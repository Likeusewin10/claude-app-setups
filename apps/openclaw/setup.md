# 用 Claude Code 一键装好 OpenClaw（中转站模型 + 飞书）

> 这是给 **Claude Code** 读并逐步执行的指令文档（playbook）。
> 面向**完全新手**：用户只装了 Claude Code，其余全部由你（Claude Code）代劳。
> 全程读环境变量 `RELAY_API_KEY`，本文件内**不含任何密钥**，可安全公开托管 / 被 curl 抓取。

---

## 给分发者（不是给 Claude Code 执行）

本文件由 catalog 仓库统一托管：`Likeusewin10/claude-app-setups`，canonical raw 地址为
`https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/openclaw/setup.md`。
飞书 wiki 页面做“落地页”，放下面这段**引导语**让新手复制。
**关键**：第 1 步由用户在终端执行、并在同一终端启动 Claude Code，env 才能被继承（Claude Code 跨命令不保留 env，不能让它自己 export）。

终端先执行：

```bash
export RELAY_API_KEY=sk-你的通用key
claude
```

再发给 Claude Code：

```text
请帮我装好 OpenClaw，全程用中文沟通：
1. 先执行 printf '%s\n' "${RELAY_API_KEY:+set}" 确认能读到 RELAY_API_KEY（应输出 set）；为空就停下让我先 export 再重启你。
2. 执行：curl -fsSL https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/openclaw/setup.md -o setup.md
3. 读取 setup.md，严格按步骤逐步执行，每步先校验，需要我操作时再叫我。
```

- 密钥 `sk-...` 只出现在你受控的飞书 wiki 落地页里，**不要写进本文件或仓库**。
- 用 `curl 下载到本地再读`，比让 Claude Code 直接 WebFetch 在线页更稳（不受域名白名单/JS 渲染影响）。

---

## 给 Claude Code：执行总则

- 你的目标：把 OpenClaw 装好、用中转站配好模型、接入飞书、最后**自我验证打通**。
- 平台假设 macOS / Linux。Windows 见末尾「Windows 备注」。
- **逐步执行，每步带校验门**：校验不过不要进入下一步，先看 `openclaw logs --follow` 排查并告诉用户结论。
- 只有以下环节需要**用户本人**操作，到时停下来清楚地引导他：在飞书开放平台建应用 / 授权 / 发布 / 把机器人拉进群 / 在飞书里发测试消息。其余命令你自己跑。
- 先确认 `RELAY_API_KEY` 已设置：`printf '%s' "${RELAY_API_KEY:+set}"`（应输出 `set`）。若为空，**停下**让用户在终端 `export RELAY_API_KEY=sk-...` 后**重启 Claude Code**（env 不跨命令保留，你自己 export 无效）。

---

## 第 0 步 · 环境预检

```bash
node --version
```

- 需要 Node ≥ 22.19（推荐 24）。版本不够或没装也没关系，下一步的安装脚本会补 Node。

校验门：能打印版本即可继续；命令不存在也继续（安装脚本会装 Node）。

---

## 第 1 步 · 安装 OpenClaw

```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

装完刷新 PATH 并校验：

```bash
hash -r 2>/dev/null || true
openclaw --version
```

校验门：`openclaw --version` 打印出版本号。
若提示 `command not found`：让用户**新开一个终端窗口**再试（PATH 未刷新），或参考 https://docs.openclaw.ai/install/node#troubleshooting 。

---

## 第 2 步 · 非交互 onboard（接入 qqqrouter 中转站，模型 gpt-5.5）

```bash
openclaw onboard --non-interactive --mode local \
  --auth-choice custom-api-key \
  --custom-base-url "https://console.qqqrouter.ai/v1" \
  --custom-model-id "gpt-5.5" \
  --custom-api-key "$RELAY_API_KEY" \
  --custom-provider-id "qqqrouter" \
  --custom-compatibility openai \
  --secret-input-mode plaintext \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --json
```

校验门：命令退出码为 0、JSON 摘要正常。
说明：这会把网关装成本机守护进程（loopback:18789），并把 `qqqrouter/gpt-5.5` 设为默认模型。

---

## 第 3 步 · 校验网关 + 模型真的能回话

```bash
openclaw gateway status
```

应看到网关在 `18789` 监听。然后做一次最小模型探活：

```bash
openclaw infer model run --model "qqqrouter/gpt-5.5" "只回复两个字：OK"
```

> 若该子命令参数报错，先跑 `openclaw infer model run --help` 看实际用法再探活。

校验门：模型返回了文本（例如 `OK`）。
**如果探活失败且报与接口路径/格式有关的错**（如 4xx、`chat/completions` 不支持），把兼容模式切到 responses 再重配模型：

```bash
openclaw config set models.providers.qqqrouter.api "openai-responses"
openclaw gateway restart
# 再次探活
openclaw infer model run --model "qqqrouter/gpt-5.5" "只回复两个字：OK"
```

仍失败则：确认 `RELAY_API_KEY` 有效、`https://console.qqqrouter.ai/v1` 可达、模型名 `gpt-5.5` 在中转站存在。把结论告诉用户。

到这里**模型已配好**。如果用户暂时不接飞书，可让他 `openclaw dashboard` 在浏览器里直接聊天。

---

## 第 4 步 · 安装飞书插件

```bash
openclaw plugin add @openclaw/feishu
openclaw plugins list | grep -i feishu
```

校验门：`plugins list` 里出现 feishu。

---

## 第 5 步 · 引导用户拿飞书应用凭证（这一步需要用户操作）

清楚地告诉用户去 **飞书开放平台** https://open.feishu.cn/app 完成（Lark 用 https://open.larksuite.com ）：

1. **创建自建应用**，记下 **App ID**（形如 `cli_xxx`）和 **App Secret**。
2. 开启 **机器人（Bot）** 能力。
3. **事件订阅**：添加事件 `im.message.receive_v1`；连接方式选 **长连接 / WebSocket**（不要选 webhook）。
4. **权限管理**：授予「接收消息」「发送消息」等 IM 权限（如 `im:message`、`im:message:send_as_bot` 等读取/发送消息范围）。
5. **创建版本并发布**，等待生效/审批通过。

然后让用户把 **App ID** 和 **App Secret** 贴给你。

---

## 第 6 步 · 写入飞书凭证并重启网关（你来跑）

拿到凭证后（把 `<APP_ID>` / `<APP_SECRET>` 换成用户给的值）：

```bash
openclaw config set channels.feishu.accounts.default.appId "<APP_ID>"
openclaw config set channels.feishu.accounts.default.appSecret "<APP_SECRET>"
openclaw config set channels.feishu.enabled true
openclaw config set channels.feishu.dmPolicy "pairing"
openclaw gateway restart
```

- `dmPolicy=pairing`：陌生人首次私聊机器人会拿到配对码，由你审批后才能对话（适合新手私聊自测）。
- 安全增强（可选）：不想把 App Secret 明文存进 `openclaw.json`，可改用环境变量引用：
  ```bash
  export FEISHU_APP_SECRET="<APP_SECRET>"
  openclaw config set channels.feishu.accounts.default.appSecret \
    --ref-provider default --ref-source env --ref-id FEISHU_APP_SECRET
  ```

校验门：`openclaw gateway status` 正常；`openclaw config get channels.feishu.enabled` 为 true。

---

## 第 7 步 · 配对放行（用户私聊 + 你审批）

1. 让用户在飞书里**给机器人发一条私聊消息**（如「你好」）。
2. 你查看待配对请求并放行：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

校验门：approve 成功，无报错。

---

## 第 8 步 · 端到端自验证（成功标准）

开一个日志跟随窗口，观察入站事件：

```bash
openclaw logs --follow
```

让用户在飞书里再发一条消息，你确认：

- 日志出现入站事件 `im.message.receive_v1`；
- 机器人**在飞书里回复了**，且内容来自 `qqqrouter/gpt-5.5`。

满足即**全部打通**，向用户报告成功，并给出常用指令：飞书里直接发文本 `/status`、`/model`、`/reset`（飞书不支持斜杠菜单，发纯文本即可）。

群聊补充：若要在群里用，引导用户**把机器人拉进群**并 **@机器人**（默认需要 @）；需要的话可放开：

```bash
openclaw config set channels.feishu.groupPolicy "open"
openclaw gateway restart
```

---

## 排障速查

机器人收不到消息：
1. 应用已**发布且审批通过**；
2. 事件订阅含 `im.message.receive_v1`；
3. 连接方式是**长连接 / WebSocket**；
4. 所需权限 scope 已授予；
5. 网关在跑：`openclaw gateway status`；
6. 看日志：`openclaw logs --follow`。

模型不回话：回到第 3 步，先 `openclaw infer model run` 探活；必要时把 `models.providers.qqqrouter.api` 在 `openai` / `openai-responses` 间切换并 `openclaw gateway restart`。

App Secret 泄露：在开放平台重置 Secret → `openclaw config set channels.feishu.accounts.default.appSecret "<新值>"` → `openclaw gateway restart`。

---

## Windows 备注

第 1 步改用 PowerShell：

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

其余命令一致；环境变量用 `setx RELAY_API_KEY "sk-..."`（新开终端生效）或当前会话 `$env:RELAY_API_KEY="sk-..."`。

---

## 参考（官方文档）

- 安装：https://docs.openclaw.ai/start/getting-started ・ https://docs.openclaw.ai/install/installer
- 非交互 onboard：https://docs.openclaw.ai/start/wizard-cli-automation ・ https://docs.openclaw.ai/cli/onboard
- 飞书：https://docs.openclaw.ai/channels/feishu
- 配置 CLI：https://docs.openclaw.ai/cli/config ・ 探活：https://docs.openclaw.ai/cli/infer
