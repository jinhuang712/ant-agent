#!/usr/bin/env bash
# ant-agent 一键安装
#
#   Claude Code：
#     curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash
#
#   顺便把角色落进一个 Codex 项目：
#     curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash -s -- --codex /abs/path/to/project
#
#   只装 Codex，不碰 Claude：
#     ... | bash -s -- --codex /abs/path/to/project --no-claude
#
# 幂等：重复跑安全，已装的走更新，CLAUDE.md 动之前先备份。
set -euo pipefail

REPO="jinhuang712/ant-agent"
CLONE="https://github.com/jinhuang712/ant-agent"
SNIPPET="https://raw.githubusercontent.com/jinhuang712/ant-agent/main/docs/CLAUDE.md.snippet"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARK="<!-- ant-agent:授权片段 · 重复安装靠这行识别，别删 -->"

CODEX_PROJECT=""
WANT_CLAUDE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --codex)     CODEX_PROJECT="${2:-}"; shift 2 ;;
    --no-claude) WANT_CLAUDE=0; shift ;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 1 ;;
  esac
done

say()  { printf '\033[36m▸\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "找不到 curl"

# ── Claude Code ───────────────────────────────────────────────────────────
if [ "$WANT_CLAUDE" = 1 ]; then
  command -v claude >/dev/null 2>&1 \
    || die "找不到 claude CLI。装 Claude Code：https://claude.com/claude-code（只用 Codex 就加 --no-claude）"

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
    { printf '\n%s\n' "$MARK"; curl -fsSL "$SNIPPET"; } >> "$CLAUDE_MD"
    echo "  已追加。片段里章节号写的是「## N.」，按你自己文件的顺序改一下"
  fi
fi

# ── Codex ─────────────────────────────────────────────────────────────────
if [ -n "$CODEX_PROJECT" ]; then
  [ -d "$CODEX_PROJECT" ] || die "目录不存在：$CODEX_PROJECT"

  # 角色 TOML 从哪儿来：Claude 装过就直接用 marketplace 那份，否则临时 clone
  src="$HOME/.claude/plugins/marketplaces/ant/codex/templates/.codex/agents"
  tmp=""
  if [ ! -d "$src" ]; then
    command -v git >/dev/null 2>&1 || die "找不到 git（装 Codex 角色需要它来取模板）"
    tmp="$(mktemp -d)"
    say "取模板"
    git clone --depth 1 -q "$CLONE" "$tmp/ant-agent"
    src="$tmp/ant-agent/codex/templates/.codex/agents"
  fi
  [ -d "$src" ] || die "取不到角色模板"

  say "把八只角色落进 $CODEX_PROJECT/.codex/agents/"
  mkdir -p "$CODEX_PROJECT/.codex/agents"
  cp "$src"/ant-*.toml "$CODEX_PROJECT/.codex/agents/"
  echo "  $(ls "$CODEX_PROJECT/.codex/agents"/ant-*.toml | wc -l | tr -d ' ') 个 TOML"

  [ -n "$tmp" ] && rm -rf "$tmp"
  warn "Codex 的角色是项目级的，换个项目要再跑一次 --codex"
fi

printf '\n\033[32m✓\033[0m 装好了。'
[ "$WANT_CLAUDE" = 1 ] && printf 'Claude Code 重启一下，或在会话里跑 /reload-plugins。'
printf '\n'
