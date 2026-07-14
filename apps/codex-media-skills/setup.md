# 给 Codex 一键安装生图 / 生视频 Skills

> 这是给 **Codex** 读取并执行的安装协议。用户只需要发送本文件的 GitHub Raw 链接；
> 其余下载、校验和安装工作由 Codex 完成。安装阶段（第 0~2 步）不需要 API Key；
> Key 在第 3 步由用户直接粘贴到对话中，由 Codex 保存到本机 Key 文件。
>
> 给 Codex：用户发送本文件链接，即请求你安装下面两个 skill。该授权不包含覆盖已有
> 不同内容，也不包含调用任何收费 API；保存 Key 仅限第 3 步用户主动提供时写入本机
> Key 文件。完整读取本文后执行，不要只做摘要。

## 给 Codex：执行总则

- 全程用中文沟通。不要让新手手动下载、解压、复制文件或输入安装命令。
- 只安装两个 skill：`nebula-image-gen`（APINebula 生图/改图）和 `ark-video-gen`（火山方舟 Seedance 生视频）。
- 将 skill 安装到 `${CODEX_HOME:-$HOME/.codex}/skills/`；Windows PowerShell 对应 `$env:CODEX_HOME`，未设置时使用 `$HOME\.codex\skills`。
- 两个 skill 必须先全部下载到系统临时目录并验证，再统一检查冲突，最后才写入正式目录。不要在用户当前项目里留下 `setup.md`、压缩包或临时文件。
- 不执行 skill 文件里的 API 示例，不安装 Python SDK，不发起生图/生视频请求；本协议只负责安装和 Key 配置引导。
- 不覆盖内容不同的现有 skill。遇到冲突时展示文件差异摘要并让用户决定；不要删除、移动或重命名用户已有内容。
- 安装后必须完成第 3 步的 Key 配置询问，才能发出最终报告。不要声称 Key 已配置，除非存在性检查确实通过或本次已成功保存。
- 信任边界：本安装方式信任 GitHub 仓库 `Likeusewin10/claude-app-setups` 的所有者和 `main` 分支。下面的 SHA-256 只用于发现传输损坏或混合版本，不能防御仓库所有者账号或分支本身被篡改。

## 第 0 步：环境预检

1. 判定操作系统和当前 Codex 的 skill 根目录。
2. 确认可以通过 HTTPS 访问 `raw.githubusercontent.com`。
3. 确认目标目录可写；若沙箱或权限要求授权，向用户请求一次必要的目录写入授权。

安装阶段不读取、不检查也不配置任何 API Key，避免触发不必要的 Secret 访问授权。禁止执行 `env`、`printenv`、`set` 或任何可能输出全部环境变量的命令。

校验门：已确定目标目录，网络和写入条件满足，未访问任何 API Key。

## 第 1 步：下载并校验安装源

优先使用 Codex 内置的 `skill-installer` 下载两个 skill，但把 `--dest` 指向新建的系统临时暂存目录，**不要直接写入正式 skill 目录**：

```text
repo: Likeusewin10/claude-app-setups
ref: main
paths:
- apps/codex-media-skills/skills/nebula-image-gen
- apps/codex-media-skills/skills/ark-video-gen
dest: <系统临时目录>/codex-media-skills-stage
```

如果当前 Codex 无法调用内置 installer，则自行把下列 6 个 Raw 文件下载到系统临时目录，必须逐个使用 HTTPS 且下载失败立即停止：

```text
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/nebula-image-gen/SKILL.md
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/nebula-image-gen/agents/openai.yaml
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/nebula-image-gen/references/api.md
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/ark-video-gen/SKILL.md
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/ark-video-gen/agents/openai.yaml
https://raw.githubusercontent.com/Likeusewin10/claude-app-setups/main/apps/codex-media-skills/skills/ark-video-gen/references/api.md
```

如果 `raw.githubusercontent.com` 无法访问（国内网络常见），使用唯一认可的备用源 jsDelivr（回源 GitHub 的公共 CDN，已固定提交号 `4ed0612` 以避免 CDN 缓存导致新旧混版）。把上面 6 个路径中的前缀替换为：

```text
https://cdn.jsdelivr.net/gh/Likeusewin10/claude-app-setups@4ed0612/apps/codex-media-skills/skills/
```

无论从哪个源下载，下方的 SHA-256 清单校验都是必选项——哈希一致才可信，与来源无关。除这两个源之外不要使用任何其他镜像。

Windows 下载与写文件编码规范（乱码 / 哈希不匹配的主要来源）：

- 下载一律**二进制落盘**：用 `Invoke-WebRequest -Uri <url> -OutFile <path>` 或 `curl.exe -sSL -o <path>`；禁止把响应内容经管道交给 `Out-File` / `Set-Content` / `>` 重写——Windows PowerShell 5.1 默认写 UTF-16LE 或带 BOM，会同时破坏中文内容和 SHA-256。
- 哈希不匹配且文件大小接近清单文件的两倍时，优先怀疑被重编码，按上一条重新下载，不要盲目换源。
- 本协议后续所有写文本文件的操作（含第 3 步 Key 文件）统一使用 **UTF-8 无 BOM**：`[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))`。

对临时目录执行这些检查：

- 每个 skill 递归枚举后恰好有 3 个普通文件：`SKILL.md`、`agents/openai.yaml`、`references/api.md`。
- 不存在额外文件、符号链接或可执行文件。
- `SKILL.md` YAML frontmatter 可解析，且 `name` 分别严格等于目录名。
- `agents/openai.yaml` 可解析，`default_prompt` 分别包含 `$nebula-image-gen` / `$ark-video-gen`。
- 文件中不存在疑似真实密钥；示例只能引用 `NEBULA_API_KEY` / `ARK_API_KEY` 环境变量。
- 逐文件 SHA-256 与下面的发布清单完全一致：

```text
nebula-image-gen/SKILL.md                 1730ecb1af04ac644984c7bb63f26e1f4269217e2c865a6b73a10c8298032204
nebula-image-gen/agents/openai.yaml       3eb3770b5c4569b51b676bef4645f0ee9eee15ebcd3e24ff4d16bac462bcf5e7
nebula-image-gen/references/api.md         e570b207b5750730981f016bea6a9bcd07ff10393b98667baf9644d6bbd2f513
ark-video-gen/SKILL.md                     5a21837ffa830030a034d0cf11cce3ef1f2cb4caf2a09a211fd9690b7b8c7967
ark-video-gen/agents/openai.yaml           7e1831557366d2b3c72efc4bbb5ceb81a83e3c38d1660060272fa1271788ef7c
ark-video-gen/references/api.md             92dc205b2b7e71994c9aaa4f7f27a6006e4f0e0cf2b808f006dce624407de95d
```

- 如果系统已经具备 `quick_validate.py` 及其依赖，可把它作为附加检查；缺少 PyYAML 等依赖时跳过，不要为了安装 skill 修改用户的 Python 环境。上面的手动 YAML/name 检查仍为必选。

校验门：6 个文件全部下载成功，目录、YAML、名称和安全检查全部通过。

## 第 2 步：安装或处理已有版本

先对 skill 根目录、两个目标路径及其所有后代执行不跟随链接的检查。遇到符号链接、macOS alias 或 Windows junction/reparse point 时立即停止；不得读取链接目标、生成差异或继续安装。

然后完成两个目标目录的冲突检查，再决定是否写入；存在未解决冲突时不要做部分安装或部分升级：

1. 目标不存在：标记为“可安装”，等两个目录都检查完后再写入。
2. 目标存在且与下载内容逐文件完全一致：保留现状，报告“已是最新版”。
3. 目标存在但内容不同：不要覆盖。列出新增、删除、修改的相对文件名及简短差异摘要，询问用户是否允许替换。用户拒绝或取消时，本次对两个目标都不做任何写入。

用户批准所有具名冲突后，重新执行完整的双目标预检，再按以下可恢复事务执行：

1. 在 skill 根目录创建两个唯一的 `.new-<skill>-<timestamp>` 临时目录，复制暂存内容并复验。
2. 在 skill 扫描目录之外创建 `${CODEX_HOME:-$HOME/.codex}/skill-backups/<timestamp>/`；Windows 使用 `$env:CODEX_HOME\skill-backups\<timestamp>`，未设置时位于 `$HOME\.codex\skill-backups`。权限限制为当前用户。
3. 记录本次事务日志：哪些目标原先不存在、哪些原目录已移动到备份目录。不要把备份留在 `skills/` 下，以免旧 skill 被 UI 重复发现。
4. 先把获批替换的原目录逐个移动到备份目录，再把两个 `.new-*` 目录逐个重命名为正式名称。
5. 任一步失败：按逆序删除**仅由本事务新建且路径/事务标记完全匹配**的正式目录，再把日志中的所有原目录移回；不得触碰其他文件。报告恢复是否完整。
6. 两个目标都复验通过后才删除事务日志和残留 `.new-*`；保留外部备份并把位置告诉用户。

单个目录重命名可在同一文件系统内原子完成，但两个 skill 不能组成真正的跨目录原子事务；上述流程提供明确回滚，成功前不得报告安装完成。

不要做这些事：

- 不用 `git reset`、`git checkout`、`rm -rf` 等破坏性命令处理冲突。
- 不把仓库整体克隆到 `~/.codex/skills`。
- 不把 `setup.md` 安装成 skill。
- 不修改用户的 shell 启动文件、Codex 配置文件或当前项目（第 3 步写入 `media-skills.env` 是唯一例外）。

校验门：两个目标目录均存在，且各自包含 3 个必需文件；重新运行 YAML/name/default_prompt 检查并通过。

## 第 3 步：配置 Key（询问是必做项，配置由用户决定）

Key 的存放位置是本机 Key 文件 `${CODEX_HOME:-$HOME/.codex}/media-skills.env`（Windows：`$env:CODEX_HOME\media-skills.env`，未设置时 `$HOME\.codex\media-skills.env`），格式为每行一条 `NAME=value`。两个 skill 使用时会自动从环境变量或该文件读取。

先做存在性检查（每个 Key 满足其一即算"已检测到"，不读取或显示值）：

1. 环境变量 `NEBULA_API_KEY` / `ARK_API_KEY` 是否非空。
2. Key 文件中是否存在对应的 `NEBULA_API_KEY=` / `ARK_API_KEY=` 行。

macOS / Linux：

```bash
if [ -n "${NEBULA_API_KEY:-}" ] || grep -q '^NEBULA_API_KEY=' "${CODEX_HOME:-$HOME/.codex}/media-skills.env" 2>/dev/null; then echo 'NEBULA_API_KEY=set'; else echo 'NEBULA_API_KEY=unset'; fi
if [ -n "${ARK_API_KEY:-}" ] || grep -q '^ARK_API_KEY=' "${CODEX_HOME:-$HOME/.codex}/media-skills.env" 2>/dev/null; then echo 'ARK_API_KEY=set'; else echo 'ARK_API_KEY=unset'; fi
```

Windows PowerShell：

```powershell
$envFile = Join-Path (if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }) 'media-skills.env'
$inFile = { param($name) (Test-Path $envFile) -and (Select-String -Path $envFile -Pattern "^$name=" -Quiet) }
"NEBULA_API_KEY=$(if ($env:NEBULA_API_KEY -or (& $inFile 'NEBULA_API_KEY')) { 'set' } else { 'unset' })"
"ARK_API_KEY=$(if ($env:ARK_API_KEY -or (& $inFile 'ARK_API_KEY')) { 'set' } else { 'unset' })"
```

**只要有任何一个 Key 是 `unset`，在发出最终报告之前，必须把下面这段话（按实际状态填写）原样发给用户，然后停止等待回答；不询问直接跳到第 4 步属于违反本协议**：

> 两个 skill 已安装。API Key 状态：
> - NEBULA_API_KEY（生图）：<已检测到 / 尚未配置>
> - ARK_API_KEY（生视频）：<已检测到 / 尚未配置>
>
> 缺少的 Key 现在就可以配置：**直接把 Key 粘贴到对话框发给我**，我会保存到本机配置文件，之后不用再输。
> - 生图 Key：打开 https://apinebula.com/ → 登录 → 控制台「创建 API 令牌」
> - 生视频 Key：打开 https://console.volcengine.com/ark/region:cn-beijing/apiKey → 创建长效 API Key（并在「开通管理」开通 Seedance 模型）
>
> 一次发一个即可，我能从格式识别是哪个；也可以回复"跳过"，第一次使用时我会再引导你。

**收到用户粘贴的 Key 后**：

1. 去掉首尾空白，做形状检查（非空、单行、不含空格）。无法确定归属时询问一句"这是生图还是生视频的 Key？"。
2. 写入 Key 文件对应的 `NAME=<key>` 行（目录/文件不存在则创建；已有该行则整行替换），编码固定 **UTF-8 无 BOM**（PowerShell 用 `[System.IO.File]::WriteAllText` 配合 `New-Object System.Text.UTF8Encoding $false`；`Out-File`/`Set-Content` 的默认编码或 BOM 会让 `^NAME=` 行匹配失败、Key 被误判为未配置）。权限规则分平台：macOS/Linux 执行 `chmod 600`；**Windows 不要修改 ACL**——`%USERPROFILE%` 下默认已仅限当前用户，错误的 ACL 收紧会导致后续读取被拒、Key 被误判为未配置。写入时用编程方式写文件，不要让 Key 出现在 shell 命令行参数里。
3. **写入后立即读回校验**：能重新读出该行且值一致，才允许报告"已保存"；读回失败视为保存失败，先修复再继续。
4. 回复只确认已保存并显示前 6 位掩码（如 `sk-abc***`），**绝不回显完整 Key**。
5. 提醒用户：对话记录里留有这条 Key，若客户端支持建议删除该消息；日后怀疑泄露，去对应控制台删除并重建，再发新 Key 给我覆盖即可。

**模型 ID 不需要询问**：生视频默认使用 `doubao-seedance-2-0-260128`，skill 会自动采用；仅当用户主动提供其他 Model ID 时才保存为 Key 文件的 `ARK_VIDEO_MODEL=<id>` 行（非秘密，可正常显示确认），同样读回校验。

用户回复"跳过" → 直接进入第 4 步。已是 `set` 的 Key 只说"已检测到"，不验证值、不调用收费 API。

获取凭据的官方入口：

- APINebula：`https://apinebula.com/`
- 火山方舟控制台：`https://console.volcengine.com/ark/region:cn-beijing/apiKey`
- 火山方舟视频 API 文档：`https://console.volcengine.com/ark/region:cn-beijing/docs/82379/1520757?lang=zh`

校验门：两个 Key 均为 `set`，或已向用户发出上述询问并收到明确回答（已保存 / 跳过）；除写入 Key 文件外未回显或外传任何秘密。

## 第 4 步：自验证与交付

只做离线验证，不发起收费请求：

1. 确认两个 `SKILL.md` 都能读取，frontmatter 名称正确。
2. 确认两个 `agents/openai.yaml` 都能解析，且 UI 元数据完整。
3. 确认两个 `references/api.md` 都存在。
4. 告诉用户从下一轮对话开始，可以直接说“生成一张……”或“生成一个视频……”，Codex 会触发对应 skill。

最终报告必须包含：安装目录、两个 skill 的安装结果、两个 Key 的最终状态（`已检测到` / `本次已保存` / `用户选择跳过`）、Key 配置引导是否已完成，以及"未执行任何收费 API"。不得包含任何 Key 内容（掩码除外）。

## 排障速查

- GitHub Raw 无法访问：先切换到第 1 步列出的 jsDelivr 备用源；仍失败再检查网络或代理。只重试缺失文件；除这两个源外不要改用其他镜像。
- 目标目录无写权限：请求用户批准 Codex 写入该目录；不要改装到当前项目来绕过权限。
- 现有 skill 冲突：保持原文件不变，等待用户明确选择是否备份替换。
- Windows 中文乱码或哈希反复不匹配：几乎都是 `Out-File`/`Set-Content` 重编码或 BOM 造成——下载改为二进制落盘、写文件改为 UTF-8 无 BOM 后重试。skill 正文里已有「Windows PowerShell 编码规范」章节，使用阶段照做即可。
- YAML 校验失败或文件缺失：停止安装并报告具体相对路径；不要安装半成品。
- Key 为 `unset` 且用户选择跳过：skill 已安装仍可正常被发现，首次实际使用时 skill 自身会再次引导配置。
