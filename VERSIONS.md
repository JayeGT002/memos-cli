# memos-cli 版本台账

> **规则：仓库每更新一次，必须在此留存一个版本。**
> 版本号格式：`v{兼容的 memos 版本}-r{修订号}`（如 `v0.31.0-r2` = 兼容 memos v0.31.0 的第 2 次修订）。
> 每个条目必须含四要素：**API 兼容版本 / 基本介绍 / 本版本更新时间 / memos 项目更新时间**。
> 配套工具：`update-check.sh`（查上游差异）、`release.sh`（发版），流程见 SKILL.md §版本与升级流程。

---

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
