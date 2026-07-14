# gpt-image-2-1k 分组 API 完整参数参考

> 来源：APINebula 官方文档 `docs.apinebula.com/docs/advanced/image/gpt-image-2-1k`（抓取于 2026-07-10）
> 与 `docs.apinebula.com/docs/advanced/image-tasks`（抓取于 2026-07-14）。
> "支持情况"为该文档的实测标注，与 OpenAI 官方 Images API 行为存在差异，以本表为准。

## 通用

- Base URL：`https://apinebula.com/v1`
- 鉴权：`Authorization: Bearer <API_KEY>`
- 模型：固定 `gpt-image-2`
- 同步响应结构：`{ "data": [ { "b64_json": "..." } ] }` 或 `{ "data": [ { "url": "..." } ] }`
- 异步为默认方式；服务端调用上游时自动追加 `async=true`，客户端**不需要**传该参数。

## 0. 异步任务接口（默认）

### 0.1 创建生图任务 `POST /v1/image-tasks/generations`（JSON）

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| model | string | 是 | 固定 `gpt-image-2` |
| prompt | string | 是 | 图片生成提示词 |
| quality | string | 否 | 如 `low` / `medium` / `high` |

响应：`{ "id": "task_...", "task_id": "task_...", "object": "image.task", "model": "gpt-image-2", "status": "queued", "created_at": ... }`

### 0.2 创建改图任务 `POST /v1/image-tasks/edits`（JSON）

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| model | string | 是 | 固定 `gpt-image-2` |
| prompt | string | 是 | 图片编辑提示词 |
| images | array | 是 | 图片列表，元素为 `{ "image_url": "<公网 URL>" }`；**不支持本地文件与蒙版** |
| quality | string | 否 | 同上 |

### 0.3 查询任务详情 `GET /v1/image-tasks/{task_id}`

| Query 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| detail | boolean | 否 | 传 `true` 时返回上游 `detail` 内容（含 `download_url`） |

成功响应（`detail=true`）：

```json
{
  "id": "task_...",
  "object": "image",
  "model": "gpt-image-2",
  "status": "completed",
  "created_at": 1779104464,
  "completed_at": 1779104532,
  "detail": {
    "data": [ { "download_url": "https://pubimage.apinebula.com/....png" } ],
    "response_format": "b64_json"
  }
}
```

失败响应含 `"status": "failed"` 与 `error.message`。

### 0.4 状态机与计费

| 状态 | 说明 |
|---|---|
| queued | 任务排队中（上游 queued / waiting） |
| in_progress | 任务处理中（上游 running / in_progress） |
| completed | 任务成功（上游 succeeded / completed） |
| failed | 任务失败或被取消（上游 failed / cancelled） |

- 计费按请求里的 `model` 对应的系统配置计费。
- 异步任务最终失败或取消时，按任务预扣额度退回。

## 1. 同步生图 `POST /v1/images/generations`（JSON，兜底）

| 参数 | 类型 | 支持情况 | 说明 |
|---|---|---|---|
| model | string | 支持 | 固定填写 `gpt-image-2` |
| prompt | string | 支持 | 建议写清楚主体、场景、风格、比例和文字内容 |
| n | integer | **仅支持 1** | 实测传 `n=2` 仍只返回 1 张图 |
| size | string | 部分支持 | 可传 `1024x1024`；`2048x2048` 不报错但实测返回约 1254x1254；**不支持 2K、4K** |
| quality | string | 支持 | `low` / `medium` / `high` / `auto` |
| response_format | string | 支持 | `url` 返回 `data[0].url`；`b64_json` 返回 `data[0].b64_json` |
| output_format | string | 部分支持 | 可传 `png`、`jpeg`；**实测 jpeg 仍返回 PNG**，不能作为稳定格式开关 |
| output_compression | integer | 部分支持 | 0~100，仅当输出实际为 jpeg 时有压缩意义 |
| background | string | 支持 | `opaque` / `transparent`；transparent 实测可返回带 alpha 的 PNG |
| moderation | string | 支持 | `auto` / `low`，安全审核参数，不改变画面风格 |
| user | string | 支持 | 可选，标记终端用户/业务来源 |

## 2. 同步参考图编辑 `POST /v1/images/edits`（multipart/form-data，兜底）

| 参数 | 类型 | 支持情况 | 说明 |
|---|---|---|---|
| model | string | 支持 | 固定 `gpt-image-2` |
| prompt | string | 支持 | 写清楚要保留什么、替换什么、输出风格和主体关系 |
| image | file[] | 支持 | 一张或多张参考图；**多张图使用重复的 `image` 字段** |
| mask | file | 支持 | 可选；传入后用于蒙版局部重绘 |
| n | integer | **仅支持 1** | 一次只返回 1 张 |
| size | string | 部分支持 | 示例可传 `1536x1024`；不支持 2K、4K |
| quality | string | 支持 | `low` / `medium` / `high` / `auto` |
| response_format | string | 支持 | `url` / `b64_json` |
| input_fidelity | string | 支持 | 支持 `high`，提高对输入参考图的跟随程度 |
| output_format | string | 部分支持 | 同上，jpeg 实测仍返回 PNG |
| output_compression | integer | 部分支持 | 同上 |
| background | string | 支持 | `opaque` / `transparent` |
| moderation | string | 支持 | `auto` / `low` |
| user | string | 支持 | 可选 |

## 3. 蒙版局部重绘 `POST /v1/images/edits`（multipart/form-data，仅同步）

在参考图编辑的基础上：

| 参数 | 类型 | 支持情况 | 说明 |
|---|---|---|---|
| image | file | 支持 | 上传原图（单张） |
| mask | file | 支持 | 上传蒙版；**原图和蒙版尺寸要一致，蒙版需要带 alpha 通道** |
| prompt | string | 支持 | 描述蒙版区域要重绘成什么，以及非蒙版区域需保留的光照、透视和风格 |
| input_fidelity | string | 支持 | `high` 提高对原图内容的跟随程度 |
| size | string | 部分支持 | 不确定时保持默认或用 `1024x1024` |

其余参数（n / quality / response_format / output_format / output_compression / background / moderation / user）与参考图编辑一致。

## 场景建议

- 常规生图/URL 素材改图 → 异步任务接口（默认）：不阻塞、失败退款、结果为可直接下载的 `download_url`。
- 本地文件改图、蒙版重绘、需要 size / background 等细粒度参数 → 同步 Images API。
- 需要把图片能力与多轮对话、工作流、工具调用组合 → 再考虑配合对话接口设计。
