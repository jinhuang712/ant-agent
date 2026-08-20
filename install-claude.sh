#!/usr/bin/env bash
# ant-agent Claude 侧本地装载：plugins/ant-agent/agents/*.md symlink 进 ~/.claude/agents/。
# 机制：symlink 装载，改源跑一次 build 即生效，无需重装。
# 幂等 + 覆盖：重复跑安全——已正确链接则跳过；指向别处 / 旧实体一律覆盖修复（实体先备份）。
# 装载前先跑 validate，产物不合规就不装。
# 废弃 agent 只报告不删：同名文件可能是你自己写的。
# 用法：./install-claude.sh
set -u

SRC_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
AGENTS_SRC="${SRC_ROOT}/plugins/ant-agent/agents"
AGENTS_DIR="${HOME}/.claude/agents"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_g=$'\033[32m'; c_r=$'\033[31m'; c_y=$'\033[33m'; c_c=$'\033[36m'; c_d=$'\033[90m'; c_e=$'\033[0m'
ok()   { echo "  ${c_g}✓${c_e} $1"; }
warn() { echo "  ${c_y}⚠${c_e} $1"; }
bad()  { echo "  ${c_r}✗${c_e} $1"; }

echo "${c_c}装载 ant-agent（Claude 侧）${c_e}"
echo "  ${c_d}源：    ${AGENTS_SRC}${c_e}"
echo "  ${c_d}目标：  ${AGENTS_DIR}${c_e}"
echo

if ! node "${SRC_ROOT}/scripts/validate.mjs"; then
  bad "产物不合规，先修好再装。改了源卡的话先跑 node scripts/build.mjs"
  exit 1
fi
echo

mkdir -p "${AGENTS_DIR}" || { bad "建不了 ${AGENTS_DIR}"; exit 1; }

fail=0
for src in "${AGENTS_SRC}"/ant-*.md; do
  [ -e "$src" ] || { bad "${AGENTS_SRC} 下没有 ant-*.md，先跑 node scripts/build.mjs"; exit 1; }
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

  if ln -s "$src" "$dst"; then
    ok "${name}"
  else
    bad "${name} 建链失败"
    fail=1
  fi
done

echo
# 早期版本留下的执行体，只报告不删
for stale in fact-check evidence-hunter code-reader; do
  p="${AGENTS_DIR}/${stale}.md"
  if [ -e "$p" ] || [ -L "$p" ]; then
    warn "${stale}.md 是 ant-agent 早期版本，编制已重切"
    echo "     ${c_d}确认没别的用途后自行删除：rm ${p}${c_e}"
  fi
done

echo
if [ "$fail" = 0 ]; then
  ok "装载完成"
  echo "  ${c_d}新开一个会话，或在已有会话里发一条消息，即可认到${c_e}"
  echo "  ${c_d}授权与分派门槛要手动并进 ~/.claude/CLAUDE.md，片段见 docs/CLAUDE.md.snippet${c_e}"
else
  bad "有条目失败，看上面"
  exit 1
fi
