# ant-agent

给 Claude Code 配一队工蚁：主会话跑贵模型只做编排和决策，一次性的调查、执行、等待派给便宜模型。

## 一句话背景

一次真实排查里，主会话在 21 分钟内自己跑了 **88 次**读取调用，全堆在 Opus 的上下文里。而那次排查真正有用的结论只有一行：

```
上传 url → image_handler.go:88 → oss_client.go:142 → image_repo.go:37 → tbl_activity_image
```

几万 token 的探索，换一行结论。这行结论任何模型一看便知，也很好验证。

ant-agent 做的就是把探索赶进可丢弃的子上下文，只让那一行回到主线。省的不只是单价，还有主会话的上下文——它不会因为一次排查就被塞满。

## 八只蚂蚁

**按认知状态认领，不按对象类型。** 对象是代码、配置、日志还是线上数据，不参与判断。

| ant | 我知道 | 我不知道 | model |
|---|---|---|---|
| `ant-locate` | 它是什么 | 它在哪 | sonnet |
| `ant-verify` | 它在哪 | 它的值是什么 | haiku |
| `ant-trace` | 两头 | 中间怎么连的 | sonnet |
| `ant-sift` | 什么算有用 | 有用的有哪些 | sonnet |
| `ant-census` | 我想要一个数 | 这数多少，以及什么算一个 | sonnet |
| `ant-adjust` | 每一步怎么做 | — | 按活选 |
| `ant-pardon` | 每一步怎么做，且不打算回看 | — | haiku |
| `ant-monitor` | 终态长什么样 | 什么时候到 | haiku |

`ant-verify` 的主场是**铺开跑**：一批同构的小命题，一只一条，几十只并行，彼此独立、单价极低。

## 三条贯穿始终的约定

**pin** —— 每条结论都要带一个能回到原始现场的坐标。它定义了核实的含义：**主会话核 pin，不核推理**。

**Unplanned** —— 每次回复的最后一栏，装蚂蚁撞见但没被问到的东西。它不参与格式坍缩，而且优先级高于其他栏——预期到的东西主会话自己也会想到问，预期不到的才值钱。

**格式归调用方，信息不归** —— 要一行就给一行，别把模板所有栏填满；但撞见重要的东西，模板里没位置也要说。

## 装

```bash
git clone https://github.com/jinhuang712/ant-agent ~/dev/skills/ant-agent
cd ~/dev/skills/ant-agent
node scripts/build.mjs      # 源卡 → 两侧产物
```

### Claude Code

```bash
./install-claude.sh         # symlink 进 ~/.claude/agents/，八只全局可用
```

装完还要把授权片段并进你的 `CLAUDE.md`：

```bash
cat docs/CLAUDE.md.snippet
```

**这一步不能省。** Claude Code 的系统提示里带着一句「用户没要求就别调 AgentTool」，不写下授权，八只蚂蚁装了也不会被主动派出去。

### Codex

```bash
./install-codex.sh                          # 只装 dispatch skill
./install-codex.sh /abs/path/to/project     # 顺便把角色 TOML 落进那个项目
```

**Codex 的角色是项目级的**，住在 `<项目根>/.codex/agents/`，换个项目要再落一次。不带路径跑就只装 skill，之后让 `$ant-agent:ant-dispatch` 自己 init。

两侧的差别只在角色住哪：Claude 全局一份装完即用，Codex 每个项目一份。

## 改一只蚂蚁

产物是生成的，**不要手改**。改 `shared/roles/<slug>.md`，然后：

```bash
node scripts/build.mjs && node scripts/validate.mjs
```

symlink 装载，改完即生效，不用重装。八只共享的契约在 `shared/common-contract.md`，改一处八只全变。

## 设计决定

**不写 `tools` 白名单**，拿物理隔离换可移植性。

- MCP 工具名带着本地插件的命名空间（`mcp__plugin_<你的插件>_<server>__*`），写死了别人 clone 下去全是废名字
- 代价是蚂蚁继承主会话全部工具，`Edit`/`Write` 与派 subagent 的工具都在内
- 所以每只的正文里都写死了两条：默认只读，除非 dispatch 时显式授权；以及自己是叶子，不许再派下一层

**这个代价兑现过一次。** 契约里当时还没有「叶子」那条。

一只 `ant-sift` 收到任务 22 秒内、自己一条命令没跑，就把整份任务书原样转发给另一只 `ant-sift`；子层答完后，父层又重扫了一遍同样的文件。子层 93,782 token 已经够，这一支烧掉 173,997。

三层的 `model` 都碰巧传对了，但档位不继承——haiku 蚂蚁不传 `model`，活就落到舰队里最贵的模型上。

**环境专有纪律不写进蚂蚁定义。** 子 agent 会继承你的 `CLAUDE.md`，时区约定、搜索禁令、内部工具链这些各家不同的规矩交给它就行。蚂蚁定义只写「这个角色怎么干活」。

**给模型读的一律英文，给人读的中文。** 源卡、产物、共同契约是英文；README 和 `dev-docs/` 是中文。

## 已知限制

- **`model:` frontmatter 不生效**（实测）。dispatch 时必须显式传 `model`，否则蚂蚁会跑成主会话的模型，降档收益全丢。这条写进了每只的 description 当每轮提醒
- **想不起来派，这套东西解决不了。** 蚂蚁靠 description 出现在每轮的可用列表里被想起来，跟 skill 是同一层机制。真要每一步都盯着，得上 PreToolUse hook
- **符号导航类 MCP 的 active project 是进程级状态**，跨仓并行会互相踩，跨仓请串行派
- **Codex 侧已实现但未实测。** 角色 TOML、dispatch skill、插件清单、安装脚本都在，形状是照现有 Codex 插件推的，但三个假设一次没验：`spawn_agent` 认不认自定义 `agent_type`、skill 里的 init 相对路径装完还成不成立、marketplace 清单格式对不对

设计文档见 `dev-docs/`。

## License

MIT
