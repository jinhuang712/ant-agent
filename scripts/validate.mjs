#!/usr/bin/env node
// 产物合规校验。产物格式错了不会报错只会静默失效，这是唯一的防线。
// 挂 CI，也在 install-*.sh 里跑一遍。
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const CLAUDE_OUT = join(ROOT, "plugins", "ant-agent", "agents");
const CODEX_OUT = join(ROOT, "codex", "templates", ".codex", "agents");
const CODEX_SKILLS = join(ROOT, "codex", "skills");

// Claude Code 专属语法。漏进 Codex 产物就是跨平台污染，而且不会报错只会静默失效。
const FORBIDDEN = [
  "$ARGUMENTS",
  "${CLAUDE_PLUGIN_ROOT}",
  "AskUserQuestion",
  "Agent(",
  "../../commands",
];
const TOML_KEYS = ["name", "description", "sandbox_mode", "developer_instructions"];

const errors = [];
const fail = (m) => errors.push(m);
const claudeSlugs = new Set();
const codexSlugs = new Set();

for (const f of readdirSync(CLAUDE_OUT).filter((n) => n.endsWith(".md"))) {
  const text = readFileSync(join(CLAUDE_OUT, f), "utf8");
  claudeSlugs.add(f.replace(/^ant-/, "").replace(/\.md$/, ""));
  if (!text.startsWith("---\n")) fail(`${f}: 缺 frontmatter`);
  // 匹配 model=<tier> 而不是整句——description 折成块标量后短语会被换行断开
  if (!/model=(haiku|sonnet|opus)\b/.test(text)) fail(`${f}: 缺 model 提醒`);
  if (!text.includes("Unplanned")) fail(`${f}: 缺 Unplanned 出口`);
  if (!/^name: ant-/m.test(text)) fail(`${f}: name 不是 ant-* 前缀`);

  // frontmatter 必须是合法 YAML。最常踩的坑是值里含「冒号 + 空格」——解析器会
  // 当成第二个 key 分隔符，整块 frontmatter 报废，而且没有任何运行时报错。
  const fmBlock = /^---\n([\s\S]*?)\n---\n/.exec(text);
  if (!fmBlock) {
    fail(`${f}: frontmatter 没有闭合`);
  } else {
    for (const line of fmBlock[1].split("\n")) {
      if (/^\s/.test(line) || !line.trim()) continue; // 缩进行属于块标量，跳过
      const kv = /^([a-z_]+):\s*(.*)$/.exec(line);
      if (!kv) { fail(`${f}: frontmatter 有不成 key 的裸行「${line.trim()}」`); continue; }
      if (kv[2] !== ">-" && /:\s/.test(kv[2])) {
        fail(`${f}: ${kv[1]} 的值里有「冒号+空格」，YAML 会解析失败——改用 >- 块标量`);
      }
    }
  }
}

for (const f of readdirSync(CODEX_OUT).filter((n) => n.endsWith(".toml"))) {
  const text = readFileSync(join(CODEX_OUT, f), "utf8");
  codexSlugs.add(f.replace(/^ant-/, "").replace(/\.toml$/, ""));
  // 报错指向源卡而不是产物——产物是生成的，改它没用，下次 build 就覆盖回去了
  const src = `shared/roles/${f.replace(/^ant-/, "").replace(/\.toml$/, "")}.md`;
  for (const tok of FORBIDDEN) {
    if (text.includes(tok)) {
      fail(`${f}: 含 Claude 专属语法 ${tok} —— 改 ${src} 或 shared/common-contract.md`);
    }
  }
  for (const m of text.matchAll(/^([a-z_]+)\s*=/gm)) {
    if (!TOML_KEYS.includes(m[1])) {
      fail(`${f}: 多余顶层键 ${m[1]}，Codex 会静默忽略整个角色`);
    }
  }
  if (!text.includes("Suggested model:")) fail(`${f}: 缺 model 提醒`);
  if (!text.includes("Unplanned")) fail(`${f}: 缺 Unplanned 出口`);
}

// codex/skills 下的 SKILL.md 与 references 同样是 Codex 侧产物，同一条禁词表
function walkMd(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walkMd(p));
    else if (e.name.endsWith(".md")) out.push(p);
  }
  return out;
}

if (existsSync(CODEX_SKILLS)) {
  for (const p of walkMd(CODEX_SKILLS)) {
    const text = readFileSync(p, "utf8");
    const rel = p.slice(ROOT.length + 1);
    for (const tok of FORBIDDEN) {
      if (text.includes(tok)) fail(`${rel}: 含 Claude 专属语法 ${tok}`);
    }
  }
}

for (const s of claudeSlugs) if (!codexSlugs.has(s)) fail(`${s}: Codex 侧缺产物`);
for (const s of codexSlugs) if (!claudeSlugs.has(s)) fail(`${s}: Claude 侧缺产物`);
if (!claudeSlugs.size) fail("没有任何产物，先跑 scripts/build.mjs");

// 两份 marketplace 清单声明的 source 路径，必须跟脚本实际写产物的地方对得上。
// 这是仓里唯一的静默失败模式：改了目录名而没同步清单，build 和上面所有校验都会通过
// （产物照样生成到旧位置），但插件不再被加载，而且没有任何报错。
const posix = (p) => p.split(sep).join("/");

function checkManifest(label, manifestPath, pick, mustContain) {
  if (!existsSync(manifestPath)) return fail(`${label}: 清单不存在`);
  let declared;
  try {
    declared = pick(JSON.parse(readFileSync(manifestPath, "utf8")));
  } catch (e) {
    return fail(`${label}: 解析失败 ${e.message}`);
  }
  if (!declared) return fail(`${label}: 没声明 source`);
  const target = resolve(ROOT, declared);
  const rel = posix(relative(target, mustContain));
  if (rel.startsWith("..")) {
    fail(`${label}: source 声明的 ${declared} 装不下产物目录 ` +
         `${posix(relative(ROOT, mustContain))} —— 插件会静默不加载`);
  }
}

checkManifest(
  ".claude-plugin/marketplace.json",
  join(ROOT, ".claude-plugin", "marketplace.json"),
  (j) => j.plugins?.[0]?.source,
  CLAUDE_OUT,
);
checkManifest(
  ".agents/plugins/marketplace.json",
  join(ROOT, ".agents", "plugins", "marketplace.json"),
  (j) => j.plugins?.[0]?.source?.path,
  CODEX_OUT,
);

// Claude 插件清单必须躺在 marketplace source 指向的那个目录里
const claudePluginJson = join(CLAUDE_OUT, "..", ".claude-plugin", "plugin.json");
if (!existsSync(claudePluginJson)) {
  fail("plugins/ant-agent/.claude-plugin/plugin.json 不存在 —— Claude 认不出这是个插件");
}
const codexPluginJson = join(ROOT, "codex", ".codex-plugin", "plugin.json");
if (!existsSync(codexPluginJson)) {
  fail("codex/.codex-plugin/plugin.json 不存在 —— Codex 认不出这是个插件");
}

if (errors.length) {
  console.error(errors.map((e) => `  ✗ ${e}`).join("\n"));
  console.error(`\n${errors.length} 处违规`);
  process.exit(1);
}
console.log(`  ✓ ${claudeSlugs.size} 只，两侧产物合规`);
