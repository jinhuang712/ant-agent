# ant-agent

给 Claude Code 配一队工蚁。主会话跑贵模型只管编排和决策，翻代码、核事实、捞证据、跑命令、等终态这些一次性的活，派给便宜模型去烧。

```
   主会话 · opus                  「派个 ant:trace 去追这条链」
        │
        └──────────►  ant:trace · sonnet · 一次性上下文
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

```bash
curl -fsSL https://raw.githubusercontent.com/jinhuang712/ant-agent/main/install.sh | bash
```

装完重启 Claude Code，或者在会话里跑 `/reload-plugins`。

脚本做三件事：注册 marketplace、装插件、把授权片段并进 `~/.claude/CLAUDE.md`。第三件不能省——Claude Code 的系统提示里带着一句「用户没要求就别调 AgentTool」，不写下授权，八只蚂蚁装了也不会被主动派出去。

改 `CLAUDE.md` 之前会自动备份，重复跑安全。

## 用

**你不用敲任何命令。** 正常提你的需求，主会话遇到该派的活会自己认领：

```
你：这个接口返回的 currency 字段是从哪儿来的？

    ▸ 派个 ant:trace 去追这条链。

    从 handler 到 DB 的完整链路：
      req → pricing_handler.go:44 → currency_resolver.go:88 → tbl_market_config
    第 88 行按 market_id 查表，缺省回落 USD（currency_resolver.go:102）
```

中间那一大段翻代码的过程不会进你的上下文，也不会进主会话的。

想手动指定用哪只，说名字就行：「派个 ant:census 数一下这仓有多少个 i18n 文件」。

## 八只蚂蚁

**按你的认知状态挑，不按要查的东西是什么。** 代码、配置、日志、线上数据，都一样。

| ant | 我知道 | 我不知道 | 典型问法 |
|---|---|---|---|
| `ant:locate` | 它是什么 | 它在哪 | 「限流配置写在哪个文件」 |
| `ant:verify` | 它在哪 | 它的值是什么 | 「这个字段是 string 还是指针」 |
| `ant:trace` | 两头 | 中间怎么连的 | 「这个值从接口到落库怎么走的」 |
| `ant:sift` | 什么算有用 | 有用的有哪些 | 「这堆日志里有哪些是超时」 |
| `ant:census` | 我想要一个数 | 这数多少 | 「有多少个接口没加鉴权」 |
| `ant:adjust` | 每一步怎么做 | — | 「把这 20 个文件的 import 改了」 |
| `ant:pardon` | 每一步怎么做，也不打算看结果 | — | 「这 40 个都改一遍，别汇报」 |
| `ant:monitor` | 终态长什么样 | 什么时候到 | 「盯着这个 CI，跑完告诉我」 |

三对容易混的：

- **locate / verify** —— 指不出位置就是 locate；能指出位置、只是不知道那儿放着什么，才是 verify
- **sift / census** —— 要东西本身用 sift，要一个数用 census
- **adjust / pardon** —— 只差结果回不回来。五条结果读起来便宜还有用，四十条不如不看

## 每只蚂蚁都欠你的

**pin** —— 每条结论带一个能回到原始现场的坐标（`文件:行号`、完整查询语句、可点的 URL）。核实的方式是**照 pin 回去看原文**，不是审它的推理过程。

**Unplanned** —— 回复最后一栏，装它撞见但你没问到的东西。这栏经常比你问的那部分值钱。

**说不准就说不准** —— 范围内没找到、找到几个互相矛盾的、拿不准是不是要问的那个，都得说出来，不许猜。

## Codex

```bash
git clone https://github.com/jinhuang712/ant-agent && cd ant-agent
./install-codex.sh /abs/path/to/your/project
```

Codex 的角色是**项目级**的，住在 `<项目根>/.codex/agents/`，换个项目要再落一次。派发写 `spawn_agent({ agent_type: "ant-verify", model: "gpt-5.4-mini", … })`——那边没有命名空间，所以名字保留 `ant-` 前缀。

Codex 侧装得上，但没在真实会话里派过蚂蚁。

## 卸

```bash
claude plugin uninstall ant
```

`~/.claude/CLAUDE.md` 里那段授权片段要自己删，找 `<!-- ant-agent:授权片段` 开头那行。

## License

MIT
