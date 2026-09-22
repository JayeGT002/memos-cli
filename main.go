package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	// 读取配置
	config, err := loadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "配置文件错误: %v\n", err)
		os.Exit(1)
	}

	client := NewClient(config.MemosURL, config.AccessToken)

	// 命令行参数
	flag.Parse()
	args := flag.Args()

	if len(args) == 0 {
		printUsage()
		os.Exit(0)
	}

	command := args[0]

	switch command {
	case "test":
		testConnection(client)
	case "list":
		listMemos(client, args[1:])
	case "create":
		createMemo(client, args[1:])
	case "get":
		getMemo(client, args[1:])
	case "delete":
		deleteMemo(client, args[1:])
	case "update":
		updateMemo(client, args[1:])
	default:
		fmt.Printf("未知命令: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}

func loadConfig() (*Config, error) {
	data, err := os.ReadFile("config.json")
	if err != nil {
		// 尝试上一级目录
		data, err = os.ReadFile("../config.json")
		if err != nil {
			return nil, fmt.Errorf("找不到配置文件: %v", err)
		}
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	return &config, nil
}

func printUsage() {
	fmt.Println(`Memos CLI - Memos API 命令行工具 (对齐 memos v0.31.0 openapi)

用法:
  memos-cli <命令> [参数...]

命令:
  test                测试连接
  list [数量]          列出 memos (默认10条)
  get <id>            获取单个 memo（id 为字符串 UID，如 Ts5Vwm3...）
  create <内容>        创建 memo（强制 PROTECTED）
  delete <id>          删除 memo
  update <id> <内容>   更新 memo 内容

示例:
  memos-cli test
  memos-cli list 20
  memos-cli create "Hello World"
  memos-cli get Ts5Vwm3SVKSNNEWfWaBPF8
  memos-cli delete Ts5Vwm3SVKSNNEWfWaBPF8
  memos-cli update Ts5Vwm3SVKSNNEWfWaBPF8 "Updated content"`)
}

func testConnection(client *Client) {
	// 通过 memos 列表测试连接（v0.31 无 /users/me 端点）
	memos, err := client.GetAllMemos(1)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ 连接失败: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("✅ 连接成功！共获取 %d 条 memos\n", len(memos))
}

func listMemos(client *Client, args []string) {
	limit := 10
	if len(args) > 0 {
		fmt.Sscanf(args[0], "%d", &limit)
	}

	memos, err := client.GetAllMemos(limit)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ 获取失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📝 共 %d 条 memos:\n\n", len(memos))
	for _, m := range memos {
		visibility := m.Visibility
		if m.Pinned {
			visibility = "📌 " + visibility
		}
		fmt.Printf("[%s] %s\n", memoID(m.Name), visibility)
		fmt.Printf("    %s\n\n", truncate(m.Content, 100))
	}
}

func getMemo(client *Client, args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "用法: memos-cli get <id>")
		os.Exit(1)
	}

	memo, err := client.GetMemo(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ 获取失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📄 Memo %s\n", memo.Name)
	fmt.Printf("内容: %s\n", memo.Content)
	fmt.Printf("可见性: %s\n", memo.Visibility)
	fmt.Printf("状态: %s\n", memo.State)
	fmt.Printf("创建时间: %s\n", memo.CreateTime)
	fmt.Printf("置顶: %v\n", memo.Pinned)
}

func createMemo(client *Client, args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "用法: memos-cli create <内容>")
		os.Exit(1)
	}

	content := strings.Join(args, " ")

	// 安全策略：客户端强制 PROTECTED，禁止 PUBLIC（入参仅作占位）
	memo, err := client.CreateMemo(content, "PROTECTED")
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ 创建失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✅ 创建成功! ID: %s\n", memoID(memo.Name))
}

func deleteMemo(client *Client, args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "用法: memos-cli delete <id>")
		os.Exit(1)
	}

	if err := client.DeleteMemo(args[0]); err != nil {
		fmt.Fprintf(os.Stderr, "❌ 删除失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✅ 删除成功!\n")
}

func updateMemo(client *Client, args []string) {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "用法: memos-cli update <id> <新内容>")
		os.Exit(1)
	}

	id := args[0]
	content := strings.Join(args[1:], " ")

	memo, err := client.UpdateMemo(id, content, "", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ 更新失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✅ 更新成功! ID: %s\n", memoID(memo.Name))
}

func truncate(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen]) + "..."
}
