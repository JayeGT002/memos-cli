#!/bin/sh
# memos-api skill 冒烟测试：重编译 + 六命令链路验证
# 用法: cd skills/memos-api && ./quickstart.sh
# 说明: create 会真实写入一条测试 memo，验证通过后自动删除（幂等收尾）
set -e

echo "1/3 重编译..."
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
