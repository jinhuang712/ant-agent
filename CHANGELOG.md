# Changelog

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
