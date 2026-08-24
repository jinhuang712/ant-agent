# ant-agent

给 Claude Code 和 Codex 配一队工蚁。主会话跑贵模型只管编排和决策，翻代码、核事实、捞证据、跑命令、等终态这些一次性的活，派给便宜模型去烧。

```
   主会话 · 贵模型                  「派个 trace 去追这条链」
        │
        └──────────►  ant trace · 便宜模型 · 一次性上下文
                          find_symbol → Read → Bash → Grep → …
                          58 次工具调用 · 103,250 token 烧在这儿
                                    │
        ┌───────────────────────────┘  回来的只有这一行
        ▼
   上传 url → image_handler.go:88 → oss_client.go:142 → tbl_activity_image
   每一跳带一个 pin，你能照着回原始现场核
```

探索留在那个用完即弃的上下文里，主会话只多了一行。实测压缩比 32:1 到 67:1。

## 装

### Claude Code

```bash
curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash
```

装完重启 Claude Code，或者在会话里跑 `/reload-plugins`。

脚本做三件事：注册 marketplace、装插件、把授权片段并进 `~/.claude/CLAUDE.md`。第三件不能省——Claude Code 的系统提示里带着一句「用户没要求就别调 AgentTool」，不写下授权，八只装了也不会被主动派出去。改 `CLAUDE.md` 之前自动备份，重复跑安全。

### Codex

角色是**项目级**的，得指定落到哪个项目：

```bash
curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash -s -- --codex /abs/path/to/project
```

换个项目要再跑一次。不用 Claude Code 的话加 `--no-claude`，只装 Codex 这半。

## 用

**你不用敲任何命令。** 正常提需求，主会话遇到该派的活会自己认领：

```
你：这个接口返回的 currency 字段是从哪儿来的？

    ▸ 派个 trace 去追这条链。

    从 handler 到 DB 的完整链路：
      req → pricing_handler.go:44 → currency_resolver.go:88 → tbl_market_config
    第 88 行按 market_id 查表，缺省回落 USD（currency_resolver.go:102）
```

中间那一大段翻代码的过程不进你的上下文，也不进主会话的。

想手动指定用哪只，说名字就行：「派个 census 数一下这仓有多少个 i18n 文件」。

## 八只蚂蚁

**按你的认知状态挑，不按要查的东西是什么。** 代码、配置、日志、线上数据，都一样。

| 蚂蚁 | 我知道 | 我不知道 | 典型问法 |
|---|---|---|---|
| **locate** | 它是什么 | 它在哪 | 「限流配置写在哪个文件」 |
| **verify** | 它在哪 | 它的值是什么 | 「这个字段是 string 还是指针」 |
| **trace** | 两头 | 中间怎么连的 | 「这个值从接口到落库怎么走的」 |
| **sift** | 什么算有用 | 有用的有哪些 | 「这堆日志里有哪些是超时」 |
| **census** | 我想要一个数 | 这数多少 | 「有多少个接口没加鉴权」 |
| **adjust** | 每一步怎么做 | — | 「把这 20 个文件的 import 改了」 |
| **pardon** | 每一步怎么做，也不打算看结果 | — | 「这 40 个都改一遍，别汇报」 |
| **monitor** | 终态长什么样 | 什么时候到 | 「盯着这个 CI，跑完告诉我」 |

三对容易混的：

- **locate / verify** —— 指不出位置就是 locate；能指出位置、只是不知道那儿放着什么，才是 verify
- **sift / census** —— 要东西本身用 sift，要一个数用 census
- **adjust / pardon** —— 只差结果回不回来。五条结果读起来便宜还有用，四十条不如不看

### 两边的写法不一样

| | Claude Code | Codex |
|---|---|---|
| 名字 | `ant:trace` | `ant-trace` |
| 怎么派 | `Agent(subagent_type: "ant:trace", model: …)` | `spawn_agent({ agent_type: "ant-trace", model: … })` |
| 角色住哪 | 全局，装完即用 | 每个项目一份 |

Claude 有插件命名空间兜底所以是冒号，Codex 按项目里的文件名寻址、没有命名空间，就保留 `ant-` 前缀防撞名。同一张源卡，两侧按各自的规则渲染。

### 档位

**轻档**跑 verify、pardon、monitor；**重档**跑 locate、trace、sift、census；adjust 按活选——机械批量走轻档，要改文件或步骤需要判断走重档。

| | 轻档 | 重档 |
|---|---|---|
| Claude Code | haiku | sonnet |
| Codex | gpt-5.4-mini | gpt-5.4 |

**派发时必须显式传 `model`。** 角色定义文件里写的档位两侧都不生效，不传就继承主会话的档位，省钱那部分全丢。

## 每只蚂蚁都欠你的

**pin** —— 每条结论带一个能回到原始现场的坐标（`文件:行号`、完整查询语句、可点的 URL）。核实的方式是**照 pin 回去看原文**，不是审它的推理过程。

**Unplanned** —— 回复最后一栏，装它撞见但你没问到的东西。这栏经常比你问的那部分值钱。

**说不准就说不准** —— 范围内没找到、找到几个互相矛盾的、拿不准是不是要问的那个，都得说出来，不许猜。

## 卸

```bash
claude plugin uninstall ant                  # Claude 侧
rm <项目>/.codex/agents/ant-*.toml           # Codex 侧，每个装过的项目都要
```

`~/.claude/CLAUDE.md` 里那段授权片段要自己删，找 `<!-- ant-agent:授权片段` 开头那行。

## License

MIT
