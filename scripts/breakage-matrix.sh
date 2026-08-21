#!/usr/bin/env bash
# 逐条破坏 validate.mjs 的校验，确认每条都真的拦得住。挂在 CI 里跑，也能本地手跑。
# 每轮：破坏 → 跑 validate → 记退出码 → git checkout 还原。
# 前置：工作区必须干净，否则还原步骤（git checkout -- .）会连累未提交的改动。
#
# 约定，改这个文件的人请遵守：
#   - 破坏命令一律走 sedi（下面定义），不要裸写 sed -i ''——BSD/GNU 不通用，
#     CI 跑的是 GNU sed 的 ubuntu，裸写 macOS 写法在 CI 上会直接报错。
#   - say() 里但凡拼「变量 + 紧跟着的全角标点」（不留 ASCII 间隔），一律用
#     printf -v 拼好整行再传给 say，不要在 say "...$var（...）..." 里裸拼。
#     本机 bash 5.3.15 对「裸 $var 后面紧跟多字节字面量」这个词法组合有解析
#     bug，会整段吞掉变量内容、后面的多字节字符也丢首字节；跟 locale 无关——
#     LANG/LC_ALL 设成任何 UTF-8 locale 都复现，只有 ${var} 加花括号或者
#     printf 传参能稳定绕开。下面仍然锁 UTF-8 locale，是防万一 CI 的 runner/
#     bash 版本组合有别的、真正吃 locale 的多字节问题，两道防线不冲突。
set -uo pipefail

R=/Users/jin.huang/dev/skills/ant-agent
OUT="${1:-/dev/stdout}"
: > "$OUT" 2>/dev/null || true

say() { printf '%s\n' "$*" >> "$OUT"; }

# --- 锁定 UTF-8 locale：不假设调用环境带着可用的 LANG（nohup 起的进程、
# 精简过的 CI runner 都可能没有）。挑不到能用的就直接中止，不悄悄退化成
# C locale 吃掉全角标点。 ---
pick_utf8_locale() {
  local avail cand
  avail="$(locale -a 2>/dev/null)"
  for cand in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    if grep -qix "$cand" <<<"$avail"; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}
if LOC="$(pick_utf8_locale)"; then
  export LANG="$LOC" LC_ALL="$LOC"
else
  say "ABORT 找不到可用的 UTF-8 locale（试过 C.UTF-8 / C.utf8 / en_US.UTF-8 / en_US.utf8）"
  say "DONE"
  exit 1
fi

# --- 跨平台 sed -i：GNU（ubuntu CI）不吃空扩展名参数，BSD（macOS 本地）必须
# 给这个参数，两边语法不通用。用 sed --version 探测——BSD sed 不认这个选项，
# 探测本身不产出文件，不用担心误破坏。 ---
sedi() {                        # sedi <expr> <file>
  if sed --version >/dev/null 2>&1; then
    sed -i "$1" "$2"            # GNU sed
  else
    sed -i '' "$1" "$2"         # BSD sed
  fi
}
export -f sedi                  # 破坏命令跑在 bash -c 起的子进程里，函数要显式导出才可见

# --- 前置检查：必须是干净的 git 工作区，且脚本依赖的文件都在。 ---
if [ "$(git -C "$R" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
  say "ABORT $R 不是 git 工作区"
  say "DONE"; exit 1
fi
for f in scripts/validate.mjs scripts/build.mjs; do
  if [ ! -f "$R/$f" ]; then
    say "ABORT 缺 $R/$f，脚本没法跑"
    say "DONE"; exit 1
  fi
done
if [ -n "$(git -C "$R" status --porcelain)" ]; then
  say "ABORT 工作区不干净，拒绝跑——还原步骤会连累未提交的改动"
  say "DONE"; exit 1
fi

pass=0; fail=0
probe() {                       # probe <名字> <破坏命令>
  local name="$1"; shift
  bash -c "$*" >/dev/null 2>&1
  node "$R/scripts/validate.mjs" >/dev/null 2>&1
  local code=$?
  git -C "$R" checkout -- . 2>/dev/null
  local line
  if [ "$code" -ne 0 ]; then
    printf -v line '  PASS  %s（退出码 %s）' "$name" "$code"
    say "$line"; pass=$((pass+1))
  else
    printf -v line '  MISS  %s —— 破坏了但校验放行' "$name"
    say "$line"; fail=$((fail+1))
  fi
}

say "破坏测试矩阵 开始"
say ""

# YAML「冒号+空格」只在裸标量（非 >- 块标量）的那一行上非法。situation/description
# 折成块标量后冒号在里面是合法内容，塞进 situation 测不出这条——block 化解了破坏。
# color 是生成产物里唯一保留裸标量的字段，改它才是这条校验真正能拦住的破坏。
probe "YAML 冒号+空格" \
  "sedi 's|^color: yellow|color: yellow: bold|' $R/shared/roles/verify.md && node $R/scripts/build.mjs"
probe "frontmatter 未闭合" \
  "printf 'oops\n%s' \"\$(cat $R/plugins/ant/agents/verify.md)\" > $R/plugins/ant/agents/verify.md"
probe "TOML 多余顶层键" \
  "printf '\nmodel = \"haiku\"\n' >> $R/codex/templates/.codex/agents/ant-verify.toml"
probe "Codex 侧混入 Claude 语法" \
  "printf '\n\$ARGUMENTS\n' >> $R/codex/templates/.codex/agents/ant-verify.toml"
probe "description 裸名交叉引用" \
  "sedi 's|use ant:sift|use ant-sift|' $R/plugins/ant/agents/census.md"
probe "档位自相矛盾" \
  "sedi 's|Always pass model=sonnet|Pass model=haiku or model=sonnet|' $R/plugins/ant/agents/sift.md"
probe "name 跟文件名对不上" \
  "sedi 's|^name: census|name: tally|' $R/plugins/ant/agents/census.md"
probe "缺 Unplanned 出口" \
  "sedi 's|Unplanned|Unplnnd|g' $R/plugins/ant/agents/verify.md"
probe "源卡有产物没有" \
  "rm $R/plugins/ant/agents/monitor.md $R/codex/templates/.codex/agents/ant-monitor.toml"
probe "产物有源卡没有" \
  "rm $R/shared/roles/monitor.md"
probe "两侧产物不对等" \
  "rm $R/codex/templates/.codex/agents/ant-trace.toml"
probe "清单 source 路径错" \
  "sedi 's|./plugins/ant|./plugins/nowhere|' $R/.claude-plugin/marketplace.json"
probe "hook 脚本不存在" \
  "sedi 's|dispatch-nudge.mjs|dispatch-nudge-gone.mjs|' $R/plugins/ant/hooks/hooks.json"
# 版本号用正则替换「当前是什么就换掉什么」，不写死旧版本号——写死的话每次
# CHANGELOG 一 bump，这条探针就悄悄失效（sed 找不到匹配、文件原样不变、
# validate 自然放行，被误判成 MISS）。
probe "Claude 版本号跟 CHANGELOG 脱节" \
  "sedi 's|\"version\": \"[^\"]*\"|\"version\": \"0.9.9\"|' $R/plugins/ant/.claude-plugin/plugin.json"
probe "Codex 版本号跟 CHANGELOG 脱节" \
  "sedi 's|\"version\": \"[^\"]*\"|\"version\": \"0.9.9\"|' $R/codex/.codex-plugin/plugin.json"
probe "plugin.json 缺失" \
  "rm $R/plugins/ant/.claude-plugin/plugin.json"

say ""
say "结果 拦下 $pass 条 / 放行 $fail 条"

status=0
node "$R/scripts/build.mjs" >/dev/null 2>&1
if node "$R/scripts/validate.mjs" >/dev/null 2>&1 && [ -z "$(git -C "$R" status --porcelain)" ]; then
  say "还原 工作区干净，validate 全绿"
else
  say "还原 异常——工作区没回到干净状态，需要人工看"
  status=1
fi
if [ "$fail" -ne 0 ]; then
  status=1
fi

say "DONE"
exit "$status"
