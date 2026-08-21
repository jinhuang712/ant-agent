# Changelog

## 未发布

### 蚂蚁是叶子

共同契约加第十条 **You are a leaf**：不许再派下一层，够不着的活写进 `Unplanned` 让调用方决定。

起因是一次真实事故——一只 `ant-sift` 在收到任务 22 秒内、自己一条命令没跑，就把整份任务书原样转发给另一只 `ant-sift`；子层答完之后，父层又把同一批文件重扫了一遍，最后交了一份转述。子层 93,782 token 已经够了，这一支实际烧掉 173,997。

三层 `model` 都碰巧传对了，但没有任何机制保证这一点：档位不继承，一只 haiku 蚂蚁不传 `model` 就能把活交给舰队里最贵的模型。

### 源卡加 thought

处境句描述的是第三人称的认知状态，准确，但模型伸手去调工具那一刻不会把自己的处境形式化成「我知道 X 不知道 Y」。`thought` 是同一个状态的第一人称当下表述——`"let me just check that."`、`"where is that actually defined?"`。

两句管两件事：`situation` 管认领**准确**（`ant-sift` 和 `ant-census` 不混），`thought` 管认领**发生**。

### 派发与收活都是静默的

派一句话，收只给结论。把蚂蚁的返回原样转贴回主线，等于把压缩掉的 token 又倒回去。

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
