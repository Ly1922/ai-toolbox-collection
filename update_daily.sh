#!/bin/bash
# 用法: update_daily.sh YYYY-MM-DD
# 将当日简报文件注册到 README.md 的每日情报区，然后 commit + push

# 仓库路径：优先用环境变量 REPO，否则尝试常见默认位置，最后回退到脚本所在目录的上级
if [ -z "$REPO" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$SCRIPT_DIR/.git" ]; then
        REPO="$SCRIPT_DIR"
    elif [ -d "/root/workspace/ai-toolbox-collection/.git" ]; then
        REPO="/root/workspace/ai-toolbox-collection"
    elif [ -d "/home/agentuser/repos/ai-toolbox-collection/.git" ]; then
        REPO="/home/agentuser/repos/ai-toolbox-collection"
    else
        REPO="$SCRIPT_DIR"
    fi
fi
DATE="$1"
BRANCH=main

if [ -z "$DATE" ]; then
    echo "Usage: $0 YYYY-MM-DD"
    exit 1
fi

BRIEFING_FILE="daily-briefings/${DATE}.md"
if [ ! -f "$REPO/$BRIEFING_FILE" ]; then
    echo "文件不存在: $BRIEFING_FILE"
    exit 1
fi

cd "$REPO"

# 防重：若今日条目已存在则跳过插入
if grep -q "\*\*$DATE\*\* — \[📄 查看\](./daily-briefings/${DATE}.md)" README.md; then
    echo "今日条目已存在，跳过 README 插入"
else
    # 更新 README.md: 在「每日 AI 工具情报」区块顶部插入今日条目
    # 格式: - **YYYY-MM-DD** — [📄 查看](./daily-briefings/YYYY-MM-DD.md)
    NEW_ENTRY="- **${DATE}** — [📄 查看](./daily-briefings/${DATE}.md)"

    # 检查 README 里有没有「每日 AI 工具情报」区块
    if grep -q "## 📊 每日 AI 工具情报" README.md; then
        # 找到区块，在「更新时间」行之后插入新条目
        python3 - <<PYEOF
import re

date = "$DATE"
entry = f"- **{date}** — [📄 查看](./daily-briefings/{date}.md)"

with open('README.md', 'r') as f:
    content = f.read()

# 找到「更新时间：」行，在其后插入新条目
pattern = r'(> 更新：\d{4}-\d{2}-\d{2}\n)'
if re.search(pattern, content):
    content = re.sub(pattern, r'\1\n' + entry + '\n', content, count=1)
else:
    header = '## 📊 每日 AI 工具情报'
    if header in content:
        content = content.replace(header, header + '\n\n' + entry, 1)

with open('README.md', 'w') as f:
    f.write(content)
print("README.md updated")
PYEOF
    else
        # 没有这个区块，在最开头（标题后）插入新区块
        python3 - <<PYEOF
import re

date = "$DATE"
entry = f"- **{date}** — [📄 查看](./daily-briefings/{date}.md)"

with open('README.md', 'r') as f:
    content = f.read()

new_section = f"""## 📊 每日 AI 工具情报

{entry}
"""

marker = "## 🎨 亚马逊美工/电商视觉"
content = content.replace(marker, new_section + "\n" + marker, 1)

with open('README.md', 'w') as f:
    f.write(content)
print("README.md updated (new section created)")
PYEOF
    fi
fi

# Commit + Push (用 gh credential helper)
git config credential.helper "/usr/bin/gh auth git-credential"
git add README.md "$BRIEFING_FILE"
git commit -m "📊 每日AI情报 ${DATE}"
git push origin main 2>&1
echo "Done."
