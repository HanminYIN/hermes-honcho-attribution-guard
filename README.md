<p align="right">
  <strong>简体中文</strong> · <a href="./README.en.md">English</a>
</p>

<p align="center">
  <img src="./assets/readme-hero.svg" alt="Hermes Honcho Attribution Guard：让记忆知道，是谁说的" width="100%">
</p>

<p align="center">
  <a href="#它解决什么问题">解决的问题</a> ·
  <a href="#三步安装">三步安装</a> ·
  <a href="#身份称呼向导">称呼向导</a> ·
  <a href="#兼容范围">兼容范围</a> ·
  <a href="#安全回滚">安全回滚</a> ·
  <a href="./RELEASE_NOTES.md">更新说明</a> ·
  <a href="./CONTRIBUTING.md">参与贡献</a> ·
  <a href="./SECURITY.md">安全策略</a>
</p>

<p align="center">
  <code>v0.2.0</code>　<code>Hermes v2026.8.19</code>　<code>MIT</code>
</p>

`hermes-honcho-attribution-guard` 是一个面向 Hermes Agent 内置 Honcho memory
provider 的小型、可验证、可回滚补丁工具。它为每条用户与助手消息补充明确的身份
归属信息，降低 Honcho 在提取长期记忆时混淆“谁说了什么”的风险。

它不是新的 memory provider，也不是 Hermes fork。补丁只修改
`plugins/memory/honcho/session.py`，不会改写原始对话，不会修改 Hermes 配置，也不会
自动重启任何服务。

> [!IMPORTANT]
> 本版本只支持 Hermes `v2026.8.19`（Python package `0.20.5`）。安装器会同时核验
> 版本、目标文件 SHA256 与补丁 SHA256；任一项不匹配都会保持原文件不变并安全退出。

## 它解决什么问题

| 常见问题 | 本补丁如何处理 |
| --- | --- |
| “我”和“你”被归到错误的人 | 写入 speaker、addressee、消息角色及第一/第二人称映射 |
| 助手的猜测被沉淀为用户事实 | 标记助手来源与未确认状态，并加入 Honcho 推理约束 |
| 昵称、英文名或第三人称自称无法对应 peer | 可选称呼档案将多个自然语言称呼映射到稳定 peer ID |
| “准备睡觉”“稍后回来”等短期状态进入长期记忆 | 检索时保守过滤少量明确的中英文短期表达 |
| summary、representation 或 peer card 出现重复内容 | 检索时去除规范化后的完全重复项 |

稳定 peer ID 与消息角色始终具有最高优先级。称呼只是帮助理解内容的 metadata 提示，
不能覆盖真实作者，也不参与判断“我”和“你”。

## 工作方式

| 阶段 | 作用 |
| --- | --- |
| 消息写入 | 附加 attribution v2 结构化 metadata，不改写消息正文 |
| 身份理解 | 使用运行时 peer ID、角色、speaker/addressee 和人称映射 |
| 可选称呼 | 将用户或助手的多个称呼映射到对应 peer，冲突时拒绝使用 |
| Honcho 推理 | 要求未确认的助手猜测不得直接转成用户事实 |
| 记忆检索 | 保守过滤明确短期状态与规范化后的完全重复内容 |

## 三步安装

### 1. 下载并校验

从 [GitHub Releases](../../releases) 下载这两个文件：

- `hermes-honcho-attribution-guard-v0.2.0.tar.gz`
- `SHA256SUMS`

macOS：

```bash
shasum -a 256 -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.2.0.tar.gz
cd hermes-honcho-attribution-guard-v0.2.0
shasum -a 256 -c MANIFEST.sha256
```

Linux：

```bash
sha256sum -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.2.0.tar.gz
cd hermes-honcho-attribution-guard-v0.2.0
sha256sum -c MANIFEST.sha256
```

### 2. 运行设置向导

```bash
./honcho-guard setup
```

向导会查找或询问 Hermes checkout 路径、显示兼容状态、在确认后安装补丁，并询问是否
配置可选身份称呼。普通用户不需要直接操作 patch 文件。

安装器优先使用 POSIX `patch`；环境未提供该命令但有 `git` 时，会先执行
`git apply --check` 再应用，并继续核验精确的补丁后 SHA256。

### 3. 使用原有方式重启 Hermes

安装完成后，使用当前部署原有的服务管理方式重启 Hermes，使 Python 进程加载新代码。
本工具不会猜测你的部署方式，也不会操作 systemd、Docker、1Panel 或其他控制面板。

> [!TIP]
> 不确定补丁是否已安装时，运行 `./honcho-guard status`。它只读取版本、目标文件、备份
> 与身份档案状态，不会修改 Hermes。

更简短的中文操作说明见 [QUICKSTART.zh-CN.md](./QUICKSTART.zh-CN.md)。

## 身份称呼向导

称呼档案用于帮助 Honcho 理解稳定 peer ID 与对话中不同名字之间的关系。例如，一个
用户可以同时填写常用名、昵称、英文名、网名或第三人称自称；助手称呼保存在另一组。

向导会依次确认：

1. 是否启用可选称呼；
2. 当前 Hermes 是否为单用户实例；
3. 是否接受隐私提示；
4. 用户主要称呼与其他称呼；
5. 助手主要称呼与其他称呼；
6. 是否保存预览中的内容。

```bash
./honcho-guard identity show     # 查看
./honcho-guard identity edit     # 修改
./honcho-guard identity clear    # 清除
```

> [!WARNING]
> `v0.2.0` 的称呼档案仅适用于单用户 Hermes 实例。多用户网关应跳过此步骤；核心
> attribution 功能不依赖称呼档案，跳过后仍然可用。

身份档案保存在目标 Hermes checkout 的
`.hermes-honcho-attribution-guard/identity.json`，文件权限为 `0600`，目录权限为
`0700`。档案文件不会进入补丁仓库、Release 包或日志。为了让 Honcho 使用映射，称呼
值会作为结构化消息 metadata 发送到用户已经配置的 Honcho 后端；向导会在采集前明确
告知并默认跳过。

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `./honcho-guard setup` | 交互式检查、安装与可选称呼设置 |
| `./honcho-guard status` | 查看版本、补丁、备份和称呼档案状态 |
| `./honcho-guard install /path/to/hermes-agent` | 非交互安装 |
| `./honcho-guard rollback /path/to/hermes-agent` | 从已验证备份回滚 |
| `./honcho-guard identity show` | 查看当前称呼档案 |
| `./honcho-guard verify` | 维护者完整来源与测试验证 |
| `./honcho-guard version` | 显示补丁包与目标 Hermes 版本 |

也可以设置 `HAG_HERMES_ROOT=/path/to/hermes-agent`，省略命令后的路径。

## 兼容范围

兼容性采用精确版本与 SHA256，不使用模糊版本范围：

| 项目 | 要求 |
| --- | --- |
| Hermes release | `v2026.8.19` |
| `hermes-agent` Python package | `0.20.5` |
| 上游 commit | `fcbd1076a93841fa88855acce810e342a5b78101` |
| Honcho SDK | `honcho-ai==2.2.0` |
| 目标文件 | `plugins/memory/honcho/session.py` |
| 原始文件 SHA256 | `0feada7c6db22376d5dea5bcf9afc9573612f791892294288495d979a1afa7d4` |
| 补丁后 SHA256 | `fdb1f7ee13b48aa0b2fb6ea187984801e256a046b8811a3a4e7b05f535795762` |

机器可读的完整记录位于 [compatibility.json](./compatibility.json)。

## 安全回滚

安装前，工具会把精确匹配的原始目标文件保存在：

```text
HERMES_ROOT/.hermes-honcho-attribution-guard/backups/v2026.8.19/plugins/memory/honcho/session.py
```

需要撤销时运行：

```bash
./honcho-guard rollback
```

回滚同时要求当前目标为已知补丁 SHA256、备份为已知原始 SHA256。遇到未知本地修改、
异常备份或符号链接时会拒绝覆盖。重复安装与重复回滚均为经过校验的安全 no-op。

## 已知边界

- attribution metadata、版本检查、备份与检索过滤是确定性的。
- Honcho 服务端结论生成仍然由模型驱动；推理约束可以降低误归属风险，但不能证明每条
  派生结论都绝对正确。
- 当前重复过滤只处理规范化后的完全重复内容，不宣称语义级去重。
- 补丁不会自动迁移或清理既有 Honcho 结论；部署后应使用新会话审查新生成的记忆。

详细证据边界见 [AUDIT.md](./AUDIT.md)。

<details>
<summary><strong>维护者：验证与构建 Release</strong></summary>

完整验证会从官方不可变 tag 下载目标源文件、`LICENSE` 与 `pyproject.toml`，核验版本和
SHA256，在临时副本应用补丁、编译、运行测试并执行敏感信息扫描：

```bash
./honcho-guard verify
```

遇到 GitHub Raw 限流时，维护者也可设置 `HERMES_UPSTREAM_ROOT` 指向已经检出精确
标签的只读上游 checkout；相同的目标、许可证、版本和 SDK 哈希门禁仍会执行。

同一验证会在 GitHub Actions 中对推送到 `main`、Pull Request 和手动触发运行。CI
只有仓库内容读取权限，不持有发布或部署权限；外部 Action 固定到完整 commit SHA。

生成本地发布资产：

```bash
./scripts/build-release.sh
```

产物位于 `dist/`。构建器只复制显式允许清单内的文件，并生成外层 `SHA256SUMS` 与包内
`MANIFEST.sha256`；相同源文件会生成相同的压缩包 SHA256。

</details>

## 上游与许可证

本补丁面向 [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
release [`v2026.8.19`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.19)。
Hermes Agent 采用 MIT License；上游许可证和版权声明已原样保留在 [LICENSE](./LICENSE)。

---

<p align="center">
  <a href="./README.en.md">Read this page in English →</a>
</p>
