# memos-cli

对齐 [Memos](https://github.com/usememos/memos) v0.31.0 OpenAPI 的极简命令行客户端。单二进制，零运行时依赖。

> 创建的 memo **强制 PROTECTED 可见性**（代码层强制，不接受 PUBLIC）。

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

## 与旧版 API 的差异（v0.31）

- memo ID 是**字符串 UID**，不再是 int
- 响应无 `{code,data}` 信封；错误 = HTTP ≥400 + `google.rpc.Status`
- `rowStatus` → `state`，`createdTs/updatedTs` → `createTime/updateTime`（RFC3339）
- `/users/me` 端点已移除，`test` 改用列表接口验证连接

完整字段定义见上游 `proto/gen/openapi.yaml`。

## 冒烟测试

```bash
sh ./quickstart.sh   # 重编译 + create→get→update→delete 全链路（会真实写入并删除一条测试 memo）
```

## License

[MIT](LICENSE)（与 memos 源仓库一致）
