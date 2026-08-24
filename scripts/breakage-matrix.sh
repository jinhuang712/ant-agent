#!/usr/bin/env bash
# 逐条破坏 validate.mjs 的校验，确认每条都真的拦得住，而且拦住的是它自己声称要拦的
# 那条——不是破坏顺带触发了别的校验、退出码照样非零、但探针名不对题。
# 每轮：破坏 → 跑 validate → 比对预期错误特征 → 记结果（PASS/MISS/WRONG）→ 还原。
# 前置：工作区必须干净，否则还原步骤（git checkout -- . + git clean -fd）会连累未提交的改动。
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
#   - probe 现在是三个参数：probe <名字> <预期错误特征> <破坏命令>。预期特征是
#     validate.mjs 报错文案里的一段定字符串（fail() 消息的一截），跑完用
#     grep -F 在 validate.mjs 的 stderr 里找这段——找到了才是 PASS，退出码非零
#     但没找到算 WRONG（破坏打偏了，触发的是别的校验，不是这条探针要测的那条）。
#     退出码为 0 一律是 MISS，不看预期特征。
#   - 预期特征只挑不随「哪个文件名 / 哪个动态值」变化的定长片段；涉及
#     CHANGELOG 版本号这类会变的动态值，只取到动态值之前为止。
set -uo pipefail

# 仓库根从脚本位置推导，不写死——写死的话在 CI runner 上那个路径不存在，
# 前置检查会 ABORT，而且报的是「不是 git 工作区」，看着像环境问题不像脚本问题。
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
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

pass=0; fail=0; wrong=0
probe() {                       # probe <名字> <预期错误特征> <破坏命令>
  local name="$1" expect="$2"; shift 2
  bash -c "$*" >/dev/null 2>&1
  local out
  out="$(node "$R/scripts/validate.mjs" 2>&1 >/dev/null)"
  local code=$?
  git -C "$R" checkout -- . 2>/dev/null
  git -C "$R" clean -fd . >/dev/null 2>&1   # 有的探针会新建未跟踪文件，checkout 管不到
  local line
  if [ "$code" -eq 0 ]; then
    printf -v line '  MISS  %s —— 破坏了但校验放行' "$name"
    say "$line"; fail=$((fail+1))
  elif grep -qF -- "$expect" <<<"$out"; then
    printf -v line '  PASS  %s（退出码 %s）' "$name" "$code"
    say "$line"; pass=$((pass+1))
  else
    printf -v line '  WRONG %s —— 退出码 %s 非零，但没打中预期特征「%s」，打偏了' "$name" "$code" "$expect"
    say "$line"; wrong=$((wrong+1))
  fi
}

say "破坏测试矩阵 开始"
say ""

# --- 原有 16 条：回填预期错误特征，行为不变，只是现在还核对报的是哪条 ---

# YAML「冒号+空格」只在裸标量（非 >- 块标量）的那一行上非法。situation/description
# 折成块标量后冒号在里面是合法内容，塞进 situation 测不出这条——block 化解了破坏。
# color 是生成产物里唯一保留裸标量的字段，改它才是这条校验真正能拦住的破坏。
probe "YAML 冒号+空格" \
  "verify.md: color 的值里有「冒号+空格」" \
  "sedi 's|^color: yellow|color: yellow: bold|' $R/shared/roles/verify.md && node $R/scripts/build.mjs"
probe "frontmatter 未闭合" \
  "verify.md: frontmatter 缺失或没有闭合" \
  "printf 'oops\n%s' \"\$(cat $R/plugins/ant/agents/verify.md)\" > $R/plugins/ant/agents/verify.md"
probe "TOML 多余顶层键" \
  "ant-verify.toml: 多余顶层键 model" \
  "printf '\nmodel = \"haiku\"\n' >> $R/codex/templates/.codex/agents/ant-verify.toml"
probe "Codex 侧混入 Claude 语法" \
  "ant-verify.toml: 含 Claude 专属语法 \$ARGUMENTS" \
  "printf '\n\$ARGUMENTS\n' >> $R/codex/templates/.codex/agents/ant-verify.toml"
probe "description 裸名交叉引用" \
  "census.md: description 里有裸名 ant-sift" \
  "sedi 's|use ant:sift|use ant-sift|' $R/plugins/ant/agents/census.md"
probe "档位自相矛盾" \
  "sift.md: description 里同时出现" \
  "sedi 's|Always pass model=sonnet|Pass model=haiku or model=sonnet|' $R/plugins/ant/agents/sift.md"
probe "name 跟文件名对不上" \
  "census.md: name 跟文件名对不上" \
  "sedi 's|^name: census|name: tally|' $R/plugins/ant/agents/census.md"
probe "缺 Unplanned 出口" \
  "verify.md: 缺 Unplanned 出口" \
  "sedi 's|Unplanned|Unplnnd|g' $R/plugins/ant/agents/verify.md"
probe "源卡有产物没有" \
  "monitor: 源卡在 shared/roles/ 里，产物却没生成" \
  "rm $R/plugins/ant/agents/monitor.md $R/codex/templates/.codex/agents/ant-monitor.toml"
probe "产物有源卡没有" \
  "monitor: 有产物但源卡不在了，该删产物" \
  "rm $R/shared/roles/monitor.md"
probe "两侧产物不对等" \
  "trace: Codex 侧缺产物" \
  "rm $R/codex/templates/.codex/agents/ant-trace.toml"
probe "清单 source 路径错" \
  ".claude-plugin/marketplace.json: source 声明的" \
  "sedi 's|./plugins/ant|./plugins/nowhere|' $R/.claude-plugin/marketplace.json"
probe "hook 脚本不存在" \
  "引用的 hooks/dispatch-nudge-gone.mjs 不存在" \
  "sedi 's|dispatch-nudge.mjs|dispatch-nudge-gone.mjs|' $R/plugins/ant/hooks/hooks.json"
# 版本号用正则替换「当前是什么就换掉什么」，不写死旧版本号——写死的话每次
# CHANGELOG 一 bump，这条探针就悄悄失效（sed 找不到匹配、文件原样不变、
# validate 自然放行，被误判成 MISS）。预期特征只取到动态的 CHANGELOG 版本号
# 之前为止，同样是为了不随 bump 失效。
probe "Claude 版本号跟 CHANGELOG 脱节" \
  "plugins/ant/.claude-plugin/plugin.json 的 version 0.9.9 跟 CHANGELOG 顶部的" \
  "sedi 's|\"version\": \"[^\"]*\"|\"version\": \"0.9.9\"|' $R/plugins/ant/.claude-plugin/plugin.json"
probe "Codex 版本号跟 CHANGELOG 脱节" \
  "codex/.codex-plugin/plugin.json 的 version 0.9.9 跟 CHANGELOG 顶部的" \
  "sedi 's|\"version\": \"[^\"]*\"|\"version\": \"0.9.9\"|' $R/codex/.codex-plugin/plugin.json"
probe "plugin.json 缺失" \
  "plugins/ant/.claude-plugin/plugin.json 不存在" \
  "rm $R/plugins/ant/.claude-plugin/plugin.json"

# --- 补齐覆盖缺口：validate.mjs 里此前一次都没被打到的 fail() 落点 ---

probe "Claude 侧缺 model 提醒" \
  "verify.md: 缺 model 提醒" \
  "sedi 's|model=haiku|use haiku|' $R/plugins/ant/agents/verify.md"
probe "frontmatter 裸行" \
  "verify.md: frontmatter 有不成 key 的裸行「badline_no_colon」" \
  "awk 'NR==1{print; print \"badline_no_colon\"; next}1' $R/plugins/ant/agents/verify.md > $R/plugins/ant/agents/verify.md.tmp && mv $R/plugins/ant/agents/verify.md.tmp $R/plugins/ant/agents/verify.md"
probe "Codex 侧缺 model 提醒" \
  "ant-verify.toml: 缺 model 提醒" \
  "sedi 's|Suggested model:|Suggested tier:|' $R/codex/templates/.codex/agents/ant-verify.toml"
probe "Codex 侧缺 Unplanned 出口" \
  "ant-verify.toml: 缺 Unplanned 出口" \
  "sedi 's|Unplanned|Unplnnd|g' $R/codex/templates/.codex/agents/ant-verify.toml"
probe "codex/skills 混入 Claude 语法" \
  "codex/skills/ant-dispatch/SKILL.md: 含 Claude 专属语法 AskUserQuestion" \
  "printf '\nAskUserQuestion\n' >> $R/codex/skills/ant-dispatch/SKILL.md"
# 两侧产物不对等只测过「Codex 缺」方向（上面那条），这条补「Claude 缺」方向——
# 新增一个只在 Codex 侧存在的孤儿 slug，source 卡和 Claude 侧都没有它。
probe "Claude 侧缺产物（反向）" \
  "ghost: Claude 侧缺产物" \
  "cp $R/codex/templates/.codex/agents/ant-verify.toml $R/codex/templates/.codex/agents/ant-ghost.toml"
probe "一只产物都没有" \
  "没有任何产物，先跑 scripts/build.mjs" \
  "rm $R/plugins/ant/agents/*.md"
probe "Codex 清单不存在" \
  ".agents/plugins/marketplace.json: 清单不存在" \
  "rm $R/.agents/plugins/marketplace.json"
probe "Claude 清单解析失败" \
  ".claude-plugin/marketplace.json: 解析失败" \
  "printf ',' >> $R/.claude-plugin/marketplace.json"
probe "Codex 清单没声明 source" \
  ".agents/plugins/marketplace.json: 没声明 source" \
  "sedi 's|\"path\":|\"pathX\":|' $R/.agents/plugins/marketplace.json"
probe "Codex plugin.json 缺失" \
  "codex/.codex-plugin/plugin.json 不存在" \
  "rm $R/codex/.codex-plugin/plugin.json"
probe "hooks.json 解析失败" \
  "hooks/hooks.json: 解析失败" \
  "printf ',' >> $R/plugins/ant/hooks/hooks.json"
probe "hook command 没引用 PLUGIN_ROOT" \
  "PreToolUse 的 command 没引用" \
  "sedi 's|CLAUDE_PLUGIN_ROOT|CLAUDE_PLUGIN_ROOTX|' $R/plugins/ant/hooks/hooks.json"

say ""
say "结果 拦下 $pass 条 / 放行 $fail 条 / 打偏 $wrong 条"

status=0
node "$R/scripts/build.mjs" >/dev/null 2>&1
if node "$R/scripts/validate.mjs" >/dev/null 2>&1 && [ -z "$(git -C "$R" status --porcelain)" ]; then
  say "还原 工作区干净，validate 全绿"
else
  say "还原 异常——工作区没回到干净状态，需要人工看"
  status=1
fi
if [ "$fail" -ne 0 ] || [ "$wrong" -ne 0 ]; then
  status=1
fi

say "DONE"
exit "$status"
