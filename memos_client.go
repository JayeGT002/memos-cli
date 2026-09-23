package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// 配置结构
type Config struct {
	MemosURL    string `json:"memos_url"`
	AccessToken string `json:"access_token"`
}

// Status 错误响应（google.rpc.Status，仅在 HTTP >= 400 时出现）
// 参见 openapi.yaml components.schemas.Status
type Status struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Details json.RawMessage `json:"details"`
}

// User 用户（openapi.yaml components.schemas.User）
type User struct {
	Name      string `json:"name"` // users/{user}
	Role      string `json:"role"` // HOST | ADMIN | USER
	Email     string `json:"email"`
	Nickname  string `json:"nickname"`
	AvatarURL string `json:"avatarUrl"`
	State     string `json:"state"` // NORMAL | DELETED
}

// Memo Memo（openapi.yaml components.schemas.Memo，v0.31.0 对齐）
type Memo struct {
	Name       string   `json:"name"`       // 资源名 memos/{memo}，memo 为字符串 UID
	State      string   `json:"state"`      // NORMAL | ARCHIVED（取代旧 rowStatus）
	Creator    string   `json:"creator"`    // users/{user}，只读
	CreateTime string   `json:"createTime"` // RFC3339，只读
	UpdateTime string   `json:"updateTime"` // RFC3339，只读
	Content    string   `json:"content"`
	Visibility string   `json:"visibility"` // PRIVATE | PROTECTED | PUBLIC | SPACE
	Tags       []string `json:"tags"`       // 只读，从内容提取
	Pinned     bool     `json:"pinned"`
	Snippet    string   `json:"snippet"` // 只读摘要
}

// MemoListResponse ListMemosResponse
type MemoListResponse struct {
	Memos         []Memo `json:"memos"`
	NextPageToken string `json:"nextPageToken"`
}

// Client Memos客户端
type Client struct {
	baseURL     string
	accessToken string
	httpClient  *http.Client
}

// NewClient 创建客户端
func NewClient(baseURL, accessToken string) *Client {
	return &Client{
		baseURL:     baseURL,
		accessToken: accessToken,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}
}

// memoID 归一化：接受 "Ts5V..." 或 "memos/Ts5V..." 两种写法
func memoID(nameOrID string) string {
	return strings.TrimPrefix(strings.TrimSpace(nameOrID), "memos/")
}

// grpcCodeName 常见 gRPC 状态码转可读名
func grpcCodeName(code int) string {
	names := map[int]string{
		1: "CANCELLED", 2: "UNKNOWN", 3: "INVALID_ARGUMENT", 4: "DEADLINE_EXCEEDED",
		5: "NOT_FOUND", 6: "ALREADY_EXISTS", 7: "PERMISSION_DENIED",
		8: "RESOURCE_EXHAUSTED", 9: "FAILED_PRECONDITION", 12: "UNIMPLEMENTED",
		13: "INTERNAL", 14: "UNAVAILABLE", 16: "UNAUTHENTICATED",
	}
	if n, ok := names[code]; ok {
		return n
	}
	return fmt.Sprintf("CODE_%d", code)
}

// doRequest 发送请求。
// v0.31 对齐要点：
//   - 成功（HTTP 2xx）：直接返回业务 JSON，无 {code,data} 信封
//   - 失败（HTTP >= 400）：body 为 google.rpc.Status {code(=gRPC码), message}
func (c *Client) doRequest(method, endpoint string, body interface{}) ([]byte, error) {
	var bodyReader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("marshal error: %v", err)
		}
		bodyReader = bytes.NewReader(data)
	}

	req, err := http.NewRequest(method, c.baseURL+"/api/v1"+endpoint, bodyReader)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+c.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	result, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode >= 400 {
		var st Status
		if err := json.Unmarshal(result, &st); err == nil && st.Message != "" {
			return nil, fmt.Errorf("API error: %s (%s, HTTP %d)", st.Message, grpcCodeName(st.Code), resp.StatusCode)
		}
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, truncateStr(string(result), 200))
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("unexpected HTTP status %d", resp.StatusCode)
	}

	return result, nil
}

// ListMemos 获取memos列表（GET /memos，支持 pageSize/pageToken 分页）
func (c *Client) ListMemos(pageSize int, pageToken string) (*MemoListResponse, error) {
	query := url.Values{}
	query.Set("pageSize", fmt.Sprintf("%d", pageSize))
	if pageToken != "" {
		query.Set("pageToken", pageToken)
	}
	endpoint := "/memos?" + query.Encode()

	data, err := c.doRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}

	var resp MemoListResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// GetAllMemos 获取所有memos（分页遍历）
func (c *Client) GetAllMemos(limit int) ([]Memo, error) {
	if limit <= 0 {
		return nil, fmt.Errorf("limit must be a positive integer")
	}
	var allMemos []Memo
	pageToken := ""

	for {
		resp, err := c.ListMemos(50, pageToken)
		if err != nil {
			return nil, err
		}

		allMemos = append(allMemos, resp.Memos...)

		if len(allMemos) >= limit {
			return allMemos[:limit], nil
		}

		if resp.NextPageToken == "" {
			break
		}
		pageToken = resp.NextPageToken
	}

	return allMemos, nil
}

// CreateMemo 创建memo（POST /memos，body 即 Memo；visibility 强制 PROTECTED）
func (c *Client) CreateMemo(content, visibility string) (*Memo, error) {
	// 安全策略：强制使用 PROTECTED（忽略入参）
	visibility = "PROTECTED"

	body := map[string]interface{}{
		"content":    content,
		"visibility": visibility,
	}

	data, err := c.doRequest("POST", "/memos", body)
	if err != nil {
		return nil, err
	}

	var memo Memo
	if err := json.Unmarshal(data, &memo); err != nil {
		return nil, err
	}
	return &memo, nil
}

// UpdateMemo 更新memo（PATCH /memos/{id}?updateMask=...）
// id 可为字符串 UID 或 "memos/xxx" 资源名
func (c *Client) UpdateMemo(id string, content, visibility string, pinned *bool) (*Memo, error) {
	body := map[string]interface{}{}
	updateMask := []string{}

	if content != "" {
		body["content"] = content
		updateMask = append(updateMask, "content")
	}
	if visibility != "" {
		// 安全策略：强制使用 PROTECTED（忽略入参）
		body["visibility"] = "PROTECTED"
		updateMask = append(updateMask, "visibility")
	}
	if pinned != nil {
		body["pinned"] = *pinned
		updateMask = append(updateMask, "pinned")
	}

	if len(updateMask) == 0 {
		return nil, fmt.Errorf("no fields to update")
	}

	url := fmt.Sprintf("/memos/%s?updateMask=%s", memoID(id), joinStrings(updateMask, ","))
	data, err := c.doRequest("PATCH", url, body)
	if err != nil {
		return nil, err
	}

	var memo Memo
	if err := json.Unmarshal(data, &memo); err != nil {
		return nil, err
	}
	return &memo, nil
}

// DeleteMemo 删除memo（DELETE /memos/{id}，200 空响应体）
func (c *Client) DeleteMemo(id string) error {
	_, err := c.doRequest("DELETE", fmt.Sprintf("/memos/%s", memoID(id)), nil)
	return err
}

// GetMemo 获取单个memo（GET /memos/{id}）
func (c *Client) GetMemo(id string) (*Memo, error) {
	data, err := c.doRequest("GET", fmt.Sprintf("/memos/%s", memoID(id)), nil)
	if err != nil {
		return nil, err
	}

	var memo Memo
	if err := json.Unmarshal(data, &memo); err != nil {
		return nil, err
	}
	return &memo, nil
}

func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}

func truncateStr(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen]) + "..."
}
