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
- **流程对所有系统一致；只有个别命令分平台**。第 0 步会先探测操作系统，之后凡命令给出 `macOS / Linux:` 与 `Windows (PowerShell):` 两版的，按探测结果选对应那版执行；只写一份的（纯 `openclaw` 子命令）两平台通用。Windows 用户若在 **WSL / Git-Bash**（有 `bash`/`find`/`/tmp`）按 macOS / Linux 版走；在**原生 PowerShell / Windows Terminal** 才用 Windows 版。不要在 PowerShell 里照搬 bash 的 `\` 续行、`$(...)`、`find`、`rm`、`/tmp`、`grep`。
- **逐步执行，每步带校验门**：校验不过不要进入下一步，先看 `openclaw logs --follow` 排查并告诉用户结论。
- **飞书接入首选「扫码自动建应用」**（第 5 步），用户只需用手机扫一次码、点同意，应用 / 事件订阅 / 权限 / 长连接全部自动配好，无需去开放平台手动操作。手动建应用是备选（见第 5 步附录）。
- 需要**用户本人**操作的环节只有：扫码授权、配对放行时的私聊、把机器人拉进群、发测试消息。到时停下来清楚引导，其余命令你自己跑。
- 先确认 `RELAY_API_KEY` 已设置。**macOS / Linux:** `printf '%s\n' "${RELAY_API_KEY:+set}"`（应输出 `set`）；**Windows (PowerShell):** `if ($env:RELAY_API_KEY) { "set" } else { "EMPTY" }`。若为空，**停下**让用户在终端设置后**重启 Claude Code**（env 不跨命令保留，你自己设无效）——macOS / Linux 用 `export RELAY_API_KEY=sk-...`；Windows 当前会话用 `$env:RELAY_API_KEY="sk-..."`，要持久化用 `setx RELAY_API_KEY "sk-..."`（新开终端才生效）。

---

## 第 0 步 · 环境预检（含操作系统判定）

先判定操作系统（决定后续遇到分平台命令时选哪版），再看 Node 版本：

```bash
node -e "console.log('platform=' + process.platform)"   # darwin=macOS / linux / win32=Windows
node --version
```

- `platform=win32` → 后续选 **Windows (PowerShell)** 版命令（除非用户在 WSL/Git-Bash，则按 macOS / Linux 版）。`darwin` / `linux` → 选 **macOS / Linux** 版。
- 需要 Node ≥ 22.19（推荐 24）。版本不够或没装也没关系，下一步的安装脚本会补 Node（连 `node` 都没有时，先按第 1 步装好再回看版本）。

校验门：记下平台即可继续；Node 命令不存在也继续（安装脚本会装 Node）。

---

## 第 1 步 · 安装 OpenClaw

**macOS / Linux:**

```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

**Windows (PowerShell):**

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

> Windows 安装脚本会自动补 Node（winget→choco→scoop→portable-node 多级回退）并写入用户 PATH。

装完刷新 PATH 并校验：

**macOS / Linux:**

```bash
hash -r 2>/dev/null || true
openclaw --version
```

**Windows (PowerShell):** 无需 `hash -r`，**新开一个终端窗口**后：

```powershell
openclaw --version
```

校验门：`openclaw --version` 打印出版本号。
若提示 `command not found` / `不是内部或外部命令`：让用户**新开一个终端窗口**再试（PATH 未刷新），或参考 https://docs.openclaw.ai/install/node#troubleshooting 。

---

## 第 2 步 · 非交互 onboard（接入 qqqrouter 中转站，模型 gpt-5.5）

**macOS / Linux:**

```bash
openclaw onboard --non-interactive --accept-risk --mode local \
  --auth-choice custom-api-key \
  --custom-base-url "https://console.qqqrouter.ai/v1" \
  --custom-model-id "gpt-5.5" \
  --custom-api-key "$RELAY_API_KEY" \
  --custom-provider-id "qqqrouter" \
  --custom-compatibility openai-responses \
  --secret-input-mode plaintext \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --json
```

**Windows (PowerShell):** 续行符是反引号 `` ` ``（不是 `\`），变量是 `$env:RELAY_API_KEY`：

```powershell
openclaw onboard --non-interactive --accept-risk --mode local `
  --auth-choice custom-api-key `
  --custom-base-url "https://console.qqqrouter.ai/v1" `
  --custom-model-id "gpt-5.5" `
  --custom-api-key "$env:RELAY_API_KEY" `
  --custom-provider-id "qqqrouter" `
  --custom-compatibility openai-responses `
  --secret-input-mode plaintext `
  --gateway-port 18789 --gateway-bind loopback `
  --install-daemon --daemon-runtime node `
  --json
```

校验门：命令退出码为 0、JSON 摘要正常。
说明：
- **`--accept-risk` 必带**：非交互 onboard 没有它会直接退出报 `Non-interactive setup requires explicit risk acknowledgement`。
- **兼容模式默认用 `openai-responses`**：实测该中转站的 `gpt-5.5` 走 `openai`（chat/completions）会报 `Upstream service temporarily unavailable`，换成 responses 协议才稳。若你的中转站对某模型只支持 chat/completions，再把 `--custom-compatibility openai` 试一次（见第 3 步）。
- 这会把网关装成本机守护进程（loopback:18789），并把 `qqqrouter/gpt-5.5` 设为默认模型。
- 若环境用 nvm 等版本管理器，`gateway status` 可能提示 Node 来自版本管理器的告警——**不影响功能**，可忽略，或按提示跑 `openclaw doctor` 优化。

---

## 第 3 步 · 校验网关 + 模型真的能回话

```bash
openclaw gateway status
```

应看到网关在 `18789` 监听。然后做一次最小模型探活（**注意 prompt 必须用 `--prompt` 传，不能当位置参数**）：

```bash
openclaw infer model run --model "qqqrouter/gpt-5.5" --prompt "只回复两个字：OK"
```

> 若该子命令参数报错，先跑 `openclaw infer model run --help` 看实际用法再探活。
> 探活首次执行可能较慢（冷启动 + 上游延迟），给它 30-60s，不要急着判失败。

校验门：模型返回了文本（例如 `OK`）。
**如果探活报与接口路径/格式有关的错**（如 4xx、`chat/completions` 不支持、或 `Upstream service temporarily unavailable`），在 `openai-responses` 和 `openai` 两种兼容模式间切换：

```bash
# 第 2 步默认已用 openai-responses；若仍失败，回退试 openai：
openclaw config set models.providers.qqqrouter.api "openai"
openclaw gateway restart
# 再次探活
openclaw infer model run --model "qqqrouter/gpt-5.5" --prompt "只回复两个字：OK"
```

> 网关支持配置热重载：`openclaw config set ...` 后日志会出现 `config hot reload applied`，多数情况下不重启也能生效；但切兼容协议这类底层改动，建议仍 `openclaw gateway restart` 一次确保干净。

仍失败则：确认 `RELAY_API_KEY` 有效、`https://console.qqqrouter.ai/v1` 可达、模型名 `gpt-5.5` 在中转站存在。把结论告诉用户。

到这里**模型已配好**。如果用户暂时不接飞书，可让他 `openclaw dashboard` 在浏览器里直接聊天。

---

## 第 4 步 · 安装飞书插件

```bash
openclaw plugins install @openclaw/feishu
openclaw gateway restart
openclaw plugins list | grep -i feishu
```

校验门：`plugins list` 里出现 feishu（状态 `enabled`）。
说明：命令是 **`plugins install`**（不是 `plugin add`）。装完必须 `gateway restart` 才会加载插件；插件输出会提示 `Restart the gateway to load plugins.`。

---

## 第 5 步 · 扫码自动创建飞书应用（首选，用户只扫一次码）

飞书插件内置了 OAuth device-code 扫码注册：用户用手机飞书 App 扫码点同意，飞书自动创建一个 `PersonalAgent` 类型应用，**事件订阅、IM 权限、长连接全部自动配好**，并把 `App ID` / `App Secret` 直接交回本机。无需去开放平台手动建应用、配权限、发版本。

> 交互式 `openclaw channels add`（不带 `--channel`）里有「扫码自动创建」选项，但它需要真实终端（TTY）走菜单，Claude Code 用工具调用驱动不了那个菜单（带 `--channel feishu` 反而会跳过扫码、建出一个**空账号**）。所以这里**绕过菜单、直接调用插件导出的注册函数**，由 Claude Code 把二维码弹给用户扫。

### 5.1 定位插件路径（版本无关，不要硬编码 hash）

**macOS / Linux:**

```bash
REG_FILE=$(find "$HOME/.openclaw/npm/projects" -path "*@openclaw/feishu/dist/app-registration-*.js" 2>/dev/null | head -1)
MEDIA_RT="$(npm root -g)/openclaw/dist/plugin-sdk/media-runtime.js"
echo "REG_FILE=$REG_FILE"
echo "MEDIA_RT=$MEDIA_RT"
[ -f "$MEDIA_RT" ] && echo "MEDIA_RT ok"
```

**Windows (PowerShell):**

```powershell
$RegFile = (Get-ChildItem "$env:USERPROFILE\.openclaw\npm\projects" -Recurse -Filter "app-registration-*.js" -ErrorAction SilentlyContinue |
            Where-Object FullName -match "@openclaw[\\/]feishu[\\/]dist" | Select-Object -First 1).FullName
$MediaRt = Join-Path (npm root -g) "openclaw\dist\plugin-sdk\media-runtime.js"
"REG_FILE=$RegFile"
"MEDIA_RT=$MediaRt"
Test-Path $MediaRt
```

校验门：`REG_FILE` / `MEDIA_RT` 都非空，且 `MEDIA_RT` 文件存在。`REG_FILE` 是飞书插件的注册模块（文件名带 hash，如 `app-registration-xxxx.js`，**靠通配匹配、不要硬编码**），`MEDIA_RT` 是核心包里的二维码渲染工具（`npm root -g` 拼出，不依赖 Node 装在哪）。找不到时，用 `openclaw plugins inspect feishu` 看插件安装根目录，或回退到第 5 步附录的手动建应用方案。

### 5.2 写扫码脚本（跨平台一份，Claude Code 生成到临时目录）

把下面内容写进临时目录的 `feishu-scan.mjs`（脚本用 `os.tmpdir()` 自动适配 macOS / Linux 的 `/tmp` 与 Windows 的 `%TEMP%`，并按平台选打开图片的方式）。将 `__REG_FILE__` / `__MEDIA_RT__` 替换成上一步得到的真实路径（Windows 路径里的 `\` 在 JS 字符串中写成 `\\`，或直接用 `/`，Node 在 Windows 上都认）：

```js
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SCAN_TP = "ob_cli_app";                 // 扫码注册的来源标记，固定值
const TMP = os.tmpdir();                       // 跨平台临时目录
const QR_PNG = path.join(TMP, "feishu-qr.png");
const CREDS = path.join(TMP, "feishu-creds.json");
const domain = process.env.FEISHU_DOMAIN === "lark" ? "lark" : "feishu";
const reg = await import("__REG_FILE__");
const media = await import("__MEDIA_RT__");

// 按平台打开图片：macOS=open / Windows=cmd start / Linux=xdg-open
function openImage(file) {
  try {
    if (process.platform === "darwin") execFileSync("open", [file]);
    else if (process.platform === "win32") execFileSync("cmd", ["/c", "start", "", file]);
    else execFileSync("xdg-open", [file]);
  } catch {}
}

try { await reg.initAppRegistration(domain); }
catch (e) { console.error("[错误] 当前环境不支持扫码注册:", e.message); process.exit(2); }

const begin = await reg.beginAppRegistration(domain);
console.log("二维码链接:", begin.qrUrl);

// 干净的二维码 PNG（终端版二维码常被颜色转义码包裹、不易扫）
let saved = null;
try {
  const d = await media.renderQrPngDataUrl(begin.qrUrl);
  const b64 = String(d).split(",")[1] ?? "";
  if (b64) { fs.writeFileSync(QR_PNG, Buffer.from(b64, "base64")); saved = QR_PNG; }
} catch {}
if (!saved) {
  try {
    const b = await media.renderQrPngBase64(begin.qrUrl);
    fs.writeFileSync(QR_PNG, Buffer.from(String(b), "base64")); saved = QR_PNG;
  } catch (e) { console.error("[警告] 二维码图片生成失败:", e.message); }
}
if (saved) { console.log("二维码图片:", saved); openImage(saved); }

console.log(`等待扫码授权中（最长 ${begin.expireIn}s）...`);
const outcome = await reg.pollAppRegistration({
  deviceCode: begin.deviceCode, interval: begin.interval, expireIn: begin.expireIn,
  initialDomain: domain, tp: SCAN_TP,
});
if (outcome.status !== "success") {
  console.error(`[失败] 扫码未完成，状态: ${outcome.status}`, outcome.message ?? ""); process.exit(3);
}
const { appId, appSecret, domain: finalDomain, openId } = outcome.result;
console.log("[成功] App ID:", appId, "| 域:", finalDomain, "| owner:", openId ?? "(无)");
fs.writeFileSync(CREDS, JSON.stringify({ appId, appSecret, domain: finalDomain, openId: openId ?? null }), { mode: 0o600 });
console.log("凭证已写入", CREDS);
```

### 5.3 后台运行脚本并把二维码弹给用户

**macOS / Linux:**

```bash
node /tmp/feishu-scan.mjs
```

**Windows (PowerShell):**

```powershell
node "$env:TEMP\feishu-scan.mjs"
```

- 用**后台任务**跑（它要轮询等扫码，最长 10 分钟）。
- 脚本会在临时目录生成 `feishu-qr.png` 并按平台自动弹出图片窗口（macOS `open` / Windows `start` / Linux `xdg-open`）。
- **引导用户**：手机飞书 App → 右上「+」→「扫一扫」→ 扫这张图 → **点同意授权**。图没弹出时，把脚本打印的「二维码链接」发给用户，让其浏览器打开后手机扫屏。
- 二维码 10 分钟有效。Lark（海外版）用户：运行前设 `FEISHU_DOMAIN=lark`（macOS / Linux `export FEISHU_DOMAIN=lark`；Windows `$env:FEISHU_DOMAIN="lark"`），脚本也会在轮询时自动识别 `tenant_brand=lark` 并切域。

校验门：脚本退出码 0，输出 `[成功] App ID: cli_xxx`，且临时目录下 `feishu-creds.json` 存在。
失败（`access_denied` / `expired` / `timeout`）就重跑脚本生成新码，或回退第 5 步附录手动方案。

### 5.4 写入凭证（不要把 secret 回显到终端）

**macOS / Linux:**

```bash
CREDS=/tmp/feishu-creds.json
APP_ID=$(node -e "console.log(require('$CREDS').appId)")
APP_SECRET=$(node -e "console.log(require('$CREDS').appSecret)")
DOMAIN=$(node -e "console.log(require('$CREDS').domain)")

openclaw config set channels.feishu.accounts.default.appId "$APP_ID"     >/dev/null && echo "✓ appId"
openclaw config set channels.feishu.accounts.default.appSecret "$APP_SECRET" >/dev/null && echo "✓ appSecret"
openclaw config set channels.feishu.domain "$DOMAIN"   >/dev/null && echo "✓ domain=$DOMAIN"
openclaw config set channels.feishu.enabled true       >/dev/null && echo "✓ enabled"
openclaw config set channels.feishu.dmPolicy "pairing" >/dev/null && echo "✓ dmPolicy=pairing"

openclaw gateway restart
# 用完即清，凭证只留在 openclaw 配置里
rm -f /tmp/feishu-creds.json /tmp/feishu-qr.png /tmp/feishu-scan.mjs
```

**Windows (PowerShell):**

```powershell
$Creds = Get-Content "$env:TEMP\feishu-creds.json" -Raw | ConvertFrom-Json
openclaw config set channels.feishu.accounts.default.appId     $Creds.appId     | Out-Null
openclaw config set channels.feishu.accounts.default.appSecret $Creds.appSecret | Out-Null
openclaw config set channels.feishu.domain  $Creds.domain | Out-Null
openclaw config set channels.feishu.enabled true          | Out-Null
openclaw config set channels.feishu.dmPolicy "pairing"    | Out-Null

openclaw gateway restart
# 用完即清，凭证只留在 openclaw 配置里
Remove-Item "$env:TEMP\feishu-creds.json","$env:TEMP\feishu-qr.png","$env:TEMP\feishu-scan.mjs" -ErrorAction SilentlyContinue
```

校验门：`openclaw channels status --channel feishu --probe` 显示飞书 `enabled, configured, running, works`。
- `dmPolicy=pairing`：陌生人首次私聊机器人会拿到配对码，由你审批后才能对话（适合新手私聊自测）。
- 扫码方案下，扫码人即应用 owner，其 `openId` 会被自动写入安全策略；第 6 步配对放行通常就是放行 owner 本人。

---

### 第 5 步附录 · 手动创建飞书应用（扫码不可用时的备选）

扫码注册若因环境/网络不支持（`initAppRegistration` 抛错），让用户去 **飞书开放平台** https://open.feishu.cn/app 手动完成（Lark 用 https://open.larksuite.com ）：

1. **创建自建应用**，记下 **App ID**（形如 `cli_xxx`）和 **App Secret**。
2. 开启 **机器人（Bot）** 能力。
3. **事件订阅**：添加事件 `im.message.receive_v1`；连接方式选 **长连接 / WebSocket**（不要选 webhook）。
4. **权限管理**：授予 `im:message`、`im:message:send_as_bot` 等读取/发送消息范围。
5. **创建版本并发布**，等待生效/审批通过。

然后让用户把 **App ID** 和 **App Secret** 贴给你，按 5.4 的方式写入（手动方案无 owner openId，配对时正常走配对码即可）。

安全增强（可选）：不想把 App Secret 明文存进 `openclaw.json`，可改用环境变量引用：

**macOS / Linux:**

```bash
export FEISHU_APP_SECRET="<APP_SECRET>"
openclaw config set channels.feishu.accounts.default.appSecret \
  --ref-provider default --ref-source env --ref-id FEISHU_APP_SECRET
```

**Windows (PowerShell):**

```powershell
$env:FEISHU_APP_SECRET = "<APP_SECRET>"
openclaw config set channels.feishu.accounts.default.appSecret `
  --ref-provider default --ref-source env --ref-id FEISHU_APP_SECRET
```

---

## 第 6 步 · 配对放行（用户私聊 + 你审批）

1. 让用户在飞书里**给机器人发一条私聊消息**（如「你好」）。机器人会回一段配对引导，里面带 `Pairing code:`（如 `DLTUWXKW`）和用户的 `Feishu user id`（`ou_...`）。
2. 你查看待配对请求并放行：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

校验门：approve 成功，无报错。
- 扫码方案下，私聊者通常就是应用 owner，放行后日志会显示 `Command owner configured ...`，用户同时被设为命令 owner（能用管理类指令）。
- 用户可以直接把机器人回复里的整行 `openclaw pairing approve feishu <CODE>` 贴给你，按它执行即可。

---

## 第 7 步 · 端到端自验证（成功标准）

开一个日志跟随窗口，观察入站与回复：

```bash
openclaw logs --follow
# 备选（macOS / Linux）：tail -f /tmp/openclaw/openclaw-*.log
# Windows 无 tail，直接用上面的 openclaw logs --follow
```

让用户在飞书里再发一条消息，你确认日志依次出现（这是实测打通时的真实标志，扫码 PersonalAgent 应用走 WebSocket 长连接，不会有 webhook 的 `im.message.receive_v1` HTTP 回调字样）：

- `feishu[default]: WebSocket client started` —— 长连接已建立；
- `feishu[default]: ... DM from ou_...: <用户消息>` —— 入站收到；
- `feishu[default]: dispatching to agent (session=...)` —— 已派发给 agent；
- `agent model: qqqrouter/gpt-5.5` —— 用的是中转站模型；
- `feishu[default] Started streaming: cardId=...` 然后 `dispatch complete (queuedFinal=true, replies=1)` —— 回复已发出（流式卡片）。

最终判据：**机器人在飞书里真的回了话**，且上面 `replies=1` 出现。满足即**全部打通**，向用户报告成功，并给出常用指令：飞书里直接发文本 `/status`、`/model`、`/reset`（飞书不支持斜杠菜单，发纯文本即可）。

群聊补充：若要在群里用，引导用户**把机器人拉进群**并 **@机器人**（默认需要 @）；需要的话可放开：

```bash
openclaw config set channels.feishu.groupPolicy "open"
openclaw gateway restart
```

---

## 排障速查

**扫码注册失败**：
- `initAppRegistration` 抛错 / `当前环境不支持` → 网络无法访问 `accounts.feishu.cn`，或该账号类型不支持自助建应用 → 回退第 5 步附录手动建应用。
- `access_denied` → 用户在手机上点了拒绝；`expired` / `timeout` → 超过 10 分钟没扫 → 重跑脚本生成新码。
- 找不到 `REG_FILE` / `MEDIA_RT` → 确认第 4 步插件已装且 `gateway restart` 过；用 `openclaw plugins inspect feishu` 看安装根目录。

**机器人收不到消息**：
1. `openclaw channels status --channel feishu --probe` 是否 `works`；
2. 扫码方案：日志有没有 `WebSocket client started`（长连接断了会缺）；手动方案：事件订阅含 `im.message.receive_v1` 且连接方式为长连接、应用已发布审批通过、权限 scope 已授予；
3. 网关在跑：`openclaw gateway status`；
4. 看日志：`openclaw logs --follow`。

**模型不回话**：回到第 3 步，先 `openclaw infer model run --model "qqqrouter/gpt-5.5" --prompt "OK"` 探活；必要时把 `models.providers.qqqrouter.api` 在 `openai-responses` / `openai` 间切换并 `openclaw gateway restart`。中转站偶发 `Upstream service temporarily unavailable` 多为上游抖动，稍等重发即可。

**App Secret 泄露**：扫码方案在开放平台或飞书 App 内重置/删除该应用后重新扫码注册；手动方案在开放平台重置 Secret → `openclaw config set channels.feishu.accounts.default.appSecret "<新值>"` → `openclaw gateway restart`。

---

## 参考（官方文档）

- 安装：https://docs.openclaw.ai/start/getting-started ・ https://docs.openclaw.ai/install/installer
- 非交互 onboard：https://docs.openclaw.ai/start/wizard-cli-automation ・ https://docs.openclaw.ai/cli/onboard
- 飞书：https://docs.openclaw.ai/channels/feishu
- 渠道 CLI：https://docs.openclaw.ai/cli/channels ・ 插件 CLI：https://docs.openclaw.ai/cli/plugins
- 配置 CLI：https://docs.openclaw.ai/cli/config ・ 探活：https://docs.openclaw.ai/cli/infer
