# 火山方舟 视频生成 API 完整参数参考

> 来源：火山方舟官方文档（Seedance 2.0 API 参考，docs.volcengine.com/docs/82379/1520757、1521309、1521675、1521720，抓取于 2026-07-10，文档更新时间 2026-07-07）。

Base URL：`https://ark.cn-beijing.volces.com/api/v3`
鉴权：仅支持 API Key（长效），`Authorization: Bearer <API_KEY>`。客户端应在进程内从 Secret Manager 或受控环境读取 Key；不要把展开后的 Key 放进命令参数。

## 目录

- [模型能力总览](#模型能力总览)
- [创建视频生成任务](#1-创建视频生成任务-post-contentsgenerationstasks)
- [查询视频生成任务](#2-查询视频生成任务-get-contentsgenerationstasksid)
- [查询任务列表](#3-查询任务列表-get-contentsgenerationstaskspage_numpage_sizefilterstatusfiltertask_idsfiltermodel)
- [取消或删除任务](#4-取消或删除任务-delete-contentsgenerationstasksid)

## 模型能力总览

| 模型 | 文生视频 | 首帧 | 首尾帧 | 多模态参考 | 有声视频 | draft 样片 |
|---|---|---|---|---|---|---|
| Seedance 2.0 系列 | ✅ | ✅ | ✅ | ✅（图 0-9 + 视频 0-3 + 音频 0-3） | ✅ | ❌ |
| Seedance 1.5 Pro | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Seedance 1.0 Pro | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Seedance 1.0 Pro Fast | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

开通 Seedance 2.0 前提：账户余额 > 200 元，或已购买 Seedance 2.0 资源包且有余量。

---

## 1. 创建视频生成任务 `POST /contents/generations/tasks`

### Body 参数

| 参数 | 类型 | 必选 | 默认 | 说明 |
|---|---|---|---|---|
| model | string | ✅ | — | Model ID；也可用 Endpoint ID（获得限流/计费/监控等高级能力） |
| content | object[] | ✅ | — | 输入信息数组，见下方「content 信息类型」 |
| callback_url | string | | — | 任务状态变化时向该地址推 POST，内容结构同查询接口返回体；status 含 queued/running/succeeded/failed/expired；发送失败（5 秒内未确认）回调三次 |
| return_last_frame | boolean | | false | true 时可通过查询接口获取尾帧图（PNG、与视频同宽高、无水印），用于连续视频接力 |
| service_tier | string | | default | `default` 在线推理；`flex` 离线推理（TPD 配额更高、价格为在线 50%）。**2.0 系列仅支持在线**；已提交任务不可改 |
| execution_expires_after | integer | | 172800 | 任务过期阈值（秒），范围 [3600, 259200]，超时任务标记 expired |
| generate_audio | boolean | | true | 仅 2.0 系列、1.5 Pro。true 生成同步音频（人声/音效/BGM，**对白置于双引号内效果更好**；输出单声道）；false 无声 |
| draft | boolean | | false | 仅 1.5 Pro。样片模式：480p（其他分辨率报错）、不支持尾帧、不支持离线推理，token 消耗更少 |
| tools | object[] | | — | 仅 2.0 系列。`{"type":"web_search"}` 联网搜索，模型自主判断是否搜索；次数见查询响应 `usage.tool_usage.web_search` |
| safety_identifier | string | | — | 终端用户唯一标识（≤64 字符，建议哈希），协助平台风控 |
| priority | integer | | 0 | 仅 2.0 系列。0~9，越大越优先（同 Endpoint 内插队，不中断 running 任务；flex 不支持） |
| resolution | string | | 见下 | 480p / 720p / 1080p / 4k。默认：2.0 系列与 1.5 Pro 为 720p，1.0 系列为 1080p。1080p：2.0 Fast/Mini 不支持；4k：仅完整版 2.0（10bit、H.265，部分播放器不兼容） |
| ratio | string | | 见下 | 16:9 / 4:3 / 1:1 / 3:4 / 9:16 / 21:9 / adaptive。默认：2.0 系列与 1.5 Pro 为 adaptive；其他模型文生 16:9、图生 adaptive。adaptive 实际值以查询响应 ratio 为准 |
| duration | integer | | 5 | 整数秒。1.0 系列 [2,12]；1.5 Pro [4,12] 或 -1；2.0 系列 [4,15] 或 -1（-1 = 模型自选，时长影响计费）。duration 与 frames 二选一，frames 优先 |
| frames | integer | | — | 2.0 系列、1.5 Pro 不支持。帧数 = 时长×24；取值 [29,289] 且满足 25+4n。用于小数秒时长 |
| seed | integer | | -1 | 2.0 系列不支持。[-1, 2^32-1]；-1 为随机；相同 seed 结果类似但不保证一致 |
| camera_fixed | boolean | | false | 固定摄像头（在提示词追加实现，效果不保证）。参考图场景与 2.0 系列不支持 |
| watermark | boolean | | false | true 时右下角显示"AI 生成"水印 |

> 参数传入方式：**新方式（推荐）**直接写入 request body（强校验，错误会报错）；旧方式在提示词后追加 `--rs 720p --rt 16:9 --dur 5 --seed 11 --cf false --wm true`（弱校验，错误被忽略）。

### content 信息类型

**文本** `{"type":"text","text":"..."}`
- 所有模型支持中英文；2.0 系列另支持日语、印尼语、西班牙语、葡萄牙语。
- 建议中文 ≤500 字、英文 ≤1000 词，过长导致模型丢细节。

**图片** `{"type":"image_url","role":"...","image_url":{"url":"..."}}`
- `url` 三种形式：公网 URL；Base64（`data:image/<小写格式>;base64,<编码>`）；素材 ID（`asset://<ASSET_ID>`，来自素材&虚拟人像库）。
- `role`：`first_frame`（首帧，可省略）/ `last_frame`（尾帧）/ `reference_image`（参考图，必填）。
- 三种场景（首帧 / 首尾帧 / 多模态参考）**互斥不可混用**。首尾帧图片可相同；宽高比不一致时以首帧为准，尾帧自动裁剪。
- 图片要求：jpeg/png/webp/bmp/tiff/gif（1.5 Pro、2.0 系列另支持 heic/heif）；宽高比 [0.4,2.5]；边长 [300,6000]px；单张 <30MB；请求体 ≤64MB（大文件勿用 Base64）。
- 数量：首帧 1 张；首尾帧 2 张；多模态参考 1~9 张（仅 2.0 系列）。

**视频** `{"type":"video_url","role":"reference_video","video_url":{"url":"..."}}`（仅 2.0 系列）
- `url`：公网 URL 或素材 ID。
- 要求：mp4/mov（视频编码 H.264/H.265，音频 AAC/MP3）；分辨率 480p~4k；单个 2~15s，最多 3 个且总时长 ≤15s；宽高比 [0.4,2.5]；边长 [300,6000]px；总像素 [409600, 8295044]；单个 ≤200MB；FPS [24,60]。
- 真人人脸：不可直接上传；可用本账号 30 天内 Seedance 2.0 生成的含人脸产物、预置虚拟人像、已授权真人素材。

**音频** `{"type":"audio_url","role":"reference_audio","audio_url":{"url":"..."}}`（仅 2.0 系列）
- `url`：公网 URL、Base64（`data:audio/<小写格式>;base64,...`）或素材 ID。
- 要求：wav/mp3；单个 2~15s，最多 3 段且总时长 ≤15s；单个 ≤15MB。
- **不可单独输入音频**，至少配 1 个参考视频或图片。

**样片任务** `{"type":"draft_task","draft_task":{"id":"<draft任务id>"}}`（仅 1.5 Pro）
- 基于 draft 样片生成正式视频；平台自动复用样片的 model、text、image_url、generate_audio、seed、ratio、duration、camera_fixed，其余参数可另行指定。

### 响应

| 字段 | 说明 |
|---|---|
| id | 任务 ID。通常最多查询最近 7 天；cancelled 记录 24 小时后自动删除。异步接口，需用查询接口获取状态与 video_url |

### 分辨率 × 宽高比 → 像素值

| 分辨率 | 宽高比 | 2.0 系列 | 1.5 Pro | 1.0 系列 |
|---|---|---|---|---|
| 480p | 16:9 | 864×496 | 864×496 | 864×480 |
| 480p | 4:3 | 752×560 | 752×560 | 736×544 |
| 480p | 1:1 | 640×640 | 640×640 | 640×640 |
| 480p | 3:4 | 560×752 | 560×752 | 544×736 |
| 480p | 9:16 | 496×864 | 496×864 | 480×864 |
| 480p | 21:9 | 992×432 | 992×432 | 960×416 |
| 720p | 16:9 | 1280×720 | 1280×720 | 1248×704 |
| 720p | 4:3 | 1112×834 | 1112×834 | 1120×832 |
| 720p | 1:1 | 960×960 | 960×960 | 960×960 |
| 720p | 3:4 | 834×1112 | 834×1112 | 832×1120 |
| 720p | 9:16 | 720×1280 | 720×1280 | 704×1248 |
| 720p | 21:9 | 1470×630 | 1470×630 | 1504×640 |
| 1080p | 16:9 | 1920×1080 | 1920×1080 | 1920×1088 |
| 1080p | 4:3 | 1664×1248 | 1664×1248 | 1664×1248 |
| 1080p | 1:1 | 1440×1440 | 1440×1440 | 1440×1440 |
| 1080p | 3:4 | 1248×1664 | 1248×1664 | 1248×1664 |
| 1080p | 9:16 | 1080×1920 | 1080×1920 | 1088×1920 |
| 1080p | 21:9 | 2206×946 | 2206×946 | 2176×928 |
| 4k | 16:9 | 3840×2160 | — | — |
| 4k | 4:3 | 3326×2494 | — | — |
| 4k | 1:1 | 2880×2880 | — | — |
| 4k | 3:4 | 2494×3326 | — | — |
| 4k | 9:16 | 2160×3840 | — | — |
| 4k | 21:9 | 4398×1886 | — | — |

注：图生视频时所选宽高比与图片不一致 → 平台居中裁剪。

---

## 2. 查询视频生成任务 `GET /contents/generations/tasks/{id}`

- 通常仅支持查询最近 7 天的任务；`cancelled` 记录 24 小时后自动删除。**video_url 有效期 24 小时**，及时下载或转存（可配置 TOS 数据订阅自动转存）。

### 响应字段

| 字段 | 说明 |
|---|---|
| id / model | 任务 ID；模型名称-版本 |
| status | `queued` / `running` / `cancelled`（取消 24h 后自动删除）/ `succeeded` / `failed` / `expired` |
| error | 成功为 null；失败为 `{code, message}` |
| created_at / updated_at | Unix 时间戳（秒） |
| content.video_url | 生成视频 URL（mp4），24h 有效 |
| content.last_frame_url | 尾帧图 URL（创建时 `return_last_frame: true` 才返回），24h 有效 |
| seed / resolution / ratio / duration / frames / framespersecond | 实际生效值；duration 与 frames 只返回其一 |
| generate_audio | 仅 2.0 系列、1.5 Pro 返回 |
| tools / safety_identifier / priority | 2.0 系列相关，原样/实际值返回 |
| draft / draft_task_id | 仅 1.5 Pro；基于样片生成正式视频时返回 draft_task_id |
| service_tier / execution_expires_after | 实际服务等级 / 超时阈值 |
| usage.completion_tokens | 计费依据；**2.0 系列有最低 token 用量，不足按最低计费** |
| usage.total_tokens | = completion_tokens（视频模型不计输入 token） |
| usage.tool_usage.web_search | 联网搜索实际次数（开启时返回） |

---

## 3. 查询任务列表 `GET /contents/generations/tasks?page_num=&page_size=&filter.status=&filter.task_ids=&filter.model=`

### Query 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| page_num | 1 | [1,500] |
| page_size | 20 | [1,500] |
| filter.status | — | queued / running / cancelled / succeeded / failed |
| filter.task_ids | — | 精确搜索，多个用重复参数：`filter.task_ids=id1&filter.task_ids=id2` |
| filter.model | — | **注意：此处为推理接入点（Endpoint）ID**，非模型名 |
| filter.service_tier | default | default / flex |

响应：`items[]`（字段同查询接口）+ `total`（符合条件的任务总数）。通常仅最近 7 天，`cancelled` 记录除外。

---

## 4. 取消或删除任务 `DELETE /contents/generations/tasks/{id}`

| 当前状态 | 支持 DELETE | 含义 | 之后状态 |
|---|---|---|---|
| queued | ✅ | 取消排队 | cancelled |
| running | ❌ | — | — |
| succeeded | ✅ | 删除记录，不可再查询 | — |
| failed | ✅ | 删除记录，不可再查询 | — |
| cancelled | ❌ | — | — |
| expired | ✅ | 删除记录，不可再查询 | — |

响应：无返回参数（`{}`）。

```text
DELETE https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks/{id}
```

使用 SDK 或在进程内注入鉴权头的 HTTP 客户端调用；不要把 Key 展开进 `curl -H` 参数。
