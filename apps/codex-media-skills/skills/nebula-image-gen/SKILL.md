---
name: nebula-image-gen
description: 通过 APINebula 的 gpt-image-2（gpt-image-2-1k 分组）生成图片、参考图改图、蒙版局部重绘。默认走异步任务接口（提交任务 → 轮询状态 → 下载结果），同步接口仅作兜底。当用户要求"生成图片 / 画图 / 产品图 / 改图 / 换背景 / 合成场景 / 局部重绘 / 抠图替换"时使用。首次使用会引导用户在对话中提供 NEBULA_API_KEY 并保存到本机 Key 文件，绝不把 Key 写进代码或 git。
---

# APINebula gpt-image-2 生图技能

通过 OpenAI 兼容接口调用 `gpt-image-2` 完成三类任务：**文本生图**、**参考图编辑**、**蒙版局部重绘**。
**默认使用异步任务接口**：创建任务（秒回 task id）→ 轮询状态 → `completed` 后立即下载。同步接口只在异步覆盖不到的场景兜底。
完整逐参数说明见 [references/api.md](references/api.md)。

**本 skill 激活时，禁止改用平台内置的图像生成/画布预览能力**——内置预览不产生本地文件，用户拿不到可用交付物。必须调用下方 APINebula 接口，把图片落盘为本地文件，并报告**绝对路径**。

- 异步生图（默认）：`POST https://apinebula.com/v1/image-tasks/generations`（JSON）
- 异步改图（默认）：`POST https://apinebula.com/v1/image-tasks/edits`（JSON，图片以**公网 URL** 传入）
- 任务详情：`GET https://apinebula.com/v1/image-tasks/{task_id}?detail=true`
- 同步生图（兜底）：`POST https://apinebula.com/v1/images/generations`（JSON）
- 同步改图/蒙版（兜底）：`POST https://apinebula.com/v1/images/edits`（multipart/form-data，本地文件与蒙版的唯一通道）
- 模型名称：固定 `gpt-image-2`
- 鉴权：`Authorization: Bearer $NEBULA_API_KEY`（来源见第 0 步）

## Windows PowerShell 编码规范（乱码防线，Windows 上必先执行）

Windows 控制台默认代码页是 GBK（936），中文 prompt 在「命令行参数 → 请求体」链路中极易变成乱码，生成的图片里出现乱码文字即源于此。在 Windows 上执行本 skill 的任何调用前：

1. 会话内先执行一次（只影响当前会话，不改系统配置）：

   ```powershell
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   $env:PYTHONUTF8 = '1'
   $env:PYTHONIOENCODING = 'utf-8'
   ```

2. 含中文的 prompt / JSON 请求体**绝不**直接写在命令行参数里传给 `curl` 或 `python -c`；一律用编程方式写成 **UTF-8（无 BOM）**的 `.py` / `.json` 文件再执行：

   ```powershell
   [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))
   ```

   Windows PowerShell 5.1 的 `Out-File` / `Set-Content` / `>` 默认写 UTF-16LE 或带 BOM，会直接导致 API 收到乱码或 JSON 解析失败，**禁止**用它们写脚本和请求体。

3. Python 脚本内统一 `open(..., encoding="utf-8")`；HTTP 请求优先用 `requests` 的 `json=` 参数（自动 UTF-8 编码），不要手拼 `--data` 字符串。
4. Key 文件 `media-skills.env` 也必须是 UTF-8（无 BOM）；如果读出乱码或匹配不到 `NAME=` 行，先检查文件编码再判断 Key 是否缺失。

## 运行时预检（调用前必做，尤其 Windows）

1. **验证 Python 是否真正可执行**，不要只看 `Get-Command python` 有结果：

   ```powershell
   $pyOk = $false
   try { $v = & python -c "import sys; print(sys.version)" 2>&1; if ($LASTEXITCODE -eq 0 -and $v) { $pyOk = $true } } catch {}
   ```

   Windows 上 `python.exe` 经常是 **Microsoft Store 占位符**（位于 `...\WindowsApps\`，执行时静默失败或弹商店页面，请求根本发不出去）。`$pyOk` 为 false 时不要尝试修复或安装 Python，直接改走下方「PowerShell 原生异步流程」。
2. **禁止用 `Start-Process` 或任何后台/分离进程承载轮询**——在 Codex 等受管环境中，后台进程可能随工具调用结束被回收，任务就丢了。轮询一律**前台阻塞**执行（前台循环 + `Start-Sleep`）。
3. 确认 `curl.exe` 可用（Windows 10 1803+ 自带）：`curl.exe --version`。Windows 上下载 `download_url` **首选 `curl.exe -sSL -o`**；`Invoke-WebRequest` 下载大文件已知会卡住，只作最后兜底。
4. 若本机笔记/记忆（如 PROJECT_MEMORY.md）中有"APINebula 没有任务 ID 接口""客户端后台异步执行"之类记录，那是旧版信息——以本文的 `/v1/image-tasks` 异步接口和前台轮询为准，并顺手更正该记录。

## 交付状态机（报告进度用语，防误判）

`submitted（任务已提交，拿到 task_id）→ generating（远端 queued/in_progress）→ downloading（远端 completed，开始下载）→ delivered（本地文件已落盘且大小 > 0）`

**远端 `completed` ≠ 交付完成**——那只是进入 downloading 的信号。只有 delivered（本地文件校验通过）才能向用户报告"完成"。

## 第 0 步：确认 API Key（每次先做）

Key 的唯一存放位置是本机 Key 文件 `~/.codex/media-skills.env`（Windows：`%USERPROFILE%\.codex\media-skills.env`），格式为每行一条 `NAME=value`。

按顺序检查，找到即通过，进入第 1 步：

1. 环境变量 `NEBULA_API_KEY` 是否已存在（只判断存在性，不打印值）。
2. Key 文件中是否有 `NEBULA_API_KEY=` 行。有则在执行调用前把它载入当前会话环境：
   - macOS / Linux：`set -a; . ~/.codex/media-skills.env; set +a`
   - Windows PowerShell：逐行读取该文件，按 `NAME=value` 拆分后写入 `$env:NAME`
   载入过程不得打印 Key 内容。

**两处都没有** → 把下面这段话原样发给用户，然后停止等待回答：

> 使用生图功能需要先配置 APINebula 的 API Key（只需一次）：
>
> 1. 打开 https://apinebula.com/ → 登录 → 控制台「创建 API 令牌」，复制生成的 Key（形如 `sk-...`）。
> 2. 把 Key 直接粘贴到对话框发给我，我会保存到本机配置文件，之后不用再输。
>
> ⚠️ Key 等于你的账户余额：只发在这个对话里，不要发给其他人或贴到网上。

**收到用户粘贴的 Key 后**：

1. 去掉首尾空白，做形状检查（非空、单行、不含空格）；不合格就说明原因并请用户重新复制粘贴。
2. 写入 Key 文件的 `NEBULA_API_KEY=<key>` 行（目录/文件不存在则创建；已有该行则整行替换），编码固定 **UTF-8 无 BOM**。权限规则分平台：macOS/Linux 执行 `chmod 600`；**Windows 不要修改 ACL**——`%USERPROFILE%` 下默认已仅限当前用户，错误的 ACL 收紧会导致后续读取被拒、Key 被误判为未配置。写入命令不得让 Key 出现在 shell 历史可见的命令行参数里（优先用编程方式写文件）。
3. **写入后立即读回校验**：能重新读出该行且值一致，才允许报告"已保存"；读回失败（如权限被拒）视为保存失败，先修复再继续。
4. 回复只确认"已保存到 ~/.codex/media-skills.env"并显示前 6 位掩码（如 `sk-abc***`），**绝不回显完整 Key**。
5. 提醒用户：这条对话消息里留有 Key，若客户端支持建议删除该消息；日后怀疑泄露，去 APINebula 控制台删除并重建 Key，再把新 Key 发给我即可（我会覆盖旧值）。

**安全红线（Agent 必须遵守）**：

- Key 只允许存在于环境变量和 `~/.codex/media-skills.env`；绝不写进代码、脚本、项目配置或 git 仓库。
- 任何输出（日志、报错、调试信息）中最多出现前 6 位掩码；禁止在载入 Key 后执行 `env`、`printenv`、`set -x` 等会整体输出环境的命令。
- 除写入上述 Key 文件、以及对 `apinebula.com` 的鉴权头之外，不得把 Key 发送到任何其他地方。

## 第 1 步：选择接口（决策树）

| 用户想要 | 接口 | 要点 |
|---|---|---|
| 纯文字描述生成新图 | 异步 `/v1/image-tasks/generations`（**默认**） | JSON 请求，提交后轮询 |
| 基于已有图片改图/合成，素材是**公网 URL** | 异步 `/v1/image-tasks/edits`（**默认**） | JSON 请求，`images` 传 URL 列表 |
| 基于**本地图片文件**改图/合成 | 同步 `/v1/images/edits` | multipart，异步接口不收本地文件 |
| 只重绘图片的某个区域，其余保持不变 | 同步 `/v1/images/edits` + `mask` | 异步接口不支持蒙版；蒙版与原图尺寸一致、需带 alpha 通道 |
| 需要 `size` / `background=transparent` 等参数 | 同步 `/v1/images/generations` | 异步接口只支持 model / prompt / quality（edits 另有 images） |

本地素材未经用户明确同意，**不得**为了走异步接口而擅自上传到任何第三方图床或对象存储。

## 第 2 步：写好 prompt

- 写清楚：主体、场景、风格、光线、构图比例；若图中要出现文字，把文字内容写进 prompt。
- 改图时写清楚：**要保留什么、要替换什么**、输出风格、主体之间的关系（如"保留真实阴影、金属高光和桌面透视关系"）。
- 蒙版重绘时写清楚：蒙版区域画什么、非蒙版区域需要延续的光照/透视/风格。

## 第 3 步：调用（默认异步：创建 → 轮询 → 下载）

按「运行时预检」选择实现：Python 可执行 → 用 Python 示例；否则（Windows 常见）→ 用 PowerShell 原生流程。两者流程一致：提交拿 task_id → **前台**轮询 → `curl.exe` 下载 → 校验落盘。Windows 上必须先按「编码规范」把脚本以 UTF-8（无 BOM）写入文件后执行，不要用 `python -c` 传中文。

### 异步文生图（Python，含轮询与落盘）

```python
import os
import time
import uuid
from pathlib import Path

import requests

BASE = "https://apinebula.com/v1"
HEADERS = {"Authorization": f"Bearer {os.environ['NEBULA_API_KEY']}"}

task = requests.post(
    f"{BASE}/image-tasks/generations",
    headers=HEADERS,
    json={
        "model": "gpt-image-2",
        "prompt": "一张简洁的商业产品图，浅灰背景中摆放一只银白色无线耳机充电盒，光线柔和，细节清晰。",
        "quality": "medium",
    },
    timeout=60,
)
task.raise_for_status()
task_id = task.json()["task_id"]
print(f"任务已创建：{task_id}")

deadline = time.monotonic() + 15 * 60  # 客户端示例最多等待 15 分钟
while time.monotonic() < deadline:
    result = requests.get(
        f"{BASE}/image-tasks/{task_id}",
        headers=HEADERS,
        params={"detail": "true"},
        timeout=60,
    ).json()
    status = result.get("status")
    if status == "completed":
        break
    if status == "failed":
        message = (result.get("error") or {}).get("message", "unknown")
        raise RuntimeError(f"图片任务失败：{message}")
    time.sleep(10)
else:
    raise TimeoutError(f"本地轮询超时；远端任务 {task_id} 可能仍在执行，稍后可再查询。")

download_url = result["detail"]["data"][0]["download_url"]
output_dir = Path("USER_APPROVED_OUTPUT_DIR").expanduser().resolve()
output_path = output_dir / f"generated-image-{uuid.uuid4().hex[:12]}.png"
max_image_bytes = 64 * 1024 * 1024

with requests.get(download_url, stream=True, timeout=120) as resp:
    resp.raise_for_status()
    total = 0
    fd = os.open(output_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "wb") as output:
        for chunk in resp.iter_content(1024 * 1024):
            if not chunk:
                continue
            total += len(chunk)
            if total > max_image_bytes:
                raise ValueError("Downloaded image exceeds the configured size cap")
            output.write(chunk)
print(output_path)
```

把 `USER_APPROVED_OUTPUT_DIR` 替换为输出目录：用户指定的优先；未指定时用**当前工作目录**（不要用系统临时目录，用户找不到）。使用唯一文件名和独占创建，避免覆盖已有文件或跟随符号链接。

### 异步改图（公网 URL 素材）

只需把创建任务的请求换成下面这个，轮询与下载逻辑与上例完全一致：

```python
task = requests.post(
    f"{BASE}/image-tasks/edits",
    headers=HEADERS,
    json={
        "model": "gpt-image-2",
        "prompt": "把第一张图中的产品放到第二张图的办公桌场景中，保留真实阴影和透视关系。",
        "quality": "high",
        "images": [
            {"image_url": "https://example.com/product.png"},
            {"image_url": "https://example.com/background.png"},
        ],
    },
    timeout=60,
)
```

### 异步文生图（Windows PowerShell 原生，Python 不可用时的完整流程）

前台阻塞执行整段脚本；prompt 先按「编码规范」以 UTF-8 无 BOM 写入 `request.json`，不要内联在命令行里。

`request.json`：

```json
{
  "model": "gpt-image-2",
  "prompt": "一张简洁的商业产品图，浅灰背景中摆放一只银白色无线耳机充电盒，光线柔和，细节清晰。",
  "quality": "medium"
}
```

主流程（整体保存为 UTF-8 无 BOM 的 `.ps1` 后前台执行）：

```powershell
$ErrorActionPreference = 'Stop'
$base = 'https://apinebula.com/v1'
$headers = @{ Authorization = "Bearer $env:NEBULA_API_KEY" }

# 1. submitted：提交任务（body 从 UTF-8 文件读，避免编码问题）
$body = [System.IO.File]::ReadAllText('request.json', [System.Text.Encoding]::UTF8)
$task = Invoke-RestMethod -Method Post -Uri "$base/image-tasks/generations" `
  -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body
$taskId = $task.task_id
Write-Host "submitted: $taskId"

# 2. generating：前台轮询（禁止 Start-Process / 后台作业）
$deadline = [DateTime]::UtcNow.AddMinutes(15)
while ($true) {
  if ([DateTime]::UtcNow -gt $deadline) {
    throw "本地轮询超时；远端任务 $taskId 可能仍在执行，稍后可再查询。"
  }
  $result = Invoke-RestMethod -Method Get -Uri "$base/image-tasks/${taskId}?detail=true" -Headers $headers
  if ($result.status -eq 'completed') { break }
  if ($result.status -eq 'failed') { throw "图片任务失败：$($result.error.message)" }
  Write-Host "generating: $($result.status)"
  Start-Sleep -Seconds 10
}

# 3. downloading：用 curl.exe 下载（不要用 Invoke-WebRequest，大文件会卡住）
$downloadUrl = $result.detail.data[0].download_url
$outputPath = Join-Path (Get-Location) ("generated-image-{0}.png" -f [guid]::NewGuid().ToString('N').Substring(0,12))
Write-Host "downloading: $downloadUrl"
& curl.exe -sSL --max-time 300 -o $outputPath $downloadUrl
if ($LASTEXITCODE -ne 0) { throw "curl.exe 下载失败，退出码 $LASTEXITCODE" }

# 4. delivered：校验 PNG（文件存在、大小 > 0、魔数 89 50 4E 47）
$item = Get-Item -LiteralPath $outputPath
if ($item.Length -le 0) { throw "下载文件为空：$outputPath" }
$magic = [System.IO.File]::ReadAllBytes($outputPath)[0..3]
if (-not ($magic[0] -eq 0x89 -and $magic[1] -eq 0x50 -and $magic[2] -eq 0x4E -and $magic[3] -eq 0x47)) {
  throw "文件不是有效 PNG（可能下载到了错误页）：$outputPath"
}
Write-Host "delivered: $($item.FullName) ($($item.Length) bytes)"
```

异步改图同理：把提交端点换成 `$base/image-tasks/edits`、`request.json` 里加 `images` URL 列表即可，轮询与下载不变。

### 轮询纪律

- 每 10 秒查询一次，客户端最长等待 15 分钟；`queued` / `in_progress` 继续等，不要过早判定失败。
- `completed` 后**立即下载** `download_url` 落盘，不要把 URL 囤着以后再下。
- `failed`：读 `error.message` 反馈给用户。异步任务最终失败或取消时按预扣额度退款，无需担心失败重复扣费；但重新提交仍是新的收费请求，先向用户确认。
- 本地轮询超时 ≠ 任务失败：报告 task id，稍后可用详情接口继续查询，不要立刻重复提交。

## 同步接口（兜底：本地文件改图 / 蒙版重绘 / 特殊参数）

同步接口阻塞 1~2 分钟且响应携带大体积 `b64_json`，只在决策树标注的兜底场景使用。不要让 curl 把 `b64_json` 响应打印到工具/聊天日志；验证并解码完成后立即删除临时响应文件。

### 同步文本生图（仅当需要 size / background 等参数时）

```bash
set +x
RESPONSE_FILE="$(mktemp)"
chmod 600 "$RESPONSE_FILE"
printf 'Authorization: Bearer %s\n' "$NEBULA_API_KEY" |
curl https://apinebula.com/v1/images/generations \
  -H @- \
  -H "Content-Type: application/json" \
  -o "$RESPONSE_FILE" \
  -d @request.json
echo "响应已保存到受限临时文件，未输出到终端：$RESPONSE_FILE"
```

`request.json`（以 UTF-8 无 BOM 编码写入）：

```json
{
  "model": "gpt-image-2",
  "prompt": "一张简洁的商业产品图，浅灰背景，光线柔和，细节清晰。",
  "size": "1024x1024",
  "quality": "medium",
  "background": "transparent",
  "response_format": "b64_json"
}
```

### 参考图编辑（本地文件，多张图合成）

```bash
set +x
RESPONSE_FILE="$(mktemp)"
chmod 600 "$RESPONSE_FILE"
printf 'Authorization: Bearer %s\n' "$NEBULA_API_KEY" |
curl https://apinebula.com/v1/images/edits \
  -H @- \
  -o "$RESPONSE_FILE" \
  -F "model=gpt-image-2" \
  -F "prompt=将第一张图中的产品摆放到第二张图的场景中，保留真实阴影和透视关系。" \
  -F "size=1536x1024" \
  -F "quality=high" \
  -F "response_format=b64_json" \
  -F "input_fidelity=high" \
  -F "image=@product.png" \
  -F "image=@background.png"
echo "响应已保存到受限临时文件，未输出到终端：$RESPONSE_FILE"
```

Windows 上含中文 prompt 的 multipart 请求不要用 PowerShell 拼 curl 参数，改用 Python `requests`（`files=` + `data=`）以 UTF-8 提交。

### 蒙版局部重绘（本地文件）

```bash
set +x
RESPONSE_FILE="$(mktemp)"
chmod 600 "$RESPONSE_FILE"
printf 'Authorization: Bearer %s\n' "$NEBULA_API_KEY" |
curl https://apinebula.com/v1/images/edits \
  -H @- \
  -o "$RESPONSE_FILE" \
  -F "model=gpt-image-2" \
  -F "prompt=将蒙版覆盖的区域完整替换为……，非蒙版区域保留自然日光和真实质感。" \
  -F "quality=high" \
  -F "response_format=b64_json" \
  -F "image=@background.png" \
  -F "mask=@mask.png"
echo "响应已保存到受限临时文件，未输出到终端：$RESPONSE_FILE"
```

## 已验证的坑（来自官方文档实测标注，2026-07）

| 坑 | 事实 | 应对 |
|---|---|---|
| 异步参数 | 异步接口只支持 `model` / `prompt` / `quality`（edits 另有 `images` URL 列表） | 需要 size / transparent / 蒙版 → 走同步接口 |
| 异步改图素材 | `images` 只接受公网 URL，不能传本地文件 | 本地文件走同步 multipart；不得擅自上传用户素材到第三方 |
| 多图 | `n` 只支持 1，传 `n=2` 仍只返回 1 张 | 要多张就循环创建任务（异步可并行提交多个任务再统一轮询） |
| 尺寸 | 不支持 2K/4K；传 `2048x2048` 不报错但实际返回约 1254px | 同步接口固定用 `1024x1024` 或 `1536x1024`，不要骗自己 |
| 输出格式 | `output_format=jpeg` 返回的仍是 PNG | 一律按 PNG 处理，文件后缀写 `.png` |
| 压缩 | `output_compression` 仅在输出真为 jpeg 时才有意义 | 基本可忽略 |
| 透明背景 | `background=transparent` 有效，返回带 alpha 的 PNG | 抠图/贴纸需求走同步接口用它 |
| 参考图跟随 | `input_fidelity=high` 可提高对输入图的跟随程度（同步 edits） | 产品图合成务必带上 |
| 蒙版 | 蒙版与原图尺寸必须一致，且需带 alpha 通道 | 先检查两图尺寸再提交 |
| response_format | 同步 `url` 返回的链接可能过期；异步 `download_url` 同理 | 拿到即下载落盘，不要囤链接 |
| Windows 乱码 | GBK 控制台 + `Out-File` 默认编码会把中文 prompt 变乱码 | 按顶部「编码规范」执行；prompt 一律经 UTF-8 文件传递 |
| 假 Python | `python.exe` 是 Microsoft Store 占位符，命令静默失败，请求根本没发出 | 按「运行时预检」先跑 `python -c` 验证；失败改走 PowerShell 原生流程 |
| 后台轮询丢任务 | `Start-Process` / 后台作业在受管环境随工具调用结束被回收 | 轮询一律前台阻塞循环 + `Start-Sleep` |
| Invoke-WebRequest 卡死 | 下载大文件已知会挂起 | Windows 下载 `download_url` 首选 `curl.exe -sSL -o` |
| completed ≠ 交付 | 远端 `completed` 时图片还没下载，容易误报完成 | 按「交付状态机」：只有本地校验通过（delivered）才算完成 |

## 失败处理

- `401`：Key 无效或没带上 → 回到第 0 步检查。
- 异步 `failed`：读 `error.message` 反馈用户；按预扣额度退款，重新提交前先向用户确认。
- `4xx` 参数错误：核对 [references/api.md](references/api.md) 中该参数的"支持情况"列——很多 OpenAI 官方参数在此分组只是"部分支持"，异步接口支持的参数更少。
- 同步接口超时：生图正常耗时可达 1~2 分钟，客户端超时至少设 120 秒。响应不明确时不要自动重试，以免重复计费；先确认请求是否被服务端接受，再由用户决定是否重发。
- 内容审核拦截：移除不合规内容后再提交，不得通过改写提示词绕过审核；`moderation` 只有 `auto`/`low`，不能关闭。

## 交付纪律

1. 图片一律落盘为 `.png`；报告前先确认文件存在、大小 > 0 且 PNG 魔数（`89 50 4E 47`）正确，然后向用户报告**绝对路径**。只出现在界面预览里、没有落盘路径的图片不算交付；远端 `completed` 但未下载也不算交付（见「交付状态机」）。
2. 一次任务多张图时，文件名带序号和语义（`product-hero-01.png`）。
3. 报告中附上实际使用的 prompt，方便用户微调后重跑。
