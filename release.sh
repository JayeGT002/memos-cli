#!/bin/sh
# release.sh — memos-cli 版本发布：同步 → 校验 → 提交 → 打 tag → GitHub Release
# 用法: cd skills/memos-api && ./release.sh <version> [--dry-run] [--yes] [--skip-smoke]
#   例: ./release.sh v0.31.0-r1 --dry-run   # 预览，不产生任何外部动作（默认行为）
#        ./release.sh v0.31.0-r1 --yes        # 真发布：push + gh release
# 前置: 1) VERSIONS.md 已写好 <version> 条目  2) 冒烟通过（正式发布默认强制跑 quickstart）
# 发布源目录: projects/memos-cli/（2026-09-23 由 sandbox/memos-cli-publish 迁入；git → github.com/JayeGT002/memos-cli）
# 失败处置: push 前失败 → 本地无副作用，修复重跑；push 后失败 → 用 gh release create 补发，git 历史不回滚
set -u

SKILL_DIR=$(cd "$(dirname "$0")" && pwd)
PUB_DIR="$SKILL_DIR/../../projects/memos-cli"

VER="${1:-}"
case "$VER" in ""|-*) echo "❌ 缺少版本号。用法: ./release.sh vX.Y.Z-rN [--dry-run] [--yes]"; exit 2;; esac
echo "$VER" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+$' || { echo "❌ 版本号格式应为 vX.Y.Z-rN（例 v0.31.0-r2）"; exit 2; }

DRY=1; YES=0; SMOKE=1
for a in "$@"; do
  [ "$a" = "--yes" ] && { DRY=0; YES=1; }
  [ "$a" = "--dry-run" ] && DRY=1
  [ "$a" = "--skip-smoke" ] && SMOKE=0
done

# 1. 校验版本台账条目存在，并提取作为 release notes
grep -q "^## $VER\$" "$SKILL_DIR/VERSIONS.md" || { echo "❌ VERSIONS.md 缺少 '## $VER' 条目，先写台账再发版。"; exit 2; }
NOTES=$(awk -v v="## $VER" '
  $0==v{f=1;next}
  f && /^#/{exit}
  f{lines[++n]=$0}
  END{
    s=1; while(s<=n && lines[s] ~ /^[[:space:]]*$/) s++;
    e=n; while(e>=s && (lines[e] ~ /^[[:space:]]*$/ || lines[e] ~ /^-[ -]*$/)) e--;
    for(i=s;i<=e;i++) print lines[i]
  }' "$SKILL_DIR/VERSIONS.md")
[ -d "$PUB_DIR/.git" ] || { echo "❌ 发布仓库不存在: $PUB_DIR"; exit 2; }

# 幂等保护：远端已发过该版本 → 直接拒绝；本地 tag 是上次 dry-run 留下的 → 复用
if [ "$DRY" = 0 ]; then
  GH_BIN=$(command -v gh || echo /root/.local/bin/gh)
  "$GH_BIN" release view "$VER" --repo JayeGT002/memos-cli >/dev/null 2>&1 \
    && { echo "❌ $VER 已在 GitHub 发布过，勿重复发版（升修订号 -rN）"; exit 2; }
fi

# 2. 冒烟（正式发布强制，除非 --skip-smoke）
if [ "$SMOKE" = 1 ] && [ "$DRY" = 0 ]; then
  echo "1/4 冒烟测试..."
  (cd "$SKILL_DIR" && ./quickstart.sh) || { echo "❌ 冒烟失败，已中止发版。"; exit 1; }
else
  echo "1/4 冒烟: 跳过（dry-run 或 --skip-smoke）"
fi

# 3. 同步 skill 源码 → 发布仓库（不带 --delete，保留仓库自有 README/LICENSE/.gitignore/.git）
echo "2/4 同步源码 → $PUB_DIR"
SYNC_FAILED=""
for f in main.go memos_client.go go.mod quickstart.sh VERSIONS.md update-check.sh release.sh SKILL.md; do
  cp "$SKILL_DIR/$f" "$PUB_DIR/$f" 2>/dev/null || SYNC_FAILED="$SYNC_FAILED $f"
done
SPEC=$(ls "$SKILL_DIR"/openapi-v*.yaml 2>/dev/null | tail -1)
[ -n "$SPEC" ] && cp "$SPEC" "$PUB_DIR/"
[ -n "$SYNC_FAILED" ] && { echo "❌ 同步失败:$SYNC_FAILED"; exit 1; }
git -C "$PUB_DIR" status --porcelain | sed 's/^/   /'

# 4. 提交 + tag（本地动作，dry-run 到此为止只预览）
echo "3/4 生成提交与 tag..."
if ! git -C "$PUB_DIR" diff --quiet || [ -n "$(git -C "$PUB_DIR" status --porcelain)" ]; then
  git -C "$PUB_DIR" add -A
  git -C "$PUB_DIR" commit -q -m "release: $VER" || { echo "❌ commit 失败"; exit 1; }
  echo "   已提交: release: $VER"
else
  echo "   无源码变更（可能只发文档版）"
fi
if git -C "$PUB_DIR" rev-parse --verify "$VER" >/dev/null 2>&1; then
  echo "   tag $VER 已存在（上次 dry-run 创建），复用"
else
  git -C "$PUB_DIR" tag -a "$VER" -m "$NOTES" || { echo "❌ tag 失败"; exit 1; }
  echo "   已打 tag: $VER"
fi

if [ "$DRY" = 1 ]; then
  echo ""
  echo "======== DRY-RUN 预览（未推送）========"
  echo "Release notes:"
  echo "$NOTES" | sed 's/^/  /'
  echo "----------------------------------------"
  echo "将要执行（确认无误后去掉 --dry-run 加 --yes）:"
  echo "  git -C $PUB_DIR push origin main"
  echo "  git -C $PUB_DIR push origin $VER"
  echo "  gh release create $VER --title $VER --notes-file -"
  echo "⚠️  注意: tag 已在本地创建；若要放弃本次发版: git -C $PUB_DIR tag -d $VER"
  exit 0
fi

# 5. 对外发布（仅 --yes 到达此处）
echo "4/4 推送 GitHub + 创建 Release..."
git -C "$PUB_DIR" push origin main || { echo "❌ push main 失败 → 修复后重跑（tag 未推，无外部残留）"; exit 1; }
git -C "$PUB_DIR" push origin "$VER" || { echo "❌ push tag 失败 → 重跑: git -C $PUB_DIR push origin $VER"; exit 1; }
GH_BIN=$(command -v gh || echo /root/.local/bin/gh)
printf '%s\n' "$NOTES" | "$GH_BIN" release create "$VER" --repo JayeGT002/memos-cli --title "$VER" --notes-file - \
  || { echo "❌ gh release create 失败 → 补发: printf '%s' '<notes>' | $GH_BIN release create $VER --repo JayeGT002/memos-cli --title $VER --notes-file -"; exit 1; }

echo "✅ 发版完成: $VER（main + tag + GitHub Release）"
