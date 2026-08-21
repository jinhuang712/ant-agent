# Changelog

## 0.2.1 — 2026-08-21

### 校验自己也有洞

派 `ant-census` 数「`validate.mjs` 到底有几条校验」——27 处 `fail()` 折成 **16 个独立失效模式**。它在 `Unplanned` 里报了两件我没问的：

- **一条死重复。** 文件不以 `---` 开头时，「缺 frontmatter」和「frontmatter 没有闭合」必然同时触发，同一个缺陷报出两条措辞。删掉前者，后者措辞改成能同时覆盖两种情况
- **一个洞，正是这个文件通篇想防的那类。** 成对性校验只比较两侧产物是否对齐，从不回头对照 `shared/roles/`。源卡加了却忘了跑 build，两侧的空缺天然成对，校验完全感知不到。补上以源卡为基准的双向核对：源卡有产物没有、产物有源卡没有，都 fail

顺带澄清：CHANGELOG 里那些「第 9 条」「第 11 条」是**添加时的时点序号**，不是当前总数——同一节里 9 和 11 并存就是证据。当前总数 16。

## 0.2.0 — 2026-08-21

### 蚂蚁是叶子

共同契约加第十条 **You are a leaf**：不许再派下一层，够不着的活写进 `Unplanned` 让调用方决定。

起因是一次真实事故——一只 `ant-sift` 在收到任务 22 秒内、自己一条命令没跑，就把整份任务书原样转发给另一只 `ant-sift`；子层答完之后，父层又把同一批文件重扫了一遍，最后交了一份转述。子层 93,782 token 已经够了，这一支实际烧掉 173,997。

三层 `model` 都碰巧传对了，但没有任何机制保证这一点：档位不继承，一只 haiku 蚂蚁不传 `model` 就能把活交给舰队里最贵的模型。

### 源卡加 thought

处境句描述的是第三人称的认知状态，准确，但模型伸手去调工具那一刻不会把自己的处境形式化成「我知道 X 不知道 Y」。`thought` 是同一个状态的第一人称当下表述——`"let me just check that."`、`"where is that actually defined?"`。

两句管两件事：`situation` 管认领**准确**（`ant-sift` 和 `ant-census` 不混），`thought` 管认领**发生**。

### 派发与收活都是静默的

派一句话，收只给结论。把蚂蚁的返回原样转贴回主线，等于把压缩掉的 token 又倒回去。

**先回的那只，拿等待期核它的 pin。** 扫了七个用过蚂蚁的 session，最普遍的缺陷不是话术而是节奏：一件事被拆成派发公告、等待汇报、结果分批到达好几段输出，六个 session 全中约 24 次。

根因是机制不是态度——后台蚂蚁完成会唤醒主会话，而被唤醒必须产出一个 turn。禁止说话没用，它给不出替代动作；**turn 的内容可以是工具调用**，而先回那只的 pin 本来就要核。

### 派发时把回收纪律贴到动作旁边

新增 `PreToolUse` hook（`plugins/ant-agent/hooks/`），匹配 `Agent` 工具、只对 `ant-*` 生效，派发时静默注入一句回收纪律。

纪律本身早就写在 CLAUDE.md 里，但那是每轮都在的背景噪音，24 次照犯。同一句话紧贴着派发动作出现，距离不一样。**这是 plugin 唯一能自带、装上就生效的机制**——agent 定义装得进去，用户的 CLAUDE.md 装不进去，`docs/CLAUDE.md.snippet` 只能靠人手抄。

走 `hookSpecificOutput.additionalContext` 静默进上下文，不是 `exit 2 + stderr`——后者每次派发都渲染成一次 hook blocking error，八次派发八次红字，噪音比它要治的毛病还大。

选 `PreToolUse` 而不是 `PostToolUse`：两者对这个用途时机等价（同一个 assistant turn 内），但前者的 `additionalContext` 本机有正在运行的实例佐证，后者只有文档——而文档在 `Stop` 的同类问题上错过一次，且这次自己前后两处格式还不一致。

### 装成插件后蚂蚁改名了

Claude 侧装成插件，`subagent_type` 带上插件命名空间：`ant-sift` → `ant-agent:ant-sift`。软链装法仍是裸名。两处跟着改：

- **产物 description 里的交叉引用补前缀**。`use ant-census` 这类不是普通说明文字——description 每轮原样注入调用方的系统提示，照抄去当 `subagent_type` 传就会找不到 agent。生成器只对 Claude 侧的 description 做替换：正文不管（只有蚂蚁自己读，而它不许再派），Codex 侧也不管（那边按项目级 TOML 文件名寻址，没有命名空间）
- **派发提醒 hook 的匹配改严**。原来写的是 `startsWith("ant-")`，能过纯属插件自己也叫 `ant-agent` 这层巧合，换个同样以 `ant-` 开头的命名空间就会误触发。改成 `/^(ant-agent:)?ant-[a-z]+$/`，两种装法都认

第 11 条校验：Claude 侧 description 里出现裸名直接 fail。

README 与 `install-claude.sh` 补上两种装法的对照——形状、hook 有没有、改完源卡要走几步，以及混装会让八只各出现两份。

### 修

- **`ant-adjust` 的 description 自相矛盾**：生成器无差别拼「Always pass model=haiku」，而这只按活选档，自己还说着「edits 用 sonnet」。源卡新增可选字段 `model_rule` 覆盖那句默认文案
- `scripts/validate.mjs` 加第 9 条：同一段 description 里出现两个不同档位直接 fail，除非源卡声明了 `model_rule`

## 0.1.0 — 2026-08-20

首个版本。

### 八只蚂蚁

按**认知状态**认领，不按对象类型——对象是代码、配置、日志还是线上数据，不参与判断。

| ant | 我知道 | 我不知道 |
|---|---|---|
| `ant-locate` | 它是什么 | 它在哪 |
| `ant-verify` | 它在哪 | 它的值是什么 |
| `ant-trace` | 两头 | 中间怎么连的 |
| `ant-sift` | 什么算有用 | 有用的有哪些 |
| `ant-census` | 我想要一个数 | 这数多少，以及什么算一个 |
| `ant-adjust` | 每一步怎么做 | — |
| `ant-pardon` | 每一步怎么做，且不打算回看 | — |
| `ant-monitor` | 终态长什么样 | 什么时候到 |

### 机制

- **一份源卡编译两份产物**：`shared/roles/*.md` 生成 Claude 的 `agents/*.md` 与 Codex 的 `.codex/agents/*.toml`，两侧不会漂移
- **九条共同契约**注入每份产物，改一处八只全变
- **pin**：每条结论都带能回到原始现场的坐标，核实的操作定义是「核 pin 不核推理」
- **Unplanned**：每次回复末尾一栏，装蚂蚁撞见但调用方没问的东西，不参与格式坍缩
- **格式归调用方，信息不归**：要一行给一行，但撞见重要的东西没位置也要说

### 工具

- `scripts/build.mjs` — 源卡 → 两侧产物
- `scripts/validate.mjs` — 八条校验，含 YAML 合法性、跨平台语法污染、清单与产物目录一致性
- `install-claude.sh` / `install-codex.sh` — symlink 装载，装前跑 validate
- CI 校验产物与源卡同步

### 已知限制

- 角色定义文件里的 `model` 两侧都不生效，必须 dispatch 时显式传
- Claude 侧不写 `tools` 白名单换可移植性，只有文字约束没有物理隔离
- Codex 侧角色是**项目级**的，每个新项目要 init 一次
- 「想不起来派」这套东西解决不了，它靠 description 出现在可用列表里被想起来
