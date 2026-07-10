# claude-app-setups

让**新手只装一个 AI 编程助手**，复制一句引导语，就由 Claude Code 或 Codex 自动装好各类应用和技能。
本仓库是这些「安装 playbook」的**统一目录**：每个应用或技能包一个目录，遵循同一套执行契约。

## 怎么用（给新手）

1. 装好 Claude Code 或 Codex，打开任意空目录。
2. 复制对应条目的**引导语**（见各区块）粘贴给 AI。
3. AI 会读取对应的 `setup.md` 并逐步执行，需要你操作时会停下来叫你。

> 飞书 wiki / 公众号等只做“人类落地页”，放引导语即可；真正被抓取的是本仓库的 raw 文件。

## 应用清单

机器可读清单见 [`catalog.json`](./catalog.json)。

### OpenClaw

OpenClaw 网关 + 中转站模型 + 飞书。需要环境变量 `RELAY_API_KEY`。

**先在终端 export，再在同一终端启动 Claude Code**（这样 key 被 claude 继承；Claude Code 跨命令不保留 env，不能让它自己 export）：

```bash
export RELAY_API_KEY=sk-你的通用key
claude
```

再把这段发给 Claude Code：

```text
请帮我装好 OpenClaw，全程用中文沟通：
1. 先执行 printf '%s\n' "${RELAY_API_KEY:+set}" 确认能读到 RELAY_API_KEY（应输出 set）；为空就停下让我先 export 再重启你。
2. 执行：curl -fsSL https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/openclaw/setup.md -o setup.md
3. 读取 setup.md，严格按步骤逐步执行，每步先校验，需要我操作时再叫我。
```

### Codex 生图 / 生视频 Skills

为 Codex 安装两个可在 UI 展示的技能：APINebula `gpt-image-2` 生图/改图，以及火山方舟 Seedance 生视频。安装本身不需要 API Key；首次使用时 Codex 会分别安全引导配置 `NEBULA_API_KEY` 和 `ARK_API_KEY`，不要把 Key 发进聊天。

最简单的方式：只把这个 Raw 链接发给 Codex：

```text
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/setup.md
```

如需明确语言，也可以在链接前补一句：“请安装链接里的两个 Codex skill，全程用中文，不要让我把 API Key 发到聊天。”

## 新增一个应用

1. 复制 [`_template/setup.md`](./_template/setup.md) 到 `apps/<app-id>/setup.md`，按模板的固定章节填内容；skill 包可把完整 skill 目录放在同一个 app 目录下。
2. 在 [`catalog.json`](./catalog.json) 的 `apps` 数组加一条（`id` / `name` / `setup` / `requiredEnv` / `platforms`）。
3. 在本 README「应用清单」加一个区块，附上该应用的引导语（只改 app 路径）。
4. raw 链接规则固定：`<rawBase>/apps/<app-id>/setup.md`，新增应用不影响已有链接。
5. 修改 Codex 媒体 skill 或校验清单后，发布前运行 `ruby apps/codex-media-skills/validate.rb`，避免 Raw 路径或 SHA-256 漂移。

## 设计约定（playbook 契约）

- 固定章节顺序：**预检 → 安装 → 配模型/凭证 → 接渠道 → 自验证 → 排障**。
- **新 playbook 文件内不含任何密钥**；新接入的凭据只通过 Secret UI、系统钥匙串、Secret Manager 或受控环境注入，绝不要求用户把 Key 发进聊天。
- 每步带**校验门**，不过不进入下一步。
- 仅在确实需要人类操作（建应用、授权、扫码、安全配置凭据）时停下引导用户。
