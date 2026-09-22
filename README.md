# memos-cli

对齐 [Memos](https://github.com/usememos/memos) v0.31.0 OpenAPI 的极简命令行客户端。单二进制，零运行时依赖。

> 创建的 memo **强制 PROTECTED 可见性**（代码层强制，不接受 PUBLIC）。

## 目录结构

```
memos-cli/
├── main.go / memos_client.go / go.mod   # 源码
├── VERSIONS.md                          # 版本台账（每版四要素）
├── skill/
│   └── SKILL.md                         # Agent Skill 说明（见下节）
├── scripts/
│   ├── quickstart.sh                    # 冒烟测试（六命令全链路）
│   ├── update-check.sh                  # 上游 memos 版本差异检查
│   └── release.sh                       # 维护者发版脚本
└── docs/
    └── openapi-v0.31.0.yaml             # 上游 OpenAPI spec 存档（对齐基准）
```

## 构建

```bash
go build -o memos-cli .
```

需要 Go 1.23+。

## 配置

当前目录放置 `config.json`（已在 .gitignore 中，不会被提交）：

```json
{
  "memos_url": "http://localhost:5230",
  "access_token": "your-api-token"
}
```

API token 获取：Memos → Settings → Access Token（`memos_pat_` 开头），鉴权方式 `Authorization: Bearer <token>`。

## 用法

```bash
./memos-cli test                 # 测试连接
./memos-cli list 20              # 列出 memos（显示字符串 UID）
./memos-cli create "Hello World" # 创建（强制 PROTECTED）
./memos-cli get <id>             # 读取单条
./memos-cli update <id> "New"    # 更新内容
./memos-cli delete <id>          # 删除
```

`<id>` 接受字符串 UID（如 `Ts5Vwm3SVKSNNEWfWaBPF8`）或资源名（`memos/UID`）。

## Skill

本仓库内置一份 Agent Skill（[`skill/SKILL.md`](skill/SKILL.md)），供 AI 助手（如 PicoClaw、Claude 等支持 skill 机制的 Agent）以受控方式操作 Memos：

- **安全策略**：可见性强制 PROTECTED（代码层强制，PUBLIC 被禁止）；
- **内容**：六命令用法、v0.31 API 新旧差异表、上游版本检查与发版流程；
- **安装**：将 `skill/SKILL.md` 复制到 Agent 的 skills 目录（如 `~/.picoclaw/workspace/skills/memos-api/SKILL.md`），并把本仓库源码目录作为工作目录即可。

## 与旧版 API 的差异（v0.31）

- memo ID 是**字符串 UID**，不再是 int
- 响应无 `{code,data}` 信封；错误 = HTTP ≥400 + `google.rpc.Status`
- `rowStatus` → `state`，`createdTs/updatedTs` → `createTime/updateTime`（RFC3339）
- `/users/me` 端点已移除，`test` 改用列表接口验证连接

完整字段定义见上游 `proto/gen/openapi.yaml`（本地存档：`docs/openapi-v0.31.0.yaml`）。

## 冒烟测试

```bash
sh ./scripts/quickstart.sh   # 重编译 + create→get→update→delete 全链路（会真实写入并删除一条测试 memo）
```

## License

[MIT](LICENSE)（与 memos 源仓库一致）
