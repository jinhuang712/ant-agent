#!/usr/bin/env bash
#
# ant-agent · Codex
#
#   一键装（不用先 clone）：
#     curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install-codex.sh | bash -s -- /abs/path/to/project
#
#   改这个仓的人，走本地软链：
#     ./install-codex.sh --link [/abs/path/to/project]
#
# 跟 Claude 侧最大的不同：**角色是项目级的**，住在 <项目根>/.codex/agents/。
# dispatch skill 装一次全局都在，角色每个项目要落一次。
set -u

REPO="jinhuang712/ant-agent"
CLONE="https://github.com/jinhuang712/ant-agent"
SKILLS_DIR="${HOME}/.codex/skills"
SKILL_DST="${SKILLS_DIR}/ant-dispatch"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_g=$'\033[32m'; c_r=$'\033[31m'; c_y=$'\033[33m'; c_c=$'\033[36m'; c_d=$'\033[90m'; c_e=$'\033[0m'
say()  { echo "${c_c}▸${c_e} $1"; }
ok()   { echo "  ${c_g}✓${c_e} $1"; }
warn() { echo "  ${c_y}⚠${c_e} $1"; }
die()  { echo "  ${c_r}✗${c_e} $1" >&2; exit 1; }

MODE=plugin
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --link) MODE=link; shift ;;
    -*)     die "未知参数 $1（只认 --link）" ;;
    *)      TARGET="$1"; shift ;;
  esac
done

# 角色 TOML 落进一个项目。$1 = 模板目录
drop_roles() {
  local src="$1"
  [ -d "$TARGET" ] || die "目标项目不存在：$TARGET"
  mkdir -p "${TARGET}/.codex/agents"
  cp "$src"/ant-*.toml "${TARGET}/.codex/agents/" \
    || die "拷角色失败"
  ok "角色已落进 ${TARGET}/.codex/agents/（$(ls "${TARGET}/.codex/agents"/ant-*.toml | wc -l | tr -d ' ') 个）"
}

# ── 一键装 ────────────────────────────────────────────────────────────────
if [ "$MODE" = plugin ]; then
  echo "${c_c}装 ant-agent（Codex）${c_e}"
  command -v curl >/dev/null 2>&1 || die "找不到 curl"
  [ -n "$TARGET" ] || die "要给出目标项目的绝对路径——Codex 的角色是项目级的
     curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install-codex.sh | bash -s -- /abs/path/to/project"

  if command -v codex >/dev/null 2>&1; then
    say "注册 marketplace 并装 dispatch skill"
    codex plugin marketplace add "$REPO" 2>&1 | tail -1 | sed 's/^/  /'
    codex plugin add ant@ant 2>&1 | tail -1 | sed 's/^/  /'
  else
    warn "找不到 codex CLI，跳过 dispatch skill，只落角色"
    echo "     ${c_d}装了 codex 之后补一次：codex plugin marketplace add ${REPO} && codex plugin add ant@ant${c_e}"
  fi

  # 模板从哪儿来：Claude 装过就复用 marketplace 那份，否则浅 clone 一次
  src="${HOME}/.claude/plugins/marketplaces/ant/codex/templates/.codex/agents"
  tmp=""
  if [ ! -d "$src" ]; then
    command -v git >/dev/null 2>&1 || die "找不到 git（取角色模板需要）"
    tmp="$(mktemp -d)"
    say "取角色模板"
    git clone --depth 1 -q "$CLONE" "$tmp/ant-agent" || die "clone 失败"
    src="$tmp/ant-agent/codex/templates/.codex/agents"
  fi
  [ -d "$src" ] || die "取不到角色模板"

  say "落角色"
  drop_roles "$src"
  [ -n "$tmp" ] && rm -rf "$tmp"

  echo
  ok "装好了"
  echo "  ${c_d}换个项目要再跑一次，带上那个项目的路径${c_e}"
  exit 0
fi

# ── 开发装：软链 ──────────────────────────────────────────────────────────
SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || true)"
[ -n "$SRC_ROOT" ] && [ -f "${SRC_ROOT}/scripts/validate.mjs" ] \
  || die "--link 要在 clone 下来的仓里跑，curl 管道用不了"

SKILL_SRC="${SRC_ROOT}/codex/skills/ant-dispatch"
TEMPLATE_SRC="${SRC_ROOT}/codex/templates/.codex/agents"

echo "${c_c}装载 ant-agent（Codex · 软链）${c_e}"
echo "  ${c_d}skill： ${SKILL_DST}${c_e}"
echo

node "${SRC_ROOT}/scripts/validate.mjs" \
  || die "产物不合规，先修好再装。改了源卡的话先跑 node scripts/build.mjs"
echo

mkdir -p "${SKILLS_DIR}" || die "建不了 ${SKILLS_DIR}"

if [ -L "${SKILL_DST}" ] && [ "$(readlink "${SKILL_DST}")" = "${SKILL_SRC}" ]; then
  ok "ant-dispatch ${c_d}已链好，跳过${c_e}"
else
  [ -L "${SKILL_DST}" ] && rm -f "${SKILL_DST}"
  [ -e "${SKILL_DST}" ] && { mv "${SKILL_DST}" "${SKILL_DST}.bak-${STAMP}"; warn "原是实体目录，已备份"; }
  ln -s "${SKILL_SRC}" "${SKILL_DST}" && ok "ant-dispatch"
fi

echo
if [ -n "$TARGET" ]; then
  drop_roles "$TEMPLATE_SRC"
else
  warn "只装了 skill，角色还没落到任何项目"
  echo "     ${c_d}给某个项目装角色：./install-codex.sh --link /abs/path/to/project${c_e}"
  echo "     ${c_d}或者让 \$ant:ant-dispatch 自己 init${c_e}"
fi

echo
ok "装载完成。软链指向工作副本，改完源卡跑一次 build 即生效"
echo "  ${c_d}角色是项目级的——换个项目要再跑一次带路径的安装${c_e}"
