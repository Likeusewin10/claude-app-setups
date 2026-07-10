---
name: nebula-image-gen
description: 通过 APINebula 的 gpt-image-2（gpt-image-2-1k 分组）生成图片、参考图改图、蒙版局部重绘。当用户要求"生成图片 / 画图 / 产品图 / 改图 / 换背景 / 合成场景 / 局部重绘 / 抠图替换"时使用。首次使用会引导用户在对话中提供 NEBULA_API_KEY 并保存到本机 Key 文件，绝不把 Key 写进代码或 git。
---

# APINebula gpt-image-2 生图技能

通过 OpenAI 兼容接口调用 `gpt-image-2` 完成三类任务：**文本生图**、**参考图编辑**、**蒙版局部重绘**。
完整逐参数说明见 [references/api.md](references/api.md)。

**本 skill 激活时，禁止改用平台内置的图像生成/画布预览能力**——内置预览不产生本地文件，用户拿不到可用交付物。必须调用下方 APINebula 接口，把图片落盘为本地文件，并报告**绝对路径**。

- 生图接口：`POST https://apinebula.com/v1/images/generations`（JSON）
- 改图/蒙版接口：`POST https://apinebula.com/v1/images/edits`（multipart/form-data）
- 模型名称：固定 `gpt-image-2`
- 鉴权：`Authorization: Bearer $NEBULA_API_KEY`（来源见第 0 步）

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
2. 写入 Key 文件的 `NEBULA_API_KEY=<key>` 行（目录/文件不存在则创建；已有该行则整行替换）。权限规则分平台：macOS/Linux 执行 `chmod 600`；**Windows 不要修改 ACL**——`%USERPROFILE%` 下默认已仅限当前用户，错误的 ACL 收紧会导致后续读取被拒、Key 被误判为未配置。写入命令不得让 Key 出现在 shell 历史可见的命令行参数里（优先用编程方式写文件）。
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

把 `USER_APPROVED_OUTPUT_DIR` 替换为输出目录：用户指定的优先；未指定时用**当前工作目录**（不要用系统临时目录，用户找不到）。使用唯一文件名和独占创建，避免覆盖已有文件或跟随符号链接。

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

1. 图片一律解码落盘为 `.png`；报告前先确认文件存在且大小 > 0，然后向用户报告**绝对路径**。只出现在界面预览里、没有落盘路径的图片不算交付。
2. 一次任务多张图时，文件名带序号和语义（`product-hero-01.png`）。
3. 报告中附上实际使用的 prompt，方便用户微调后重跑。
