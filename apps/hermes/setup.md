# 用 Claude Code 一键装好 Hermes（中转站模型 + 飞书）

> 这是给 **Claude Code** 读并逐步执行的指令文档（playbook）。
> 面向**完全新手**：用户只装了 Claude Code，其余全部由你（Claude Code）代劳。
> 全程读环境变量 `RELAY_API_KEY`，本文件内**不含任何密钥**，可安全公开托管 / 被 curl 抓取。

---

## 给分发者（不是给 Claude Code 执行）

本文件由 catalog 仓库统一托管：`Likeusewin10/claude-app-setups`，canonical raw 地址为
`https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/hermes/setup.md`。
飞书 wiki 页面做“落地页”，放下面这段**引导语**让新手复制。
**关键**：第 1 步由用户在终端执行、并在同一终端启动 Claude Code，env 才能被继承（Claude Code 跨命令不保留 env，不能让它自己 export）。

终端先执行（macOS / Linux）：

```bash
export RELAY_API_KEY=sk-你的通用key
claude
```

再发给 Claude Code：

```text
请帮我装好 Hermes，全程用中文沟通：
1. 先执行 printf '%s\n' "${RELAY_API_KEY:+set}" 确认能读到 RELAY_API_KEY（应输出 set）；为空就停下让我先 export 再重启你。
2. 执行：curl -fsSL https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/hermes/setup.md -o setup.md
3. 读取 setup.md，严格按步骤逐步执行，每步先校验，需要我操作时再叫我。
```

- 密钥 `sk-...` 只出现在你受控的飞书 wiki 落地页里，**不要写进本文件或仓库**。
- 用 `curl 下载到本地再读`，比让 Claude Code 直接 WebFetch 在线页更稳（不受域名白名单/JS 渲染影响）。

---

## 给 Claude Code：执行总则

- 你的目标：把 Hermes 装好、用中转站配好模型、接入飞书、最后**自我验证打通**。
- 平台假设 macOS。Windows 见末尾「Windows 备注」（命令略有不同，先看那一节）。
- **逐步执行，每步带校验门**：校验不过不要进入下一步，先看 `hermes logs --follow` / `hermes doctor` 排查并把结论告诉用户。
- 只有以下环节需要**用户本人**操作，到时停下来清楚地引导他：在飞书开放平台建应用 / 授权 / 发布 / 把机器人拉进群 / 在飞书里发测试消息。其余命令你自己跑。
- 先确认 `RELAY_API_KEY` 已设置：`printf '%s' "${RELAY_API_KEY:+set}"`（应输出 `set`）。若为空，**停下**让用户在终端 `export RELAY_API_KEY=sk-...` 后**重启 Claude Code**（env 不跨命令保留，你自己 export 无效）。

中转站参数（本 playbook 默认值）：

| 项 | 值 |
|---|---|
| base_url | `https://console.qqqrouter.ai/v1` |
| 模型 | `gpt-5.5` |
| provider 名 | `custom` |
| API 格式 | `chat_completions`（默认）；失败再切 `codex_responses` |
| key | 读环境变量 `RELAY_API_KEY` |

---

## 第 0 步 · 环境预检

```bash
python3 --version
node --version
```

- Hermes 需要 Python ≥ 3.11；安装脚本会用 `uv` 自动补齐 Python，没装也没关系。
- Node 非必需（部分工具用得到），缺了不阻塞。

校验门：能打印版本即可继续；命令不存在也继续（安装脚本会补依赖）。

---

## 第 1 步 · 一键安装 Hermes

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

装完刷新 PATH 并校验：

```bash
hash -r 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"
hermes --version
```

校验门：`hermes --version` 打印出版本号。
若提示 `command not found`：让用户 `source ~/.zshrc`（或 `~/.bashrc`）后重试，或**新开一个终端窗口**再试（PATH 未刷新）。安装器把 `hermes` 软链到 `~/.local/bin/hermes`。

---

## 第 2 步 · 非交互配自定义模型（中转站 qqqrouter，模型 gpt-5.5）

> ⚠️ 不要跑 `hermes model` / `hermes setup` —— 那是 curses 交互向导，在你（非 TTY）环境里会卡死。**只用 `hermes config set`**。

```bash
hermes config set model.provider custom
hermes config set model.base_url "https://console.qqqrouter.ai/v1"
hermes config set model.default "gpt-5.5"
hermes config set OPENAI_API_KEY "$RELAY_API_KEY"
```

说明：
- 前三条写入 `~/.hermes/config.yaml`；`model.provider=custom` + `model.base_url` 走 OpenAI 兼容的 `chat/completions`。
- `OPENAI_API_KEY` 因 `_API_KEY` 后缀被自动写入 `~/.hermes/.env`（不进 yaml）；custom 端点在没有显式 key 时回退读它。
- **绝不**把 `sk-...` 明文写进 playbook 或仓库——这里只引用 `$RELAY_API_KEY`。

校验门：

```bash
hermes config get model.provider   # custom
hermes config get model.base_url   # https://console.qqqrouter.ai/v1
hermes config get model.default    # gpt-5.5
```

三个值都对即可继续。

---

## 第 3 步 · 校验模型真的能回话

```bash
hermes -z "只回复两个字：OK"
```

> `hermes -z` 是 oneshot 模式：发一条 prompt、打印末尾结果块、退出。若参数报错先跑 `hermes -z --help` 看实际用法。

校验门：模型返回了文本（例如 `OK`）。

**如果探活失败，且报与接口路径 / 格式有关的错**（如 4xx、`chat/completions` 不支持、`responses` 相关），把格式切到 codex-responses 再探活：

```bash
hermes config set model.api_mode "codex_responses"
hermes -z "只回复两个字：OK"
```

仍失败的排查顺序：
1. `RELAY_API_KEY` 是否有效、是否真被读到（`printf '%s' "${RELAY_API_KEY:+set}"` 应为 `set`）。
2. `https://console.qqqrouter.ai/v1` 是否可达（`curl -sS -o /dev/null -w '%{http_code}' https://console.qqqrouter.ai/v1`）。
3. 模型名 `gpt-5.5` 在中转站是否存在。
4. 跑 `hermes doctor` 看连通性检查里模型这项的结论。

把结论告诉用户。到这里**模型已配好**。如果用户暂时不接飞书，可让他直接 `hermes` 在终端里聊天。

---

## 第 4 步 · 引导用户拿飞书应用凭证（这一步需要用户操作）

清楚地告诉用户去 **飞书开放平台** https://open.feishu.cn/app 完成（Lark 国际版用 https://open.larksuite.com ）：

1. **创建自建应用**，记下 **App ID**（形如 `cli_xxx`）和 **App Secret**。
2. 开启 **机器人（Bot）** 能力。
3. **事件订阅**：添加事件 `im.message.receive_v1`；连接方式选 **长连接 / WebSocket**（不要选 webhook，免去公网回调地址）。
4. **权限管理**：授予 IM 读写权限（如 `im:message`、`im:message:send_as_bot`，即「接收消息」「以应用身份发消息」等范围）。
5. **创建版本并发布**，等待生效 / 审批通过。

然后让用户把 **App ID** 和 **App Secret** 贴给你。**注意**：App Secret 是敏感凭证，引用时按名称称呼、不要回显原值。

---

## 第 5 步 · 写入飞书凭证并启动网关（你来跑）

拿到凭证后，写入 `~/.hermes/.env`（把 `<APP_ID>` / `<APP_SECRET>` 换成用户给的值）。
飞书各项配置 hermes 网关都从环境变量读（`gateway/config.py`），所以直接落到 `.env`。

> ⚠️ 不要用 `hermes config set FEISHU_APP_ID ...`：`hermes config set` 只对 `*_API_KEY` / `*_TOKEN` 等后缀自动落 `.env`，`FEISHU_APP_ID` / `FEISHU_APP_SECRET` 这类会被错误写进 yaml、网关读不到。
> 用下面的方式**直接、幂等地写入 `~/.hermes/.env`**（已存在则替换该行）：

```bash
ENV_FILE="${HERMES_HOME:-$HOME/.hermes}/.env"
mkdir -p "$(dirname "$ENV_FILE")"; touch "$ENV_FILE"; chmod 600 "$ENV_FILE"

set_env () {  # set_env KEY VALUE —— 幂等写入，不回显 value
  local k="$1" v="$2"
  if grep -q "^${k}=" "$ENV_FILE" 2>/dev/null; then
    # 用 awk 替换，避免 sed 分隔符被 value 里的字符干扰
    awk -v k="$k" -v v="$v" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v; done=1} {print} END{if(!done) print k"="v}' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
}

set_env FEISHU_APP_ID         "<APP_ID>"
set_env FEISHU_APP_SECRET     "<APP_SECRET>"
set_env FEISHU_DOMAIN         "feishu"        # 国际版 Lark 改成 lark
set_env FEISHU_CONNECTION_MODE "websocket"     # 长连接，无需公网地址
set_env FEISHU_ALLOW_ALL_USERS "false"         # false = 启用 DM 配对审批（新手自测推荐）
set_env FEISHU_GROUP_POLICY    "open"          # 群里 @机器人 才回应；disabled 可关群聊
chmod 600 "$ENV_FILE"
```

把网关装成后台服务并启动：

```bash
hermes gateway install   # 装常驻服务（macOS launchd / Linux systemd）
hermes gateway start
```

校验门：

```bash
hermes gateway status
```

应显示网关在运行、且飞书平台已启用（凭 `FEISHU_APP_ID`+`FEISHU_APP_SECRET` 自动启用）。
若状态异常：`hermes logs --follow` 看启动日志，常见原因是 App Secret 错、或应用未发布。

---

## 第 6 步 · 配对放行（用户私聊 + 你审批）

1. 让用户在飞书里**给机器人发一条私聊消息**（如「你好」）。
2. 你查看待配对请求并放行：

```bash
hermes pairing list
hermes pairing approve <CODE>
```

> 子命令用法不确定时先跑 `hermes pairing --help`。`FEISHU_ALLOW_ALL_USERS=false` 时陌生人首次私聊会拿到配对码，审批后才能对话。

校验门：approve 成功，无报错。

---

## 第 7 步 · 端到端自验证（成功标准）

开一个日志跟随窗口，观察入站事件：

```bash
hermes logs --follow
```

让用户在飞书里再发一条消息，你确认：

- 日志出现入站事件 `im.message.receive_v1`；
- 机器人**在飞书里回复了**，且内容来自中转站模型 `gpt-5.5`。

满足即**全部打通**，向用户报告成功，并给出常用指令：飞书里直接发文本 `/status`、`/model`、`/reset`（飞书不支持斜杠菜单，发纯文本即可）。

群聊补充：若要在群里用，引导用户**把机器人拉进群**并 **@机器人**（`FEISHU_GROUP_POLICY=open` 默认需要 @）。要关闭群聊则把它设为 `disabled` 并 `hermes gateway restart`。

---

## 排障速查

机器人收不到消息：
1. 应用已**发布且审批通过**；
2. 事件订阅含 `im.message.receive_v1`；
3. 连接方式是**长连接 / WebSocket**（`FEISHU_CONNECTION_MODE=websocket`）；
4. 所需 IM 权限 scope 已授予；
5. 网关在跑：`hermes gateway status`；
6. 看日志：`hermes logs --follow`；
7. 整体体检：`hermes doctor`。

模型不回话：回到第 3 步，先 `hermes -z` 探活；必要时在 `chat_completions` ↔ `codex_responses` 间切 `model.api_mode`：

```bash
hermes config set model.api_mode "codex_responses"   # 或清空回默认：hermes config set model.api_mode ""
hermes gateway restart
hermes -z "只回复两个字：OK"
```

改了配置后让网关生效：`hermes gateway restart`。

App Secret 泄露：在开放平台重置 Secret → 用第 5 步的 `set_env FEISHU_APP_SECRET "<新值>"` 覆写 → `hermes gateway restart`。

---

## Windows 备注

第 1 步改用 PowerShell（原生安装，含便携 Git Bash，无需管理员）：

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

环境变量：当前会话用 `$env:RELAY_API_KEY="sk-..."`；要持久化用 `setx RELAY_API_KEY "sk-..."`（**新开终端才生效**）。
**关键**：和 macOS 一样，必须在**设好 env 的同一个 PowerShell 窗口里启动 `claude`**，env 才能被继承。

其余 `hermes config set` / `hermes -z` / `hermes gateway ...` / `hermes pairing ...` / `hermes logs` 命令与 macOS 一致。
写 `.env` 的那段 bash 脚本在 Windows 上请改为：让 Claude Code 用 PowerShell 把这几行**幂等**写入 `%USERPROFILE%\.hermes\.env`（同名行替换，否则追加）：

```text
FEISHU_APP_ID=<APP_ID>
FEISHU_APP_SECRET=<APP_SECRET>
FEISHU_DOMAIN=feishu
FEISHU_CONNECTION_MODE=websocket
FEISHU_ALLOW_ALL_USERS=false
FEISHU_GROUP_POLICY=open
```

Windows 原生唯一缺的功能是浏览器版 dashboard 聊天窗（需要 WSL2）；CLI、网关、飞书都原生可用。

---

## 参考（官方文档）

- 安装与快速上手：https://hermes-agent.nousresearch.com/docs/getting-started/quickstart
- 配置（providers / 模型 / 全部选项）：https://hermes-agent.nousresearch.com/docs/user-guide/configuration
- 消息网关（飞书等平台）：https://hermes-agent.nousresearch.com/docs/user-guide/messaging
- CLI 命令参考：https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- 环境变量参考：https://hermes-agent.nousresearch.com/docs/reference/environment-variables
- 安全（命令审批 / DM 配对）：https://hermes-agent.nousresearch.com/docs/user-guide/security

