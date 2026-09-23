#!/bin/sh
# release.sh — 同步、校验并发布 memos-cli
# 用法: ./scripts/release.sh vX.Y.Z-rN [--dry-run] [--yes] [--skip-smoke]
# 默认只预览；只有显式传入 --yes 才提交、打 tag、推送并创建 GitHub Release。
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
if [ -f "$SCRIPT_DIR/../go.mod" ]; then
  SKILL_DIR=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
elif [ -f "$SCRIPT_DIR/go.mod" ]; then
  SKILL_DIR=$SCRIPT_DIR
else
  echo "❌ 找不到 go.mod，无法定位源码目录。" >&2
  exit 2
fi

if [ -n "${MEMOS_PUBLISH_DIR:-}" ]; then
  PUB_DIR=$MEMOS_PUBLISH_DIR
elif [ -e "$SKILL_DIR/.git" ]; then
  PUB_DIR=$SKILL_DIR
else
  PUB_DIR=$(CDPATH= cd "$SKILL_DIR/../../projects/memos-cli" 2>/dev/null && pwd) || {
    echo "❌ 找不到发布仓库；设置 MEMOS_PUBLISH_DIR 指定仓库路径。" >&2
    exit 2
  }
fi

VER=${1:-}
case "$VER" in
  ""|-*) echo "❌ 缺少版本号。用法: ./scripts/release.sh vX.Y.Z-rN [--dry-run] [--yes] [--skip-smoke]"; exit 2 ;;
esac
echo "$VER" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+$' || {
  echo "❌ 版本号格式应为 vX.Y.Z-rN（例 v0.31.0-r2）" >&2
  exit 2
}

YES=0
SMOKE=1
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    --dry-run) YES=0 ;;
    --skip-smoke) SMOKE=0 ;;
  esac
done

VERSIONS="$SKILL_DIR/VERSIONS.md"
[ -f "$VERSIONS" ] || { echo "❌ 找不到版本台账: $VERSIONS" >&2; exit 2; }
grep -q "^## $VER\$" "$VERSIONS" || {
  echo "❌ VERSIONS.md 缺少 '## $VER' 条目，先写台账再发版。" >&2
  exit 2
}
NOTES=$(awk -v v="## $VER" '
  $0==v{f=1;next}
  f && /^#/{exit}
  f{lines[++n]=$0}
  END{
    s=1; while(s<=n && lines[s] ~ /^[[:space:]]*$/) s++;
    e=n; while(e>=s && (lines[e] ~ /^[[:space:]]*$/ || lines[e] ~ /^-[ -]*$/)) e--;
    for(i=s;i<=e;i++) print lines[i]
  }' "$VERSIONS")
[ -d "$PUB_DIR/.git" ] || { echo "❌ 发布仓库不存在: $PUB_DIR" >&2; exit 2; }

if [ "$YES" = 0 ]; then
  echo "======== DRY-RUN 预览（没有文件或 Git 状态变更）========"
  echo "版本: $VER"
  echo "源码: $SKILL_DIR"
  echo "发布仓库: $PUB_DIR"
  echo "Release notes:"
  printf '%s\n' "$NOTES" | sed 's/^/  /'
  echo "将执行：同步源码、运行冒烟测试、提交 release: ${VER}、创建 tag ${VER}、推送 main 和 tag、创建 GitHub Release。"
  echo "确认后使用 --yes 执行发布。"
  exit 0
fi

GH_BIN=$(command -v gh || true)
[ -n "$GH_BIN" ] || { echo "❌ 找不到 gh。" >&2; exit 2; }
if "$GH_BIN" release view "$VER" --repo JayeGT002/memos-cli >/dev/null 2>&1; then
  echo "❌ ${VER} 已在 GitHub 发布过，勿重复发版（升修订号 -rN）" >&2
  exit 2
fi

if [ "$SMOKE" = 1 ]; then
  echo "1/4 冒烟测试..."
  (cd "$SKILL_DIR" && sh ./scripts/quickstart.sh) || {
    echo "❌ 冒烟失败，已中止发版。" >&2
    exit 1
  }
else
  echo "1/4 冒烟测试: 按 --skip-smoke 跳过"
fi

echo "2/4 同步源码 → $PUB_DIR"
mkdir -p "$PUB_DIR/skill" "$PUB_DIR/scripts" "$PUB_DIR/docs"
copy_file() {
  src=$1
  dst=$2
  if [ "$src" != "$dst" ]; then cp "$src" "$dst"; fi
}
for file in main.go memos_client.go go.mod VERSIONS.md; do
  copy_file "$SKILL_DIR/$file" "$PUB_DIR/$file"
done
if [ -f "$SKILL_DIR/skill/SKILL.md" ]; then
  copy_file "$SKILL_DIR/skill/SKILL.md" "$PUB_DIR/skill/SKILL.md"
elif [ -f "$SKILL_DIR/SKILL.md" ]; then
  copy_file "$SKILL_DIR/SKILL.md" "$PUB_DIR/skill/SKILL.md"
fi
for file in quickstart.sh update-check.sh release.sh; do
  if [ -f "$SKILL_DIR/scripts/$file" ]; then
    copy_file "$SKILL_DIR/scripts/$file" "$PUB_DIR/scripts/$file"
  elif [ -f "$SKILL_DIR/$file" ]; then
    copy_file "$SKILL_DIR/$file" "$PUB_DIR/scripts/$file"
  fi
done
for spec in "$SKILL_DIR"/openapi-v*.yaml "$SKILL_DIR"/docs/openapi-v*.yaml; do
  [ -f "$spec" ] || continue
  copy_file "$spec" "$PUB_DIR/docs/$(basename "$spec")"
done

echo "3/4 生成提交与 tag..."
if [ -n "$(git -C "$PUB_DIR" status --porcelain)" ]; then
  git -C "$PUB_DIR" add -A
  git -C "$PUB_DIR" commit -m "release: $VER"
fi
if ! git -C "$PUB_DIR" rev-parse --verify "refs/tags/$VER" >/dev/null 2>&1; then
  git -C "$PUB_DIR" tag -a "$VER" -m "$NOTES"
fi

echo "4/4 推送 GitHub + 创建 Release..."
git -C "$PUB_DIR" push origin main
git -C "$PUB_DIR" push origin "$VER"
printf '%s\n' "$NOTES" | "$GH_BIN" release create "$VER" --repo JayeGT002/memos-cli --title "$VER" --notes-file -
echo "✅ 发版完成: ${VER}（main + tag + GitHub Release）"
