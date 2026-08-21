#!/usr/bin/env bash
# ant-agent Codex 侧本地装载：codex/skills/ant-dispatch symlink 进 ~/.codex/skills/。
# 机制：symlink 装载，改源跑一次 build 即生效，无需重装。
#
# 跟 Claude 侧最大的不同：**角色是项目级的**。
# 这个脚本只装 skill 本身；八个角色 TOML 要靠 skill 的 init 动作落进每个目标项目的
# <项目根>/.codex/agents/。换个项目就要再 init 一次。
#
# 用法：./install-codex.sh [目标项目绝对路径]
#   不带参数 = 只装 skill
#   带参数   = 顺便把角色 TOML 拷进那个项目
set -u

SRC_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
SKILL_SRC="${SRC_ROOT}/codex/skills/ant-dispatch"
TEMPLATE_SRC="${SRC_ROOT}/codex/templates/.codex/agents"
SKILLS_DIR="${HOME}/.codex/skills"
SKILL_DST="${SKILLS_DIR}/ant-dispatch"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${1:-}"

c_g=$'\033[32m'; c_r=$'\033[31m'; c_y=$'\033[33m'; c_c=$'\033[36m'; c_d=$'\033[90m'; c_e=$'\033[0m'
ok()   { echo "  ${c_g}✓${c_e} $1"; }
warn() { echo "  ${c_y}⚠${c_e} $1"; }
bad()  { echo "  ${c_r}✗${c_e} $1"; }

echo "${c_c}装载 ant-agent（Codex 侧）${c_e}"
echo "  ${c_d}skill： ${SKILL_DST}${c_e}"
echo

if ! node "${SRC_ROOT}/scripts/validate.mjs"; then
  bad "产物不合规，先修好再装。改了源卡的话先跑 node scripts/build.mjs"
  exit 1
fi
echo

mkdir -p "${SKILLS_DIR}" || { bad "建不了 ${SKILLS_DIR}"; exit 1; }

if [ -L "${SKILL_DST}" ] && [ "$(readlink "${SKILL_DST}")" = "${SKILL_SRC}" ]; then
  ok "ant-dispatch ${c_d}已链好，跳过${c_e}"
else
  [ -L "${SKILL_DST}" ] && rm -f "${SKILL_DST}"
  [ -e "${SKILL_DST}" ] && { mv "${SKILL_DST}" "${SKILL_DST}.bak-${STAMP}"; warn "原是实体目录，已备份"; }
  ln -s "${SKILL_SRC}" "${SKILL_DST}" && ok "ant-dispatch"
fi

echo
if [ -n "${TARGET}" ]; then
  if [ ! -d "${TARGET}" ]; then
    bad "目标项目不存在：${TARGET}"
    exit 1
  fi
  mkdir -p "${TARGET}/.codex/agents"
  cp "${TEMPLATE_SRC}"/ant-*.toml "${TARGET}/.codex/agents/" && \
    ok "角色 TOML 已落进 ${TARGET}/.codex/agents/（$(ls "${TEMPLATE_SRC}"/ant-*.toml | wc -l | tr -d ' ') 个）"
else
  warn "只装了 skill，角色 TOML 还没落到任何项目"
  echo "     ${c_d}给某个项目装角色：./install-codex.sh /abs/path/to/project${c_e}"
  echo "     ${c_d}或者让 \$ant:ant-dispatch 自己 init${c_e}"
fi

echo
ok "装载完成"
echo "  ${c_d}角色是项目级的——换个项目要再跑一次带路径的安装，或让 skill 自己 init${c_e}"
