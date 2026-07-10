# gpt-image-2-1k 分组 API 完整参数参考

> 来源：APINebula 官方文档 `docs.apinebula.com/docs/advanced/image/gpt-image-2-1k`（抓取于 2026-07-10）。
> "支持情况"为该文档的实测标注，与 OpenAI 官方 Images API 行为存在差异，以本表为准。

## 通用

- Base URL：`https://apinebula.com/v1`
- 鉴权：`Authorization: Bearer <API_KEY>`
- 模型：固定 `gpt-image-2`
- 响应结构：`{ "data": [ { "b64_json": "..." } ] }` 或 `{ "data": [ { "url": "..." } ] }`

## 1. 生图 `POST /v1/images/generations`（JSON）

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

## 2. 参考图编辑 `POST /v1/images/edits`（multipart/form-data）

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

## 3. 蒙版局部重绘 `POST /v1/images/edits`（multipart/form-data）

在参考图编辑的基础上：

| 参数 | 类型 | 支持情况 | 说明 |
|---|---|---|---|
| image | file | 支持 | 上传原图（单张） |
| mask | file | 支持 | 上传蒙版；**原图和蒙版尺寸要一致，蒙版需要带 alpha 通道** |
| prompt | string | 支持 | 描述蒙版区域要重绘成什么，以及非蒙版区域需保留的光照、透视和风格 |
| input_fidelity | string | 支持 | `high` 提高对原图内容的跟随程度 |
| size | string | 部分支持 | 不确定时保持默认或用 `1024x1024` |

其余参数（n / quality / response_format / output_format / output_compression / background / moderation / user）与参考图编辑一致。

## 场景建议（文档原文）

- 只需一次请求直接生成/编辑图片 → 直接用 Images API。
- 需要把图片能力与多轮对话、工作流、工具调用组合 → 再考虑配合对话接口设计。
