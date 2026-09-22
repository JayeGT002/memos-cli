#!/bin/sh
# memos-api skill 冒烟测试：重编译 + 六命令链路验证
# 用法: skills/memos-api 下 ./quickstart.sh；发布仓库内 ./scripts/quickstart.sh
# 说明: create 会真实写入一条测试 memo，验证通过后自动删除（幂等收尾）
set -e

# 路径自适应：脚本同目录有 go.mod → 就是源码目录；否则源码在上一级（仓库 scripts/ 场景）
DIR=$(cd "$(dirname "$0")" && pwd)
if [ -f "$DIR/go.mod" ]; then ROOT="$DIR"; else ROOT="$DIR/.."; fi
cd "$ROOT"

echo "1/3 重编译（$ROOT）..."
go build -o memos-cli .

echo "2/3 test + list..."
./memos-cli test
./memos-cli list 3

echo "3/3 create -> get -> update -> delete..."
ID=$(./memos-cli create "quickstart smoke test — 自动删除" | awk '{print $NF}')
./memos-cli get "$ID"
./memos-cli update "$ID" "quickstart smoke test — updated"
./memos-cli delete "$ID"

echo "✅ 冒烟测试全部通过"
