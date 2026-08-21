#!/usr/bin/env node
// 派发一只蚂蚁时，把回收纪律贴到动作旁边。
//
// 为什么需要它：纪律本身早就写在 CLAUDE.md 里，但那是每轮都在的背景噪音——实测七个
// session，「一件事拆成派发公告、进度汇报、部分答案、剩下的答案」六个全中，约 24 次。
// 同一句话紧贴着派发动作出现，比躺在系统提示里管用。
//
// 输出走 hookSpecificOutput.additionalContext——静默进上下文，不渲染成报错。
// 对比 exit 2 + stderr：那条路每次派发都会弹一次红字，八次派发八次「hook blocking
// error」，噪音比它要治的毛病还大。
import { readFileSync } from "node:fs";

const EVENT = "PreToolUse";

const emit = (additionalContext = "") => {
  process.stdout.write(
    JSON.stringify({ hookSpecificOutput: { hookEventName: EVENT, additionalContext } }),
  );
  process.exit(0);
};

let payload;
try {
  payload = JSON.parse(readFileSync(0, "utf8"));
} catch {
  emit(); // 读不到 payload 就别挡路
}

// 只认 ant:<slug>。这个 hook 只在插件装法下被加载，而插件装法的 subagent_type 一定带
// 命名空间——软链装法压根不读 hooks/，不用为它的裸名留后门。锚定两端，别用 startsWith：
// 前缀匹配会把任何以 ant 开头的别家命名空间一起吃进来。
const slug = payload?.tool_input?.subagent_type ?? "";
if (!/^ant:[a-z]+$/.test(slug)) emit(); // 别的 subagent 不归这条纪律管

emit(
  `<!-- ant-agent:dispatch -->\n` +
    `${slug} 已派出。回收纪律：先核它给的 pin，再写字。还有别的蚂蚁在飞就继续干活——` +
    `turn 的内容可以是工具调用，不必是文字。到齐了一次成文，只留结论与需要用户拍板的决策项。`,
);
