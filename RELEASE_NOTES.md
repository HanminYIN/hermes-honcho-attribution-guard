# hermes-honcho-attribution-guard v0.4.0

<p align="right">
  <strong>简体中文</strong> · <a href="./RELEASE_NOTES.en.md">English</a>
</p>

> Safer identity attribution for Hermes Agent's built-in Honcho memory provider.

## v0.4.0 更新

- 重新基于官方 Hermes `v2026.9.7` / `hermes-agent 0.21.1` 的干净标签源码生成补丁；
- 适配上游 session 模块拆分：通过调用原有检索方法并过滤返回的派生记忆，继续保留
  身份归属、临时记忆过滤和完全重复项过滤；补丁仍只修改 `session.py`；
- 固定并核验四个上游辅助模块的 SHA256；状态、安装和回滚均拒绝缺失、修改或符号链接；
- 使用真实上游模块补测普通检索、当前查询模式、认证失败传播及原始消息保留，继续验证
  安装/回滚幂等和旧版 `0.21.0` 拒绝；
- 保持 `honcho-ai==2.2.0` 的消息级 metadata 与推理配置契约；
- 安装器继续在没有 POSIX `patch` 时使用经过 `--check` 的 `git apply` 回退，最终产物仍需
  精确匹配记录的补丁后 SHA256；
- 保留版本拒绝、未知修改拒绝、备份校验、安装/回滚幂等和隐私扫描门禁。

## 简介

`hermes-honcho-attribution-guard` 是一个面向 Hermes Agent 内置 Honcho memory
provider 的小型补丁工具。它解决的核心问题是：当 Honcho 从用户与助手的对话中
提取长期记忆时，如果消息缺少足够明确的身份归属信息，就可能混淆“谁说了什么”。

这种混淆通常表现为：

- 把助手消息里的“我”错误归到用户，或把用户消息里的“你”错误归到用户自己；
- 把助手对用户的猜测、建议或角色扮演内容沉淀成已经确认的用户事实；
- 把“准备睡觉”“稍后回来”等一次性状态保留为长期记忆；
- 在 summary、representation 或 peer card 中反复出现相同内容，增加记忆噪声。

本补丁为每条用户和助手消息增加 attribution v2 元数据，明确记录 speaker、
addressee、消息角色以及第一/第二人称映射；同时向 Honcho 提供更严格的推理规则，
要求未被用户确认的助手猜测不得转化为用户事实。检索记忆时，还会保守地过滤明确
的短期状态和规范化后的完全重复内容。

可选设置向导还允许用户把昵称、英文名、网名或第三人称自称映射到稳定 user peer，
并把助手称呼维护在独立的 assistant peer 列表中。称呼只作为结构化 metadata 提示；
peer ID、消息作者与第一/第二人称映射始终具有更高优先级。

它不会删除或改写原始对话消息，也不是一个新的 memory provider，更不是 Hermes
的 fork。补丁仅修改 Hermes 自带的 `plugins/memory/honcho/session.py`。

## 安装与回滚

本 Release 提供两个下载文件：

- `hermes-honcho-attribution-guard-v0.4.0.tar.gz`：完整补丁工具包；
- `SHA256SUMS`：压缩包校验和。

下载后先校验并解压；压缩包内的 `MANIFEST.sha256` 可以继续核验每一个文件：

```bash
shasum -a 256 -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.4.0.tar.gz
cd hermes-honcho-attribution-guard-v0.4.0
shasum -a 256 -c MANIFEST.sha256
```

Linux 用户可以使用 `sha256sum -c`。校验通过后，普通用户只需要运行统一入口：

```bash
./honcho-guard setup
```

需要撤销时运行：

```bash
./honcho-guard rollback
```

安装器会在写入前核验 Hermes 版本、目标文件 SHA256 和补丁 SHA256，并先保存可验证
的原始文件备份。打补丁时优先使用 POSIX `patch`，缺失时回退到 `git apply`。遇到
不兼容版本、未知本地修改、异常备份或符号链接时会安全退出。
安装和回滚均可重复执行。

本工具不会修改 Hermes 配置，也不会自动重启服务、容器或控制面板。安装或回滚后，
请使用部署环境原有的服务管理方式重启 Hermes。

身份称呼为可选项，默认不采集。用户主动填写后，只保存在目标 Hermes checkout 的
`0600` 私有文件中，可通过 `identity show / edit / clear` 管理。为了让 Honcho 使用
映射，称呼值会作为结构化消息 metadata 发送到用户已配置的 Honcho 后端；向导会在
采集前明确告知并再次取得同意。

`v0.4.0` 的可选称呼档案仅面向单用户 Hermes 实例；多用户网关应跳过称呼配置，
继续使用不依赖别名的核心 attribution 功能。

## 兼容范围

- Hermes release：`v2026.9.7`
- `hermes-agent`：`0.21.1`
- Honcho SDK：`honcho-ai==2.2.0`
- 补丁包版本：`0.4.0`

兼容范围采用精确版本与 SHA256 校验，不会对相似版本模糊应用补丁。

## 已知边界

身份元数据、版本检查、备份和检索过滤是确定性的；Honcho 服务端的结论生成仍然是
模型驱动的。推理规则可以显著降低错误归属风险，但不能保证每条服务端派生结论都
绝对正确。本版本的重复过滤也仅处理规范化后的完全重复内容，不宣称完成语义级去重。

建议部署后通过新的测试会话审查实际生成的 conclusions，再判断是否满足具体使用
场景的要求。

---

<p align="center">
  <a href="./RELEASE_NOTES.en.md">Read the release notes in English →</a>
</p>
