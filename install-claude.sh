#!/usr/bin/env bash
#
# ant-agent · Claude Code
#
#   一键装（不用先 clone）：
#     curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install-claude.sh | bash
#
#   改这个仓的人，走本地软链：
#     ./install-claude.sh --link
#
# 两种装法不能混，会让八只各出现两份。换装法之前先拆掉另一种。
set -u

REPO="jinhuang712/ant-agent"
SNIPPET="https://raw.githubusercontent.com/jinhuang712/ant-agent/main/docs/CLAUDE.md.snippet"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
AGENTS_DIR="${HOME}/.claude/agents"
MARK="<!-- ant-agent:授权片段 · 重复安装靠这行识别，别删 -->"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_g=$'\033[32m'; c_r=$'\033[31m'; c_y=$'\033[33m'; c_c=$'\033[36m'; c_d=$'\033[90m'; c_e=$'\033[0m'
say()  { echo "${c_c}▸${c_e} $1"; }
ok()   { echo "  ${c_g}✓${c_e} $1"; }
warn() { echo "  ${c_y}⚠${c_e} $1"; }
die()  { echo "  ${c_r}✗${c_e} $1" >&2; exit 1; }

MODE=plugin
case "${1:-}" in
  --link) MODE=link ;;
  "")     ;;
  *)      die "未知参数 $1（只认 --link）" ;;
esac

# 授权片段两种模式都要写——不写的话八只装了也不会被主动派出去
write_snippet() {
  say "写授权片段到 ${CLAUDE_MD}"
  if [ -f "$CLAUDE_MD" ] && grep -qF "$MARK" "$CLAUDE_MD"; then
    ok "已经写过了，跳过"
    return
  fi
  mkdir -p "$(dirname "$CLAUDE_MD")"
  if [ -f "$CLAUDE_MD" ]; then
    cp "$CLAUDE_MD" "${CLAUDE_MD}.bak-${STAMP}"
    ok "原文件已备份为 CLAUDE.md.bak-${STAMP}"
  fi
  if [ "$MODE" = link ] && [ -f "${SRC_ROOT}/docs/CLAUDE.md.snippet" ]; then
    { printf '\n%s\n' "$MARK"; cat "${SRC_ROOT}/docs/CLAUDE.md.snippet"; } >> "$CLAUDE_MD"
  else
    { printf '\n%s\n' "$MARK"; curl -fsSL "$SNIPPET"; } >> "$CLAUDE_MD"
  fi
  ok "已追加。片段里章节号写的是「## N.」，按你自己文件的顺序改一下"
}

# ── 一键装：插件 ──────────────────────────────────────────────────────────
if [ "$MODE" = plugin ]; then
  echo "${c_c}装 ant-agent（Claude Code · 插件）${c_e}"
  command -v claude >/dev/null 2>&1 \
    || die "找不到 claude CLI。先装 Claude Code：https://claude.com/claude-code"
  command -v curl >/dev/null 2>&1 || die "找不到 curl"

  if ls "${AGENTS_DIR}"/{locate,verify,trace,sift,census,adjust,pardon,monitor}.md >/dev/null 2>&1; then
    warn "${AGENTS_DIR} 下有软链装法留下的角色，两种装法混着会让八只各出现两份"
    echo "     ${c_d}先拆：rm ${AGENTS_DIR}/{locate,verify,trace,sift,census,adjust,pardon,monitor}.md${c_e}"
  fi

  say "注册 marketplace"
  claude plugin marketplace add "$REPO" 2>&1 | tail -1 | sed 's/^/  /'

  say "装插件"
  if claude plugin list 2>/dev/null | grep -q "ant@ant"; then
    claude plugin update ant@ant 2>&1 | tail -1 | sed 's/^/  /'
  else
    claude plugin install ant@ant 2>&1 | tail -1 | sed 's/^/  /'
  fi

  write_snippet
  echo
  ok "装好了。重启 Claude Code，或在会话里跑 /reload-plugins"
  exit 0
fi

# ── 开发装：软链 ──────────────────────────────────────────────────────────
SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || true)"
[ -n "$SRC_ROOT" ] && [ -f "${SRC_ROOT}/scripts/validate.mjs" ] \
  || die "--link 要在 clone 下来的仓里跑，curl 管道用不了"

AGENTS_SRC="${SRC_ROOT}/plugins/ant/agents"
echo "${c_c}装载 ant-agent（Claude Code · 软链）${c_e}"
echo "  ${c_d}源：    ${AGENTS_SRC}${c_e}"
echo "  ${c_d}目标：  ${AGENTS_DIR}${c_e}"
echo

node "${SRC_ROOT}/scripts/validate.mjs" \
  || die "产物不合规，先修好再装。改了源卡的话先跑 node scripts/build.mjs"
echo

if claude plugin list 2>/dev/null | grep -q "ant@ant"; then
  warn "插件装法已经在了，两种装法混着会让八只各出现两份"
  echo "     ${c_d}先拆：claude plugin uninstall ant${c_e}"
fi

mkdir -p "${AGENTS_DIR}" || die "建不了 ${AGENTS_DIR}"

fail=0
shopt -s nullglob
srcs=("${AGENTS_SRC}"/*.md)
shopt -u nullglob
[ ${#srcs[@]} -gt 0 ] || die "${AGENTS_SRC} 下没有产物，先跑 node scripts/build.mjs"

for src in "${srcs[@]}"; do
  name="$(basename "$src")"
  dst="${AGENTS_DIR}/${name}"

  if [ -L "$dst" ]; then
    cur="$(readlink "$dst")"
    if [ "$cur" = "$src" ]; then
      ok "${name} ${c_d}已链好，跳过${c_e}"
      continue
    fi
    rm -f "$dst"
    warn "${name} ${c_d}原链指向 ${cur}，改指本仓${c_e}"
  elif [ -e "$dst" ]; then
    mv "$dst" "${dst}.bak-${STAMP}"
    warn "${name} ${c_d}原是实体文件，已备份为 ${name}.bak-${STAMP}${c_e}"
  fi

  ln -s "$src" "$dst" && ok "$name" || { bad "${name} 建链失败"; fail=1; }
done

echo
# 早期版本留下的执行体，只报告不删
for stale in fact-check evidence-hunter code-reader ant-locate ant-verify ant-trace \
             ant-sift ant-census ant-adjust ant-pardon ant-monitor; do
  p="${AGENTS_DIR}/${stale}.md"
  if [ -e "$p" ] || [ -L "$p" ]; then
    warn "${stale}.md 是 ant-agent 早期版本留下的"
    echo "     ${c_d}确认没别的用途后自行删除：rm ${p}${c_e}"
  fi
done

write_snippet
echo
if [ "$fail" = 0 ]; then
  ok "装载完成。软链指向工作副本，改完源卡跑一次 build 即生效"
  echo "  ${c_d}注意：软链只搬 agents/，hooks/ 不会被加载——派发提醒 hook 只在插件装法下有${c_e}"
else
  die "有条目失败，看上面"
fi
