# claude-app-setups

让**新手只装 Claude Code**，复制一句引导语，就由 Claude Code 自动装好各类应用。
本仓库是这些「安装 playbook」的**统一目录**：每个应用一个目录，遵循同一套执行契约。

## 怎么用（给新手）

1. 装好 Claude Code，打开任意空目录。
2. 复制对应应用的**引导语**（见各应用区块）粘贴给 Claude Code。
3. Claude Code 会 `curl` 抓取该应用的 `setup.md` 并逐步执行，需要你操作时会停下来叫你。

> 飞书 wiki / 公众号等只做“人类落地页”，放引导语即可；真正被抓取的是本仓库的 raw 文件。

## 应用清单

机器可读清单见 [`catalog.json`](./catalog.json)。

### OpenClaw

OpenClaw 网关 + 中转站模型 + 飞书。需要环境变量 `RELAY_API_KEY`。

```text
请按以下步骤帮我装好 OpenClaw，全程用中文跟我沟通：
1. 终端执行：export RELAY_API_KEY=sk-你的通用key
2. 终端执行：curl -fsSL https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/openclaw/setup.md -o setup.md
3. 读取 setup.md，严格按里面的步骤逐步执行，每步先校验，需要我操作时再叫我。
```

## 新增一个应用

1. 复制 [`_template/setup.md`](./_template/setup.md) 到 `apps/<app-id>/setup.md`，按模板的固定章节填内容。
2. 在 [`catalog.json`](./catalog.json) 的 `apps` 数组加一条（`id` / `name` / `setup` / `requiredEnv` / `platforms`）。
3. 在本 README「应用清单」加一个区块，附上该应用的引导语（只改 app 路径）。
4. raw 链接规则固定：`<rawBase>/apps/<app-id>/setup.md`，新增应用不影响已有链接。

## 设计约定（playbook 契约）

- 固定章节顺序：**预检 → 安装 → 配模型/凭证 → 接渠道 → 自验证 → 排障**。
- **文件内不含任何密钥**，全程读环境变量；密钥只放在受控的落地页引导语里。
- 每步带**校验门**，不过不进入下一步。
- 仅在确实需要人类操作（建应用、授权、扫码、粘贴凭证）时停下引导用户。
