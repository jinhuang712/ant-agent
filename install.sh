#!/usr/bin/env bash
# ant-agent 一键安装
#   curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash
#
# 做三件事：注册 marketplace、装插件、把授权片段并进 ~/.claude/CLAUDE.md。
# 第三件不能省——不写授权，八只蚂蚁装了也不会被主动派出去。
# 幂等：重复跑安全，已装的跳过，CLAUDE.md 动之前先备份。
set -euo pipefail

REPO="jinhuang712/ant-agent"
SNIPPET="https://raw.githubusercontent.com/jinhuang712/ant-agent/main/docs/CLAUDE.md.snippet"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARK="<!-- ant-agent:授权片段 · 重复安装靠这行识别，别删 -->"

say() { printf '\033[36m▸\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

command -v claude >/dev/null 2>&1 || die "找不到 claude CLI。先装 Claude Code：https://claude.com/claude-code"
command -v curl   >/dev/null 2>&1 || die "找不到 curl"

say "注册 marketplace"
claude plugin marketplace add "$REPO" 2>&1 | tail -1

say "装插件"
if claude plugin list 2>/dev/null | grep -q "ant@ant"; then
  claude plugin update ant@ant 2>&1 | tail -1
else
  claude plugin install ant@ant 2>&1 | tail -1
fi

say "写授权片段到 $CLAUDE_MD"
if [ -f "$CLAUDE_MD" ] && grep -qF "$MARK" "$CLAUDE_MD"; then
  echo "  已经写过了，跳过"
else
  mkdir -p "$(dirname "$CLAUDE_MD")"
  if [ -f "$CLAUDE_MD" ]; then
    backup="$CLAUDE_MD.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$CLAUDE_MD" "$backup"
    echo "  原文件已备份到 $backup"
  fi
  {
    printf '\n%s\n' "$MARK"
    curl -fsSL "$SNIPPET"
  } >> "$CLAUDE_MD"
  echo "  已追加。片段里的章节号写的是「## N.」，按你自己文件的顺序改一下"
fi

printf '\n\033[32m✓\033[0m 装好了。重启 Claude Code，或者在会话里跑 /reload-plugins。\n'
printf '  验证：随便问一句需要翻代码的问题，看它会不会自己派蚂蚁。\n'
