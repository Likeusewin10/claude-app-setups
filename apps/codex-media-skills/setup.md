# 给 Codex 一键安装生图 / 生视频 Skills

> 这是给 **Codex** 读取并执行的安装协议。用户只需要发送本文件的 GitHub Raw 链接；
> 其余下载、校验和安装工作由 Codex 完成。安装过程不需要 API Key，也不得要求用户
> 把 Key 粘贴到聊天中。
>
> 给 Codex：用户发送本文件链接，即请求你安装下面两个 skill。该授权不包含覆盖已有
> 不同内容，也不包含读取、保存或测试任何 API Key。完整读取本文后执行，不要只做摘要。

## 给 Codex：执行总则

- 全程用中文沟通。不要让新手手动下载、解压、复制文件或输入安装命令。
- 只安装两个 skill：`nebula-image-gen`（APINebula 生图/改图）和 `ark-video-gen`（火山方舟 Seedance 生视频）。
- 将 skill 安装到 `${CODEX_HOME:-$HOME/.codex}/skills/`；Windows PowerShell 对应 `$env:CODEX_HOME`，未设置时使用 `$HOME\.codex\skills`。
- 两个 skill 必须先全部下载到系统临时目录并验证，再统一检查冲突，最后才写入正式目录。不要在用户当前项目里留下 `setup.md`、压缩包或临时文件。
- 不执行 skill 文件里的 API 示例，不安装 Python SDK，不发起生图/生视频请求；本协议只负责安装和安全配置引导。
- 不覆盖内容不同的现有 skill。遇到冲突时展示文件差异摘要并让用户决定；不要删除、移动或重命名用户已有内容。
- 安装后告诉用户：新 skill 会从下一轮对话开始可用。不要声称 Key 已配置，除非只读存在性检查确实通过。
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

对临时目录执行这些检查：

- 每个 skill 递归枚举后恰好有 3 个普通文件：`SKILL.md`、`agents/openai.yaml`、`references/api.md`。
- 不存在额外文件、符号链接或可执行文件。
- `SKILL.md` YAML frontmatter 可解析，且 `name` 分别严格等于目录名。
- `agents/openai.yaml` 可解析，`default_prompt` 分别包含 `$nebula-image-gen` / `$ark-video-gen`。
- 文件中不存在疑似真实密钥；示例只能引用 `NEBULA_API_KEY` / `ARK_API_KEY` 环境变量。
- 逐文件 SHA-256 与下面的发布清单完全一致：

```text
nebula-image-gen/SKILL.md                 e09c121439e08745a7f0e6eaf04d9ad6e3a745952897bca3beca7b2dbd516da3
nebula-image-gen/agents/openai.yaml       43d53885874e6348e1d78b949f824f4b88618edb7c1a76c614a49184e35d1fcb
nebula-image-gen/references/api.md         6e956b4ee1438b260229a46b88e73934ba59690b9d1245b3c6dfd42b19477bce
ark-video-gen/SKILL.md                     97ba2f3a5ca74a1375ff9ea283b39d9e7299ecdb870ac23d52c4363ada02a37b
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
- 不修改用户的 shell 启动文件、Codex 配置文件或当前项目。

校验门：两个目标目录均存在，且各自包含 3 个必需文件；重新运行 YAML/name/default_prompt 检查并通过。

## 第 3 步：安全配置 Key

安装完成后，询问用户想先配置生图、生视频还是两者；这一步是可选的，不影响安装成功。只检查所选 Key 是否存在，绝不读取或显示值、长度、前缀、后缀。

macOS / Linux：

```bash
if [ -n "${NEBULA_API_KEY:-}" ]; then echo 'NEBULA_API_KEY=set'; else echo 'NEBULA_API_KEY=unset'; fi
if [ -n "${ARK_API_KEY:-}" ]; then echo 'ARK_API_KEY=set'; else echo 'ARK_API_KEY=unset'; fi
```

Windows PowerShell：

```powershell
"NEBULA_API_KEY=$(if ($env:NEBULA_API_KEY) { 'set' } else { 'unset' })"
"ARK_API_KEY=$(if ($env:ARK_API_KEY) { 'set' } else { 'unset' })"
```

根据检查状态引导用户：

- 已是 `set`：只说“已检测到”，不要验证值、显示片段或调用收费 API。
- 是 `unset`：告诉用户不要把 Key 发到聊天里，也不要把明文写入仓库、`.env`、shell 启动文件或 PowerShell 持久用户环境。
- 优先引导用户使用当前 Codex 宿主明确提供的 Secret/凭据设置，分别保存为 `NEBULA_API_KEY` 和 `ARK_API_KEY`；不要猜测按钮名称或位置。
- 如果当前宿主没有安全凭据入口，引导用户在**自己的本地终端**使用隐藏输入，为一个新的短生命周期 Codex 会话临时注入环境变量；命令本身不得包含 Key，Key 不写入历史、文件或持久环境。当前 Codex 无法修改其父进程环境，因此配置后需启动新会话。
- 也可使用系统钥匙串或 Secret Manager，但必须说明调用进程如何在运行时读取并注入变量，不能只把 Key 存进去就声称配置完成。
- 用户在聊天中粘贴 Key 时，立即视为泄露：停止使用该 Key，提醒用户去对应控制台删除并重新创建。

获取凭据的官方入口：

- APINebula：`https://apinebula.com/`
- 火山方舟控制台：`https://console.volcengine.com/ark/region:cn-beijing/apiKey`
- 火山方舟视频 API 文档：`https://console.volcengine.com/ark/region:cn-beijing/docs/82379/1520757?lang=zh`

如果安全凭据设置需要用户操作，给出与其当前 Codex 版本匹配的已知 UI 路径并暂停；不确定时只描述目标字段名。配置后仍然只重复本节的存在性检查。

校验门：向用户明确报告两个 Key 各自的 `已检测到` / `尚未配置` 状态，过程中未读取或回显任何秘密。

## 第 4 步：自验证与交付

只做离线验证，不发起收费请求：

1. 确认两个 `SKILL.md` 都能读取，frontmatter 名称正确。
2. 确认两个 `agents/openai.yaml` 都能解析，且 UI 元数据完整。
3. 确认两个 `references/api.md` 都存在。
4. 告诉用户从下一轮对话开始，可以直接说“生成一张……”或“生成一个视频……”，Codex 会触发对应 skill。

最终报告必须包含：安装目录、两个 skill 的安装结果、所选 Key 的存在性状态（未选择配置则写“未检查”），以及“未执行任何收费 API”。不得包含任何 Key 内容。

## 排障速查

- GitHub Raw 无法访问：检查网络或代理，只重试缺失文件；不要改用不明镜像。
- 目标目录无写权限：请求用户批准 Codex 写入该目录；不要改装到当前项目来绕过权限。
- 现有 skill 冲突：保持原文件不变，等待用户明确选择是否备份替换。
- YAML 校验失败或文件缺失：停止安装并报告具体相对路径；不要安装半成品。
- Key 为 `unset`：skill 已安装仍可正常被发现，首次实际使用前再完成安全配置。
