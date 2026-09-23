# memos-cli 版本台账

> **规则：仓库每更新一次，必须在此留存一个版本。**
> 版本号格式：`v{兼容的 memos 版本}-r{修订号}`（如 `v0.31.0-r2` = 兼容 memos v0.31.0 的第 2 次修订）。
> 每个条目必须含四要素：**API 兼容版本 / 基本介绍 / 本版本更新时间 / memos 项目更新时间**。
> 配套工具：`update-check.sh`（查上游差异）、`release.sh`（发版），流程见 SKILL.md §版本与升级流程。

---

## v0.31.0-r4

- **更新时间（本版本）**：2026-09-23
- **Memos 项目更新时间**：无变化，仍为 v0.31.0（2026-09-20 00:50 (UTC+8) 发布）
- **API 兼容版本**：Memos v0.31.0（基准 `proto/gen/openapi.yaml`，存档 `docs/openapi-v0.31.0.yaml`，无变化）
- **介绍**：健壮性加固。CLI：`list` 参数改为 `strconv.Atoi` 严格校验（非正整数报错退出码 2）；`GetAllMemos` 拒绝非正 limit。HTTP 客户端不自动跟随重定向（防 token 泄漏），非 2xx 响应统一报错；`pageToken` 改用 `url.Values` 编码。`release.sh` 重写：版本号格式校验、VERSIONS.md 台账缺失即中止、默认 dry-run（仅 `--yes` 才实际发版）、重复发版检测、gh 缺失报错。

## v0.31.0-r3

- **更新时间（本版本）**：2026-09-23
- **Memos 项目更新时间**：无变化，仍为 v0.31.0（2026-09-20 00:50 (UTC+8) 发布）
- **API 兼容版本**：Memos v0.31.0（基准 `proto/gen/openapi.yaml`，存档 `docs/openapi-v0.31.0.yaml`，无变化）
- **介绍**：仓库目录结构重组：SKILL.md 收入 `skill/`、维护脚本收入 `scripts/`、OpenAPI spec 存档收入 `docs/`，README 增加目录结构与 Skill 使用说明；`quickstart.sh`/`update-check.sh` 路径自适应（skill 源目录与仓库 `scripts/` 下均可运行）。无代码变更。

## v0.31.0-r2

- **更新时间（本版本）**：2026-09-23
- **Memos 项目更新时间**：无变化，仍为 v0.31.0（2026-09-20 00:50 (UTC+8) 发布）
- **API 兼容版本**：Memos v0.31.0（基准 `proto/gen/openapi.yaml`，存档 `openapi-v0.31.0.yaml`，无变化）
- **介绍**：发布仓库由 `sandbox/memos-cli-publish/` 迁至 `projects/memos-cli/`（长期项目目录，不再受 sandbox 清理规则约束）；`release.sh` 修正 `gh release create` 缺 `--repo` 参数导致在非 git 目录下发布失败的问题；同步 SKILL.md 中的路径说明。

## v0.31.0-r1

- **更新时间（本版本）**：2026-09-23
- **Memos 项目更新时间**：v0.31.0 于 2026-09-20 00:50 (UTC+8) 发布
- **API 兼容版本**：Memos v0.31.0（基准上游 `proto/gen/openapi.yaml`，存档 `openapi-v0.31.0.yaml`）
- **介绍**：首版。六命令（test/list/create/get/update/delete）全链路对齐 v0.31 API：字符串 UID、无 `{code,data}` 信封、gRPC 错误码、`state`/RFC3339 字段、移除 `/users/me`；强制 PROTECTED 可见性。附上游检查工具 `update-check.sh`、发版工具 `release.sh` 与本台账。

---

### 条目模板（新版本复制到分隔线上方，最新在上）

```markdown
## vX.Y.Z-rN

- **更新时间（本版本）**：YYYY-MM-DD
- **Memos 项目更新时间**：vX.Y.Z 于 YYYY-MM-DD HH:MM (UTC+8) 发布（未升级 memos 则写"无变化，仍为 …"）
- **API 兼容版本**：Memos vX.Y.Z（基准 `proto/gen/openapi.yaml`，存档 `openapi-vX.Y.Z.yaml`）
- **介绍**：一两句话——改了什么、为什么改。
```
