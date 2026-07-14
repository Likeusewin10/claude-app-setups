---
name: ark-video-gen
description: 通过火山方舟（Ark）Seedance 系列模型生成视频：文生视频、图生视频（首帧/首尾帧）、多模态参考生视频（图+视频+音频）。异步任务流程：创建任务 → 轮询查询 → 立即下载。当用户要求"生成视频 / 图片转视频 / 首尾帧动画 / 带配音的视频 / 延长视频"时使用。首次使用会引导用户在对话中提供 ARK_API_KEY 并保存到本机 Key 文件，绝不把 Key 写进代码或 git。
---

# 火山方舟 Seedance 生视频技能

视频生成是**异步任务**，必须走三步：创建任务（秒回 task id）→ 轮询查询状态 → 成功后**立即下载**视频。
四个接口的完整参数表、模型×参数支持矩阵、分辨率像素表见 [references/api.md](references/api.md)。

- Base URL：`https://ark.cn-beijing.volces.com/api/v3`
- 创建任务：`POST /contents/generations/tasks`
- 查询任务：`GET /contents/generations/tasks/{id}`
- 任务列表：`GET /contents/generations/tasks?...`
- 取消/删除：`DELETE /contents/generations/tasks/{id}`
- 鉴权：`Authorization: Bearer $ARK_API_KEY`（长效 API Key，来源见第 0 步）

## 两条铁律（违反 = 用户损失）

1. **视频 URL 只有 24 小时有效**——任务成功后必须立刻下载到本地，再向用户报告。
2. **任务记录通常只保存 7 天**——`cancelled` 记录 24 小时后自动删除；不要把 task id 当长期凭证。

## Windows PowerShell 编码规范（乱码防线，Windows 上必先执行）

Windows 控制台默认代码页是 GBK（936），中文 prompt 在「命令行参数 → 请求体」链路中极易变成乱码，视频画面/配音出现乱码文字即源于此。在 Windows 上执行本 skill 的任何调用前：

1. 会话内先执行一次（只影响当前会话，不改系统配置）：

   ```powershell
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   $env:PYTHONUTF8 = '1'
   $env:PYTHONIOENCODING = 'utf-8'
   ```

2. 含中文的 prompt / 请求体**绝不**直接写在命令行参数里传给 `curl` 或 `python -c`；一律用编程方式写成 **UTF-8（无 BOM）**的 `.py` 文件再执行：

   ```powershell
   [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))
   ```

   Windows PowerShell 5.1 的 `Out-File` / `Set-Content` / `>` 默认写 UTF-16LE 或带 BOM，会直接导致 API 收到乱码，**禁止**用它们写脚本和请求体。

3. Python 脚本内统一 `open(..., encoding="utf-8")`；本 skill 的 SDK 示例在进程内构造请求体，天然规避命令行编码问题，优先照用。
4. Key 文件 `media-skills.env` 也必须是 UTF-8（无 BOM）；如果读出乱码或匹配不到 `NAME=` 行，先检查文件编码再判断 Key 是否缺失。

## 第 0 步：确认 API Key（每次先做）

Key 的唯一存放位置是本机 Key 文件 `~/.codex/media-skills.env`（Windows：`%USERPROFILE%\.codex\media-skills.env`），格式为每行一条 `NAME=value`。

按顺序检查，找到即通过，进入第 1 步：

1. 环境变量 `ARK_API_KEY` 是否已存在（只判断存在性，不打印值）。
2. Key 文件中是否有 `ARK_API_KEY=` 行。有则在执行调用前把它载入当前会话环境：
   - macOS / Linux：`set -a; . ~/.codex/media-skills.env; set +a`
   - Windows PowerShell：逐行读取该文件，按 `NAME=value` 拆分后写入 `$env:NAME`
   载入过程不得打印 Key 内容。

**两处都没有** → 把下面这段话原样发给用户，然后停止等待回答：

> 使用生视频功能需要先配置火山方舟的 API Key（只需一次）：
>
> 1. 打开 https://console.volcengine.com/ark/region:cn-beijing/apiKey → 创建**长效 API Key** 并复制。
> 2. 在「开通管理」中开通需要的 Seedance 模型（Seedance 2.0 系列要求账户余额大于 200 元，或已购买且有余量的资源包）。
> 3. 把 Key 直接粘贴到对话框发给我，我会保存到本机配置文件，之后不用再输。
>
> ⚠️ Key 等于你的账户余额：只发在这个对话里，不要发给其他人或贴到网上。

**收到用户粘贴的 Key 后**：

1. 去掉首尾空白，做形状检查（非空、单行、不含空格）；不合格就说明原因并请用户重新复制粘贴。
2. 写入 Key 文件的 `ARK_API_KEY=<key>` 行（目录/文件不存在则创建；已有该行则整行替换），编码固定 **UTF-8 无 BOM**。权限规则分平台：macOS/Linux 执行 `chmod 600`；**Windows 不要修改 ACL**——`%USERPROFILE%` 下默认已仅限当前用户，错误的 ACL 收紧会导致后续读取被拒、Key 被误判为未配置。写入命令不得让 Key 出现在 shell 历史可见的命令行参数里（优先用编程方式写文件）。
3. **写入后立即读回校验**：能重新读出该行且值一致，才允许报告"已保存"；读回失败（如权限被拒）视为保存失败，先修复再继续。
4. 回复只确认"已保存到 ~/.codex/media-skills.env"并显示前 6 位掩码，**绝不回显完整 Key**。
5. 提醒用户：这条对话消息里留有 Key，若客户端支持建议删除该消息；日后怀疑泄露，去控制台「API Key 管理」删除并重建，再把新 Key 发给我即可（我会覆盖旧值）。

**安全红线（Agent 必须遵守）**：

- Key 只允许存在于环境变量和 `~/.codex/media-skills.env`；绝不写进代码、脚本、项目配置或 git 仓库。
- 任何输出（日志、报错、调试信息）中最多出现前 6 位掩码；禁止在载入 Key 后执行 `env`、`printenv`、`set -x` 等会整体输出环境的命令。
- 除写入上述 Key 文件、以及对 `ark.cn-beijing.volces.com` 的鉴权头之外，不得把 Key 发送到任何其他地方。
- 视频生成按 token 计费且不便宜：提交前向用户确认模型、时长、分辨率；4k/15s 等高消耗配置要明确提示成本更高。

## 第 1 步：选择生成模式（四种互斥，不可混用）

| 用户输入 | 模式 | content 写法 | 支持模型 |
|---|---|---|---|
| 只有文字 | 文生视频 | 1 个 `text` | 全部 |
| 一张图（+文字） | 图生视频-首帧 | `text` + 1 个 `image_url`（`role: "first_frame"` 或不填） | 全部 |
| 两张图定首尾（+文字） | 图生视频-首尾帧 | `text` + 2 个 `image_url`（`role` 必填：`first_frame` / `last_frame`） | 2.0 系列、1.5 Pro、1.0 Pro |
| 参考图/参考视频/参考音频的任意有效组合 | 多模态参考 | `text` 可选；`image_url` 0~9、`video_url` 0~3、`audio_url` 0~3，分别使用对应 reference role | 仅 Seedance 2.0 系列 |

- **音频不能单独传**，至少要配 1 个参考视频或图片。
- 多模态模式不强制包含图片；纯参考视频有效。所有媒体均为空时不属于多模态参考模式。
- 要严格保证首尾帧与指定图片一致 → 用首尾帧模式，不要用多模态参考间接实现。
- 素材形式：公网 URL、Base64（`data:image/png;base64,...`，格式小写）、素材 ID（`asset://<ASSET_ID>`）。大文件勿用 Base64（请求体上限 64 MB）。
- Seedance 2.0 不支持直接上传含真人人脸的图/视频（预置虚拟人像、已授权素材、本账号 30 天内模型生成的含人脸产物除外）。

**输入素材硬限制**（提交前先校验，细节见 references）：
图片 jpeg/png/webp/bmp/tiff/gif（1.5 Pro 与 2.0 系列另支持 heic/heif）、<30MB、宽高比 [0.4,2.5]、边长 300~6000px；视频 mp4/mov、≤200MB、2~15s、总时长 ≤15s、帧率 24~60；音频 wav/mp3、2~15s、≤15MB。

## 第 2 步：选模型与参数

确定 `model` 参数，按顺序取值，**不需要询问用户**：

1. 环境变量 `ARK_VIDEO_MODEL`（如已存在）。
2. Key 文件 `~/.codex/media-skills.env` 中的 `ARK_VIDEO_MODEL=` 行（随 Key 一起载入）。
3. 都没有 → 使用默认模型 **`doubao-seedance-2-0-260128`**（Seedance 2.0）。

仅当用户明确要求换模型、或请求需要默认模型不支持的能力（如 draft 样片模式仅 1.5 Pro 支持、frames/seed 仅 1.x 支持）时才改用其他 Model ID，并保存为 Key 文件的 `ARK_VIDEO_MODEL=<id>` 行以便下次沿用。拒绝 `YOUR_MODEL_OR_ENDPOINT_ID` 等占位符。提交收费任务前再次确认时长、分辨率和预计成本等级。

若创建任务返回"模型未开通"类错误，引导用户到 https://console.volcengine.com/ark/region:cn-beijing/openManagement 开通对应模型（Seedance 2.0 系列要求账户余额大于 200 元，或已购买且有余量的资源包）。

控制台：`https://console.volcengine.com/ark/region:cn-beijing/endpoint`

| 模型 | 能力要点 |
|---|---|
| Seedance 2.0 系列 | 多模态参考、有声视频、duration [4,15] 或 -1；仅完整版 2.0 支持 4k（10bit/H.265），Fast/Mini 不支持；不支持 seed/camera_fixed/frames/flex |
| Seedance 1.5 Pro | 有声视频、draft 样片模式、duration [4,12] 或 -1 |
| Seedance 1.0 Pro | 首尾帧、duration [2,12]、frames 精确控制 |
| Seedance 1.0 Pro Fast | 仅首帧/文生，速度优先 |

常用 body 参数（**新方式：直接写进 request body，强校验，推荐**；旧方式 `--rs 720p` 追加在 prompt 后为弱校验，不要用）：

- `resolution`：480p / 720p / 1080p / 4k（4k 仅完整版 2.0；1080p 的 2.0 Fast/Mini 不支持）
- `ratio`：16:9 / 4:3 / 1:1 / 3:4 / 9:16 / 21:9 / `adaptive`（按输入自动适配，图生视频建议 adaptive）
- `duration`：整数秒；2.0 与 1.5 Pro 可设 `-1` 让模型自选（注意时长影响计费）
- `generate_audio`（2.0 / 1.5 Pro）：默认 true；**对白放进双引号内**可优化配音效果；输出为单声道
- `watermark`：默认 false
- `seed`：仅 1.x；相同 seed 结果类似但不保证一致
- `callback_url`：可选，任务状态变化时回调（结构同查询接口返回体）
- `execution_expires_after`：默认 48h，范围 [3600, 259200] 秒
- `service_tier: "flex"`：离线推理半价（2.0 不支持；draft 不支持）
- `return_last_frame: true`：返回无水印尾帧 PNG，**用于连续多镜头视频**（上一段尾帧作为下一段首帧）
- `draft: true`（仅 1.5 Pro）：480p 样片快速验证运镜/动作，满意后用 `content: [{"type":"draft_task","draft_task":{"id":"<样片任务id>"}}]` 生成正式视频，省钱
- prompt 字数：中文 ≤500 字、英文 ≤1000 词，过长会被模型丢细节

## 第 3 步：创建 → 轮询 → 下载（安全 SDK 示例）

```python
import os
import time

import requests
from volcenginesdkarkruntime import Ark

client = Ark(
    base_url="https://ark.cn-beijing.volces.com/api/v3",
    api_key=os.environ["ARK_API_KEY"],
)

task = client.content_generation.tasks.create(
    model=os.environ.get("ARK_VIDEO_MODEL", "doubao-seedance-2-0-260128"),
    content=[
        {"type": "text", "text": "镜头缓慢推进，产品在柔和晨光中旋转展示"},
        {
            "type": "image_url",
            "role": "first_frame",
            "image_url": {"url": "https://example.com/first.png"},
        },
    ],
    resolution="720p",
    ratio="adaptive",
    duration=5,
)

deadline = time.monotonic() + 30 * 60  # 客户端示例最多等待 30 分钟
while time.monotonic() < deadline:
    result = client.content_generation.tasks.get(task_id=task.id)
    if result.status == "succeeded":
        break
    if result.status in {"failed", "cancelled", "expired"}:
        raise RuntimeError(f"Ark task ended with status {result.status}: {result.error}")
    time.sleep(30)
else:
    raise TimeoutError(
        f"Local polling timed out; remote task {task.id} may still be running. Resume querying it later."
    )

from pathlib import Path
import shutil
import tempfile
import uuid

output_dir = Path("USER_APPROVED_OUTPUT_DIR").expanduser().resolve()
max_bytes = 1024 * 1024 * 1024  # 1 GiB safety cap; raise only with user approval
if shutil.disk_usage(output_dir).free < max_bytes:
    raise OSError("Not enough free disk space for the configured download cap")

final_path = output_dir / f"seedance-{uuid.uuid4().hex}.mp4"
fd = os.open(final_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
os.close(fd)  # Reserve a unique non-symlink path; temp file stays on same filesystem.

temp_path = None
try:
    with requests.get(result.content.video_url, stream=True, timeout=120) as response:
        response.raise_for_status()
        content_type = response.headers.get("Content-Type", "").lower()
        if "video" not in content_type and "octet-stream" not in content_type:
            raise ValueError(f"Unexpected Content-Type: {content_type}")
        content_length = int(response.headers.get("Content-Length", "0") or 0)
        if content_length > max_bytes:
            raise ValueError("Video exceeds the configured download cap")

        total = 0
        with tempfile.NamedTemporaryFile(dir=output_dir, prefix=".seedance-", delete=False) as output:
            temp_path = Path(output.name)
            for chunk in response.iter_content(1024 * 1024):
                if not chunk:
                    continue
                total += len(chunk)
                if total > max_bytes:
                    raise ValueError("Video exceeded the configured download cap")
                output.write(chunk)
        os.replace(temp_path, final_path)
        temp_path = None
finally:
    if temp_path is not None:
        temp_path.unlink(missing_ok=True)
    if final_path.exists() and final_path.stat().st_size == 0:
        final_path.unlink()
```

安装 SDK：`pip install 'volcengine-python-sdk[ark]' requests`。把 `USER_APPROVED_OUTPUT_DIR` 替换为用户确认的输出目录。官方示例每 30 秒轮询一次；生成通常需要几十秒到几分钟，不要过早判定失败。SDK 在进程内构造鉴权头，避免 Key 进入命令参数。

## 状态机与失败处理

`queued → running → succeeded / failed / expired`；`queued` 期间可 `DELETE` 取消（变为 `cancelled`，24h 后自动删除记录）。

- `failed`：读响应 `error.code` / `error.message` 反馈给用户；内容审核类失败（如真人人脸）改素材/提示词后重试。
- `expired`：任务排队/运行超过 `execution_expires_after`。再次提交会产生新任务和费用，先向用户确认。
- `running` 状态**不能取消**，只能等。
- `succeeded` / `failed` / `expired` 的记录可 `DELETE` 删除（删除后不可再查询）。
- 查询接口通常只能查最近 7 天的任务；`cancelled` 记录 24 小时后自动删除。

## 交付纪律

1. 视频必须已下载到本地（`.mp4`）再报告完成；报告前确认文件存在且大小 > 0，附**绝对路径**、实际分辨率/时长/宽高比（从查询响应的 `resolution`/`ratio`/`duration` 字段读，adaptive 与 -1 的实际值以响应为准）。输出目录：用户指定的优先；未指定时用当前工作目录（不要用系统临时目录）。
2. 报告 `usage.completion_tokens`（计费依据；2.0 系列有最低 token 用量，不足按最低计）。
3. 多镜头连续视频：每段设 `return_last_frame: true`，取 `content.last_frame_url` 尾帧图（同样 24h 失效，立即下载）作为下一段首帧。
