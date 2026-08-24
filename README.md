# ant-agent

给 Claude Code 和 Codex 配一队工蚁。主会话跑贵模型，只做编排、分析、决策、对话；一次性的调查、执行、等待，派给便宜模型去烧。

```
   ┌─────────────────────────────────────────────────────────┐
   │  主会话 · opus · 上下文是这里最贵的东西                    │
   └────────────────────────┬────────────────────────────────┘
                            │   「派个 ant:trace 去追这条链」
                            ▼
   ┌─────────────────────────────────────────────────────────┐
   │  ant:trace · sonnet · 一次性上下文，用完即弃               │
   │                                                         │
   │    find_symbol → Read → Bash → Grep → Read → …          │
   │    58 次工具调用 · 103,250 token 全部烧在这一格里          │
   └────────────────────────┬────────────────────────────────┘
                            │   回主线的只有下面这些
                            ▼
   ┌─────────────────────────────────────────────────────────┐
   │  上传 url → image_handler.go:88 → oss_client.go:142      │
   │           → image_repo.go:37 → tbl_activity_image        │
   │                                                         │
   │  每一跳带一个 pin，主会话照 pin 回原始现场核实             │
   │  它排除掉的死路也一并带回，省得有人再走一遍                │
   └─────────────────────────────────────────────────────────┘
```

那行结论出自一次真实排查。当时主会话自己干，21 分钟跑了 **88 次**读取调用，全堆在 opus 的上下文里。

几万 token 的探索换一行结论，而这行结论任何模型一看便知，也很容易验证。

**省的不只是单价，更是主会话的上下文**——它不会因为一次排查就被塞满。实测压缩比 32:1 到 67:1；派活时把返回形状收窄成一行，能到 540:1。

## 八只蚂蚁

**按认知状态认领，不按对象类型。** 目标是代码、配置、日志还是线上数据，不参与判断；手段是查、算、跑还是改，也不参与。

| ant | 我知道 | 我不知道 | model |
|---|---|---|---|
| `ant:locate` | 它是什么 | 它在哪 | sonnet |
| `ant:verify` | 它在哪 | 它的值是什么 | haiku |
| `ant:trace` | 两头 | 中间怎么连的 | sonnet |
| `ant:sift` | 什么算有用 | 有用的有哪些 | sonnet |
| `ant:census` | 我想要一个数 | 这数多少，以及什么算一个 | sonnet |
| `ant:adjust` | 每一步怎么做 | — | 按活选 |
| `ant:pardon` | 每一步怎么做，且不打算回看 | — | haiku |
| `ant:monitor` | 终态长什么样 | 什么时候到 | haiku |

这张表是认领时唯一的对照物。三对容易混的：

- **`locate` / `verify`** —— 指不出位置就是 locate；能指出位置、只是不知道那儿放着什么，才是 verify
- **`sift` / `census`** —— 要东西本身用 sift，要一个数用 census。census 的难点常常在「什么算一个」
- **`adjust` / `pardon`** —— 只差结果回不回来，而**判据是规模**：五条结果读起来便宜还能读出东西，四十条不行，报告本身比省下的活还贵

`ant:verify` 的主场是**铺开跑**：一批同构的小命题，一只一条，几十只并行，彼此独立、单价极低。

## 四条约定

**pin** —— 每条结论都带一个能回到原始现场的坐标。它定义了核实的含义：**主会话核 pin，不核推理**。

错的 pin 比错的结论更糟。错结论还有机会被抓住，错 pin 把抓住的机会一起拿走了。

**Unplanned** —— 每次回复的最后一栏，装蚂蚁撞见但没被问到的东西。它不参与格式坍缩，优先级高于其他栏：预期到的东西主会话自己也会想到问，预期不到的才值钱。

**格式归调用方，信息不归** —— 要一行就给一行，别把模板所有栏填满；但撞见重要的东西，模板里没位置也要说。

**蚂蚁是叶子** —— 不许再派下一层。够不着的活写进 `Unplanned`，让主会话决定。

完整的十条在 `shared/common-contract.md`，由生成器注入每份产物。

## 装

```bash
git clone https://github.com/jinhuang712/ant-agent ~/dev/skills/ant-agent
cd ~/dev/skills/ant-agent
node scripts/build.mjs      # 源卡 → 两侧产物
```

### Claude Code

两种装法，**装一种，别混**。

```bash
# A. 插件装（给使用者）——agents 和 hook 一起进来
claude plugin marketplace add jinhuang712/ant-agent
claude plugin install ant@ant

# B. 软链装（给改这个仓的人）——只搬 agents，改完跑 build 即生效
./install-claude.sh
```

| | 插件装 | 软链装 |
|---|---|---|
| `subagent_type` | `ant:sift` | `sift`（裸 slug，容易跟别的 agent 撞名） |
| 派发提醒 hook | **有** | 没有（`hooks/` 没人读） |
| 改完源卡 | build → commit → push → `claude plugin update ant@ant` | build 一步 |
| 装的是 | GitHub 远端快照 | 本地工作副本 |

混装的后果是八只各出现两份。换装法之前先拆掉另一种——软链拆 `rm ~/.claude/agents/*.md`，插件拆 `claude plugin uninstall ant`。

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

**Codex 的角色是项目级的**，住在 `<项目根>/.codex/agents/`，换个项目要再落一次。不带路径跑就只装 skill，之后让 `$ant:ant-dispatch` 自己 init。

仓里还有一套原生插件清单（`codex/.codex-plugin/plugin.json` 与 `.agents/plugins/marketplace.json`），`codex plugin add ant@ant` 实测能装上。运行时那半没验，见「已知限制」。

两侧的差别只在角色住哪：Claude 全局一份装完即用，Codex 每个项目一份。

## 一次派发长什么样

Claude 侧不用你敲命令——主会话读到自己的处境就该认领。你只会看到这一句：

```
派个 ant:sift 去扫远端。
```

它背后是一份任务书：判据、范围、要什么形状的返回、`Unplanned` 那一栏。回来之后主会话照 pin 核过，只把结论交给你。

**派发时必须显式传 `model`。** 这是最容易漏的一条——定义文件里的 `model` 两侧都不生效，不传就继承主会话的档位，降档收益全丢。插件装法带的 `PreToolUse` hook 会在派发那一刻把回收纪律贴到动作旁边。

Codex 侧走 `spawn_agent`：

```
spawn_agent({ agent_type: "ant-verify", model: "gpt-5.4-mini", message: "<任务书>" })
```

角色名两侧不同：Claude 有插件命名空间兜底，所以是 `ant:verify`；Codex 按项目里的文件名寻址、没有命名空间，保留 `ant-` 前缀防撞名。同一张源卡，两侧按各自的寻址规则渲染。

## 改一只蚂蚁

产物是生成的，**不要手改**——下次 build 会覆盖回去。改 `shared/roles/<slug>.md`，然后：

```bash
node scripts/build.mjs && node scripts/validate.mjs
```

八只共享的契约在 `shared/common-contract.md`，改一处八只全变。

软链装法改完即生效。插件装法还要 commit、push、`claude plugin update ant@ant`——更新按 `plugin.json` 的 `version` 判断，**内容改了不 bump 版本号，update 会回一句「already at the latest version」然后什么都不做**。

## 怎么保证它不烂掉

产物格式错了不会报错，只会**静默失效**：插件不加载、角色被忽略、hook 不执行——从外面看都跟正常一模一样。所以有两层机器检查。

**`scripts/validate.mjs`** —— 28 个 `fail()` 落点，覆盖 16 种独立失效模式。

包括：YAML 块标量折行、Claude 专属语法漏进 Codex 产物、清单声明的路径装不下产物目录、源卡加了但忘了 build、版本号跟 CHANGELOG 脱节、hook 引用的脚本不存在。

**`scripts/breakage-matrix.sh`** —— 29 个探针，逐条破坏上面每一条校验，确认它真的拦得住。

每个探针声明自己**预期的错误文案**。退出码非零但报的是别的错，判 `WRONG`（探针打偏了），跟 `MISS`（校验有洞）分开——只看退出码的话，一个顺带触发别的校验的破坏会伪装成通过。

CI 三步：build 后查产物是否同步 → `validate` → 破坏矩阵。

```bash
node scripts/build.mjs && node scripts/validate.mjs   # 改完源卡跑这个
bash scripts/breakage-matrix.sh                       # 改完 validate.mjs 再跑这个
```

第二层存在的理由是第一层骗得过人：**一条写坏的校验永远返回通过**，「校验跑过了」和「校验还有用」在 CI 里长得一样。这个矩阵自己也栽过同一个跟头——进 CI 之后连红四次没人发现，因为每次都只看本地结果。

## 设计决定

**不写 `tools` 白名单**，拿物理隔离换可移植性。

- MCP 工具名带着本地插件的命名空间（`mcp__plugin_<你的插件>_<server>__*`），写死了别人 clone 下去全是废名字
- 代价是蚂蚁继承主会话全部工具，`Edit`/`Write` 与派 subagent 的工具都在内
- 所以每只的正文里写死两条：默认只读，除非 dispatch 时显式授权；以及自己是叶子，不许再派下一层

**这个代价兑现过一次。** 契约里当时还没有「叶子」那条。

一只 `ant:sift` 收到任务 22 秒内、自己一条命令没跑，就把整份任务书原样转发给另一只 `ant:sift`；子层答完后，父层又重扫了一遍同样的文件。子层 93,782 token 已经够，这一支烧掉 173,997。

三层的 `model` 都碰巧传对了，但档位不继承——haiku 蚂蚁不传 `model`，活就落到舰队里最贵的模型上。

**一份源卡编译两份产物。** 八只在两个平台上语义相同，两边各写一份必然漂移。`shared/roles/*.md` 是唯一真相，Claude 的 `.md` 与 Codex 的 `.toml` 都由 `scripts/build.mjs` 生成，差异只在渲染层：命名空间、档位词汇、交叉引用的写法。

**环境专有纪律不写进蚂蚁定义。** 子 agent 会继承你的 `CLAUDE.md`，时区约定、搜索禁令、内部工具链这些各家不同的规矩交给它就行。蚂蚁定义只写「这个角色怎么干活」。

**给模型读的一律英文，给人读的中文。** 源卡、产物、共同契约是英文；README 与 CHANGELOG 是中文。

## 已知限制

- **`model:` frontmatter 不生效**（实测）。dispatch 时必须显式传 `model`，否则蚂蚁跑成主会话的档位，降档收益全丢。这条写进了每只的 description 当每轮提醒
- **想不起来派，只治了一半。** 蚂蚁靠 description 出现在每轮的可用列表里被想起来，跟 skill 是同一层机制。插件装法带的 `PreToolUse` hook 管的是「派出去之后怎么收」，不是「该派的时候想不想得起来」。后者仍然靠自觉
- **符号导航类 MCP 的 active project 是进程级状态**，跨仓并行会互相踩，跨仓请串行派
- **Codex 侧装得上，但没真派过蚂蚁**
  - 已验（真 codex CLI，隔离的 `CODEX_HOME`）：清单格式对、`plugin add` 能装上、目录跟源码 `codex/` 镜像、SKILL.md 里 `../../templates/` 这个相对路径在软链和拷贝两种装法下都成立
  - 没验的是运行时那半：`spawn_agent` 认不认自定义 `agent_type`，以及原生装法装完 dispatch skill 会不会被自动发现
- **`ant:pardon` 一次没被真派过。** 它要的规模（四十条起）这个仓产生不了。处境是真的，只是不在这里发生

## License

MIT
