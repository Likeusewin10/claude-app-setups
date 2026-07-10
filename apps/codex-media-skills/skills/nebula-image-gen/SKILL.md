---
name: nebula-image-gen
description: 通过 APINebula 的 gpt-image-2（gpt-image-2-1k 分组）生成图片、参考图改图、蒙版局部重绘。当用户要求"生成图片 / 画图 / 产品图 / 改图 / 换背景 / 合成场景 / 局部重绘 / 抠图替换"时使用。首次使用先引导用户安全配置 NEBULA_API_KEY，绝不把 Key 写进代码或对话。
---

# APINebula gpt-image-2 生图技能

通过 OpenAI 兼容接口调用 `gpt-image-2` 完成三类任务：**文本生图**、**参考图编辑**、**蒙版局部重绘**。
完整逐参数说明见 [references/api.md](references/api.md)。

- 生图接口：`POST https://apinebula.com/v1/images/generations`（JSON）
- 改图/蒙版接口：`POST https://apinebula.com/v1/images/edits`（multipart/form-data）
- 模型名称：固定 `gpt-image-2`
- 鉴权：`Authorization: Bearer <write-only secret>`

## 第 0 步：确认 API Key（安全红线，每次先做）

只检查凭据是否存在，不读取或显示任何片段：

macOS / Linux：

```bash
[ -n "${NEBULA_API_KEY:-}" ] && echo "已配置" || echo "未配置"
```

Windows PowerShell：

```powershell
if ($env:NEBULA_API_KEY) { "已配置" } else { "未配置" }
```

**如果未配置**，暂停任务并引导用户使用模型不可见的安全通道：

> 请不要把 API Key 发到聊天里。请在当前工具的 Secret/凭据设置、系统钥匙串或
> Secret Manager 中保存 `NEBULA_API_KEY`，完成后只回复“配置好了”。
>
> 如果当前工具没有安全凭据输入能力，请在本地受控终端中使用隐藏输入，并让 API
> 客户端在同一个短生命周期子 shell 内运行；不要把 Key 写进命令、shell 配置或文件。

**安全红线（Agent 必须遵守）**：

- 把 Key 视为只写秘密：绝不读取、显示前后缀、写进代码/配置/脚本/git 或放进命令参数。
- 禁止在加载 Key 后执行 `env`、`printenv`、进程转储或 `set -x`；日志必须脱敏。
- 不把 Key 明文写入 `~/.zshrc`、PowerShell 用户环境或 dotenv 文件；长期保存使用系统钥匙串或 Secret Manager。
- 如果用户不小心把 Key 粘贴进了对话：立即提醒用户这个 Key 已经泄露，应去 APINebula 控制台删除并重新创建一个，然后按上面的步骤配置新 Key。
- HTTP 客户端从受控环境读取 Key，并在进程内构造 Authorization Header；不得把展开后的 Key 交给 `curl -H`。

## 第 1 步：选择接口（决策树）

| 用户想要 | 接口 | 要点 |
|---|---|---|
| 纯文字描述生成新图 | `/v1/images/generations` | JSON 请求 |
| 基于 1~N 张已有图片改图/合成（换背景、放进新场景） | `/v1/images/edits` | multipart，多张图重复 `image` 字段 |
| 只重绘图片的某个区域，其余保持不变 | `/v1/images/edits` + `mask` | 蒙版与原图尺寸一致、需带 alpha 通道 |

## 第 2 步：写好 prompt

- 写清楚：主体、场景、风格、光线、构图比例；若图中要出现文字，把文字内容写进 prompt。
- 改图时写清楚：**要保留什么、要替换什么**、输出风格、主体之间的关系（如"保留真实阴影、金属高光和桌面透视关系"）。
- 蒙版重绘时写清楚：蒙版区域画什么、非蒙版区域需要延续的光照/透视/风格。

## 第 3 步：调用

### 文本生图（安全的 curl Header 输入）

```bash
set +x
RESPONSE_FILE="$(mktemp)"
chmod 600 "$RESPONSE_FILE"
printf 'Authorization: Bearer %s\n' "$NEBULA_API_KEY" |
curl https://apinebula.com/v1/images/generations \
  -H @- \
  -H "Content-Type: application/json" \
  -o "$RESPONSE_FILE" \
  -d '{
    "model": "gpt-image-2",
    "prompt": "一张简洁的商业产品图，浅灰背景中摆放一只银白色无线耳机充电盒，光线柔和，细节清晰。",
    "size": "1024x1024",
    "quality": "medium",
    "response_format": "b64_json"
  }'
echo "响应已保存到受限临时文件，未输出到终端：$RESPONSE_FILE"
```

不要让 curl 把 `b64_json` 响应打印到工具/聊天日志。验证并解码完成后立即删除临时响应文件。

### 文本生图（Python，含落盘）

Python 示例跨平台，Windows 用户优先使用本方式，避免 PowerShell 与 bash/curl 参数语法差异。

```python
import base64
import binascii
import os
import uuid
from pathlib import Path

import requests

output_dir = Path("USER_APPROVED_OUTPUT_DIR").expanduser().resolve()
output_path = output_dir / f"generated-image-{uuid.uuid4().hex[:12]}.png"
max_json_bytes = 128 * 1024 * 1024
max_image_bytes = 64 * 1024 * 1024

resp = requests.post(
    "https://apinebula.com/v1/images/generations",
    headers={"Authorization": f"Bearer {os.environ['NEBULA_API_KEY']}"},
    json={
        "model": "gpt-image-2",
        "prompt": "……",
        "size": "1024x1024",
        "quality": "medium",
        "response_format": "b64_json",
    },
    timeout=120,  # 生图较慢，务必给足超时
)
resp.raise_for_status()
content_type = resp.headers.get("Content-Type", "").lower()
if "json" not in content_type:
    raise ValueError(f"Unexpected Content-Type: {content_type}")
if len(resp.content) > max_json_bytes:
    raise ValueError("Image response exceeds the configured JSON size cap")
b64 = resp.json()["data"][0]["b64_json"]
if len(b64) * 3 // 4 > max_image_bytes:
    raise ValueError("Decoded image would exceed the configured size cap")
try:
    image_bytes = base64.b64decode(b64, validate=True)
except binascii.Error as exc:
    raise ValueError("Invalid base64 image response") from exc

fd = os.open(output_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
with os.fdopen(fd, "wb") as output:
    output.write(image_bytes)
print(output_path)
```

把 `USER_APPROVED_OUTPUT_DIR` 替换为用户确认的输出目录。使用唯一文件名和独占创建，避免覆盖已有文件或跟随符号链接。

### 参考图编辑（多张图合成）

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

### 蒙版局部重绘

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
| 多图 | `n` 只支持 1，传 `n=2` 仍只返回 1 张 | 要多张就循环调用 |
| 尺寸 | 不支持 2K/4K；传 `2048x2048` 不报错但实际返回约 1254px | 固定用 `1024x1024` 或 `1536x1024`，不要骗自己 |
| 输出格式 | `output_format=jpeg` 返回的仍是 PNG | 一律按 PNG 处理，文件后缀写 `.png` |
| 压缩 | `output_compression` 仅在输出真为 jpeg 时才有意义 | 基本可忽略 |
| 透明背景 | `background=transparent` 有效，返回带 alpha 的 PNG | 抠图/贴纸需求直接用它 |
| 参考图跟随 | `input_fidelity=high` 可提高对输入图的跟随程度 | 产品图合成务必带上 |
| 蒙版 | 蒙版与原图尺寸必须一致，且需带 alpha 通道 | 先检查两图尺寸再提交 |
| response_format | `url` 返回的链接可能过期 | 默认用 `b64_json` 直接落盘；用 `url` 就立即下载 |

## 失败处理

- `401`：Key 无效或没带上 → 回到第 0 步检查。
- `4xx` 参数错误：核对 [references/api.md](references/api.md) 中该参数的"支持情况"列——很多 OpenAI 官方参数在此分组只是"部分支持"。
- 超时：生图正常耗时可达 1~2 分钟，客户端超时至少设 120 秒。响应不明确时不要自动重试，以免重复计费；先确认请求是否被服务端接受，再由用户决定是否重发。
- 内容审核拦截：移除不合规内容后再提交，不得通过改写提示词绕过审核；`moderation` 只有 `auto`/`low`，不能关闭。

## 交付纪律

1. 图片一律解码落盘为 `.png`，向用户报告文件路径。
2. 一次任务多张图时，文件名带序号和语义（`product-hero-01.png`）。
3. 报告中附上实际使用的 prompt，方便用户微调后重跑。
