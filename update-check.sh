#!/bin/sh
# update-check.sh — 检查 usememos/memos 上游 API 更新，diff 本地 spec 存档
# 用法: cd skills/memos-api && ./update-check.sh
# 输出: 控制台摘要 + sandbox/memos-api-check/last-check.log（留痕）
# 退出码: 0=本地已兼容最新  1=上游有更新(新 spec 已下载待适配)  2=检查失败
set -u

SKILL_DIR=$(cd "$(dirname "$0")" && pwd)
WORK_DIR="$SKILL_DIR/../../sandbox/memos-api-check"
mkdir -p "$WORK_DIR"
LOG="$WORK_DIR/last-check.log"
: > "$LOG"

say() { echo "$@" | tee -a "$LOG"; }

# gh 优先（已认证，绕 raw 超时），退回 curl + api.github.com
GH=""
if command -v gh >/dev/null 2>&1; then GH=gh
elif [ -x /root/.local/bin/gh ]; then GH=/root/.local/bin/gh
fi

fail() { say "❌ 检查失败: $*"; exit 2; }

# 1. 上游最新 release
if [ -n "$GH" ]; then
  LATEST=$("$GH" api repos/usememos/memos/releases/latest \
    --jq '.tag_name + "|" + .published_at' 2>>"$LOG") || fail "gh api releases/latest"
else
  LATEST=$(curl -sf --max-time 20 https://api.github.com/repos/usememos/memos/releases/latest \
    | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["tag_name"]+"|"+d["published_at"])' 2>>"$LOG") \
    || fail "curl releases/latest（gh/curl 均不可用）"
fi
UP_TAG=${LATEST%%|*}
UP_TIME=${LATEST##*|}

# 2. 本地兼容版本 = spec 存档文件名
LOCAL_FILE=$(ls "$SKILL_DIR"/openapi-v*.yaml 2>/dev/null | tail -1)
[ -z "$LOCAL_FILE" ] && fail "未找到本地 spec 存档 openapi-v*.yaml"
LOCAL_TAG=$(basename "$LOCAL_FILE" | sed 's/^openapi-//; s/\.yaml$//')   # 形如 v0.31.0（含 v 前缀）

say "⏱ 检查时间: $(date '+%F %T %Z')"
say "🌐 上游最新: memos $UP_TAG（发布于 $UP_TIME）"
say "📦 本地兼容: $LOCAL_TAG（存档 $(basename "$LOCAL_FILE")）"

# 3. 版本一致 → 已是最新
if [ "$LOCAL_TAG" = "$UP_TAG" ]; then
  say "✅ 已兼容最新版本，无需适配。"
  exit 0
fi
say "⚠️  上游版本有更新，开始拉取新 spec 并 diff..."

# 4. 下载新 spec（GitHub contents 接口，raw 直连会超时）
NEW_SPEC="$WORK_DIR/openapi-$UP_TAG.yaml"
if [ -n "$GH" ]; then
  "$GH" api -H "Accept: application/vnd.github.raw" \
    "repos/usememos/memos/contents/proto/gen/openapi.yaml?ref=$UP_TAG" > "$NEW_SPEC" 2>>"$LOG" \
    || fail "下载新 spec（$UP_TAG）"
else
  curl -sf --max-time 30 -H "Accept: application/vnd.github.raw" \
    "https://api.github.com/repos/usememos/memos/contents/proto/gen/openapi.yaml?ref=$UP_TAG" \
    > "$NEW_SPEC" 2>>"$LOG" || fail "下载新 spec（$UP_TAG）"
fi
grep -q '^openapi:' "$NEW_SPEC" || { rm -f "$NEW_SPEC"; fail "下载内容不是 openapi yaml（可能被限流）"; }
say "⬇ 已下载: $NEW_SPEC"

# 5. 端点级 diff
extract_paths() {
  awk '/^paths:/{f=1;next} f && /^[^ ]/{f=0} f && /^ +\//{sub(/:$/,"");print}' "$1" | sort -u
}
extract_paths "$LOCAL_FILE" > "$WORK_DIR/paths-local.txt"
extract_paths "$NEW_SPEC"    > "$WORK_DIR/paths-new.txt"

ADDED=$(comm -13 "$WORK_DIR/paths-local.txt" "$WORK_DIR/paths-new.txt")
REMOVED=$(comm -23 "$WORK_DIR/paths-local.txt" "$WORK_DIR/paths-new.txt")

diff -u "$LOCAL_FILE" "$NEW_SPEC" > "$WORK_DIR/api-diff.patch" 2>/dev/null
CHANGED_LINES=$(grep -c '^[-+][^-+]' "$WORK_DIR/api-diff.patch" || true)

say "---- 差异摘要 ----"
if [ -n "$ADDED" ]; then say "➕ 新增端点:"; echo "$ADDED" | sed 's/^/   /' | tee -a "$LOG"; else say "➕ 新增端点: 无"; fi
if [ -n "$REMOVED" ]; then say "➖ 移除端点:"; echo "$REMOVED" | sed 's/^/   /' | tee -a "$LOG"; else say "➖ 移除端点: 无"; fi
say "📝 变更行数(含字段级): $CHANGED_LINES，全量 diff 见 $WORK_DIR/api-diff.patch"
say ""
say "👉 下一步: 过一遍 diff → 改 memos_client.go/main.go → ./quickstart.sh 冒烟"
say "   → 归档新 spec（存档改名 openapi-$UP_TAG.yaml）→ 更新 SKILL.md"
say "   → VERSIONS.md 加条目 → ./release.sh v${UP_TAG#v}-r1 --dry-run"
exit 1
