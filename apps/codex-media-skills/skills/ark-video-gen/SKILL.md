---
name: ark-video-gen
description: 通过火山方舟（Ark）Seedance 系列模型生成视频：文生视频、图生视频（首帧/首尾帧）、多模态参考生视频（图+视频+音频）。异步任务流程：创建任务 → 轮询查询 → 立即下载。当用户要求"生成视频 / 图片转视频 / 首尾帧动画 / 带配音的视频 / 延长视频"时使用。首次使用先引导用户安全配置 ARK_API_KEY，绝不把 Key 写进代码或对话。
---

# 火山方舟 Seedance 生视频技能

视频生成是**异步任务**，必须走三步：创建任务（秒回 task id）→ 轮询查询状态 → 成功后**立即下载**视频。
四个接口的完整参数表、模型×参数支持矩阵、分辨率像素表见 [references/api.md](references/api.md)。

- Base URL：`https://ark.cn-beijing.volces.com/api/v3`
- 创建任务：`POST /contents/generations/tasks`
- 查询任务：`GET /contents/generations/tasks/{id}`
- 任务列表：`GET /contents/generations/tasks?...`
- 取消/删除：`DELETE /contents/generations/tasks/{id}`
- 鉴权：`Authorization: Bearer <write-only secret>`（长效 API Key）

## 两条铁律（违反 = 用户损失）

1. **视频 URL 只有 24 小时有效**——任务成功后必须立刻下载到本地，再向用户报告。
2. **任务记录通常只保存 7 天**——`cancelled` 记录 24 小时后自动删除；不要把 task id 当长期凭证。

## 第 0 步：确认 API Key（安全红线，每次先做）

macOS / Linux：

```bash
[ -n "${ARK_API_KEY:-}" ] && echo "已配置" || echo "未配置"
```

Windows PowerShell：

```powershell
if ($env:ARK_API_KEY) { "已配置" } else { "未配置" }
```

**如果未配置**，暂停任务并引导用户使用模型不可见的安全通道：

> 请不要把 API Key 发到聊天里。请在当前工具的 Secret/凭据设置、系统钥匙串或
> Secret Manager 中保存 `ARK_API_KEY`，完成后只回复“配置好了”。
>
> 同时在火山方舟开通所需 Seedance 模型。Seedance 2.0 系列要求账户余额大于 200 元，
> 或已购买且尚有余量的对应资源包。
>
> 如果当前工具没有安全凭据输入能力，请在本地受控终端中使用隐藏输入，并让 Ark
> 客户端在同一个短生命周期子 shell 内运行；不要把 Key 写进命令、shell 配置或文件。

**安全红线（Agent 必须遵守）**：

- 把 Key 视为只写秘密：绝不读取、显示前后缀、写进代码/配置/脚本/git 或放进命令参数。
- 禁止在加载 Key 后执行 `env`、`printenv`、进程转储或 `set -x`；日志必须脱敏。
- 不把 Key 明文写入 shell 启动文件、PowerShell 用户环境或 dotenv；长期保存使用系统钥匙串或 Secret Manager。
- HTTP/SDK 客户端从受控环境读取 Key，并在进程内构造 Authorization Header；不得把展开后的 Key 交给 `curl -H`。
- 用户在对话中粘贴了 Key → 立即提醒：该 Key 已泄露，去控制台「API Key 管理」删除并重建，再按上面步骤配置。
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

首次使用必须先确定可用的 `model` 或推理接入点（Endpoint）ID，不能把模型家族名或示例占位符直接提交：

1. 让用户在火山方舟控制台开通目标 Seedance 模型，并在模型/推理接入点页面复制实际 ID；不要让用户把 API Key 一并复制。
2. 如果当前环境已设置非秘密变量 `ARK_VIDEO_MODEL`，只读取其完整 ID 用于请求；否则让用户提供实际 model/Endpoint ID，并在本次调用前确认。
3. 拒绝 `YOUR_MODEL_OR_ENDPOINT_ID` 等占位符。提交收费任务前再次确认模型、时长、分辨率和预计成本等级。

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
    model=os.environ["ARK_VIDEO_MODEL"],
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

1. 视频必须已下载到本地（`.mp4`）再报告完成，附文件路径、实际分辨率/时长/宽高比（从查询响应的 `resolution`/`ratio`/`duration` 字段读，adaptive 与 -1 的实际值以响应为准）。
2. 报告 `usage.completion_tokens`（计费依据；2.0 系列有最低 token 用量，不足按最低计）。
3. 多镜头连续视频：每段设 `return_last_frame: true`，取 `content.last_frame_url` 尾帧图（同样 24h 失效，立即下载）作为下一段首帧。
