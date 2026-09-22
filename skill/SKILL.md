# Memos API Skill

## Description

Go-based CLI tool for Memos self-hosted notes system API. Memo CRUD via `/api/v1`.
**已对齐本地 memos v0.31.0 openapi spec（2026-09-23 全链路验证）**，spec 存档见同目录 `openapi-v0.31.0.yaml`（发布仓库内位于 `docs/`）。

## ⚠️ 安全限制

### 可见性策略：仅允许 PROTECTED

| 可见性 | 说明 | 支持 |
|--------|------|------|
| PRIVATE | 仅自己可见 | ✅ |
| PROTECTED | 登录用户可见 | ✅ **默认且唯一允许** |
| PUBLIC | 公开可见 | ❌ **禁止使用** |
| SPACE | 空间成员可见 | ❌ 不使用 |

**核心规则：发布 memos 只能使用 PROTECTED 范围**

- `visibility` 参数**强制使用** `PROTECTED`（客户端代码层强制，传其他值一律转为 PROTECTED）
- 所有通过此工具创建的 memo 都将是 PROTECTED

## v0.31 API 关键变化（旧写法已全部废弃）

| 项目 | 旧（≤v0.26） | 新（v0.31，当前） |
|------|------------|-----------------|
| memo ID | `int`（如 `123`） | **字符串 UID**（如 `Ts5Vwm3SVKSNNEWfWaBPF8`），资源名 `memos/{uid}`，两种写法都接受 |
| 响应格式 | `{code, message, data}` 信封 | **直接返回业务对象**；错误 = HTTP ≥400 + `google.rpc.Status {code, message}`（code 为 gRPC 码） |
| 行状态 | `rowStatus: NORMAL/ARCHIVED` | `state: NORMAL/ARCHIVED` |
| 时间戳 | `createdTs/updatedTs` int64 | `createTime/updateTime` RFC3339 字符串 |
| 附件字段 | `resourceList` | `attachments` |
| 当前用户 | `GET /users/me` | **端点已移除**（测试连接用 `list` 代替） |
| 新增只读字段 | — | `creator`、`tags`、`snippet`、`parent` |

## Capability

- Create, read, update, delete memos（字符串 UID）
- 分页 list（pageSize/pageToken）
- Go CLI，零运行时依赖

## Usage

```bash
cd skills/memos-api

# 测试连接
./memos-cli test

# 列出 memos（列表项显示字符串 UID）
./memos-cli list 20

# 创建 memo（强制 PROTECTED）
./memos-cli create "Hello World"

# 获取单个 memo（id = 字符串 UID，或 memos/UID 资源名均可）
./memos-cli get Ts5Vwm3SVKSNNEWfWaBPF8

# 更新 memo（PATCH + updateMask=content）
./memos-cli update Ts5Vwm3SVKSNNEWfWaBPF8 "Updated content"

# 删除 memo
./memos-cli delete Ts5Vwm3SVKSNNEWfWaBPF8
```

### 环境变量（直接调 API 时用）

```bash
export MEMOS_URL="http://192.168.5.8:5230"
export MEMOS_TOKEN="your-api-token"
# 鉴权: Authorization: Bearer $MEMOS_TOKEN
```

## 高级用法（spec 有、CLI 未封装，直接 curl）

- 列表过滤：`GET /api/v1/memos?filter=content.contains("x")&state=ARCHIVED&orderBy=pinned desc, create_time desc`
- 归档状态：`state=NORMAL|ARCHIVED`（默认 NORMAL）
- 评论/附件/反应/关系/分享：`/api/v1/memos/{memo}/comments|attachments|reactions|relations|shares`
- 完整字段定义：见 `openapi-v0.31.0.yaml`（`components.schemas.Memo`）

## Output Format

- CLI 输出带 emoji 指示：✅ 成功 / ❌ 失败 / 📝 列表 / 📄 单条
- 置顶显示 📌 前缀；错误输出 gRPC 码名（如 `NOT_FOUND`）

## Configuration

Requires configuration file at:
```
skills/memos-api/config.json
```
```json
{
    "memos_url": "http://192.168.5.8:5230",
    "access_token": "your-api-token"
}
```

Get your API token from: Memos Settings → Access Token（PAT，`memos_pat_` 开头）

## 重新构建

```bash
cd skills/memos-api && go build -o memos-cli .
```

## 版本与升级流程

**版本台账：`VERSIONS.md`** —— 仓库每更新一次必须留存一个版本，条目四要素：API 兼容版本、基本介绍、本版本更新时间、memos 项目更新时间。版本号格式 `v{memos版本}-r{修订号}`。

memos 升级后的适配流程：

```bash
cd skills/memos-api
./update-check.sh          # 1. 查上游：最新 release vs 本地 spec 存档；有更新会下载新 spec 并出 diff（退出码 1）
                           # 2. 按 sandbox/memos-api-check/api-diff.patch 改 memos_client.go / main.go
./quickstart.sh            # 3. 六命令冒烟
# 4. 归档：新 spec 存档改名 openapi-vX.Y.Z.yaml，更新 SKILL.md 基准版本行
# 5. VERSIONS.md 加条目（memos 项目发布时间从 update-check.sh 输出里抄）
./release.sh vX.Y.Z-rN --dry-run   # 6. 预览：同步源码 → 本地 commit + tag（不外发）
./release.sh vX.Y.Z-rN --yes       # 7. 确认后正式发布：push + GitHub Release
```

工具位置：`update-check.sh` / `release.sh` / `VERSIONS.md`（发布仓库 = `projects/memos-cli/`，2026-09-23 由 sandbox 迁入 → github.com/JayeGT002/memos-cli。仓库结构自 v0.31.0-r3 起：源码与台账在根目录、skill 文档在 `skill/`、维护脚本在 `scripts/`、spec 存档在 `docs/`）。
失败处置：push 前失败无外部副作用，修复重跑（dry-run 的本地 commit/tag 会被复用）；`gh release create` 失败按脚本提示补发。

## Dependencies

- Go 1.23+（编译一次，二进制零依赖）

*对齐记录：2026-09-23，基准 = usememos/memos v0.31.0 `proto/gen/openapi.yaml`，全链路实测通过。*
