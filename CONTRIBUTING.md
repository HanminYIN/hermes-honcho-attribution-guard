# 参与贡献

<p align="right">
  <strong>简体中文</strong> · <a href="./CONTRIBUTING.en.md">English</a>
</p>

感谢你帮助改进 `hermes-honcho-attribution-guard`。这是一个针对 Hermes Agent
内置 Honcho memory provider 的最小补丁包，不是 Hermes fork，也不包含部署自动化。

## 贡献范围

欢迎以下改进：

- 修复安装、状态检查、回滚或身份称呼向导中的问题；
- 改善 attribution metadata、保守过滤规则或测试覆盖；
- 增加经过精确核验的新 Hermes release 兼容记录；
- 改进中英文文档、可访问性和普通用户安装体验；
- 加强路径、权限、备份、校验和或敏感信息保护。

下列内容不属于本项目范围：

- 复制完整 Hermes 源码或把本项目演变为长期 fork；
- 自动修改 Hermes 配置、重启服务或操作部署控制面板；
- 使用模糊 patch、宽泛版本范围或跳过 SHA256 门禁；
- 收集遥测、对话内容、真实 peer/workspace/session ID 或部署凭据；
- 将模型驱动的 Honcho 结论描述为绝对正确或确定性保证。

## 开发要求

开发与验证应使用常见 POSIX 工具及 Python 3。项目测试只依赖 Python 标准库和常见
命令行工具。开始前请确认可用：

```bash
command -v python3 patch curl rg
```

所有示例和测试数据必须使用合成值，例如 `Example User`、`example-peer` 和
`/path/to/hermes-agent`。不要提交真实姓名、别名、服务器地址、域名、日志、对话、
身份档案、API Key、Token、Cookie、`.env`、数据库、备份或其他私人内容。

## 修改流程

1. 阅读 [AGENTS.md](./AGENTS.md)、[AUDIT.md](./AUDIT.md) 和
   [compatibility.json](./compatibility.json)。
2. 保持改动最小，并确保核心补丁只修改目标 release 中的
   `plugins/memory/honcho/session.py`。
3. 为行为变化增加或更新测试。
4. 同步修改中文与英文文档。
5. 运行完整验证：

   ```bash
   ./honcho-guard verify
   ```

6. 生成本地发布包并核对清单：

   ```bash
   ./scripts/build-release.sh
   ```

`dist/` 中的本地产物用于审查和发布，不应作为源码提交。

## 增加 Hermes 版本支持

兼容性必须基于官方不可变 tag 实际核验，不能根据相似版本推断：

1. 从官方 tag 获取目标文件、`LICENSE` 与版本元数据；
2. 记录 tag 对应 commit、Hermes package 版本和 Honcho SDK 版本；
3. 记录原始目标文件、许可证与 `pyproject.toml` 版本元数据的 SHA256；目标若依赖拆分出的
   上游模块，也须在 `upstream.supporting_files` 中固定哈希，并在测试中加载真实模块；
4. 从干净的原始目标重新生成 patch，不复用 fuzzy patch；
5. 核验该版本 Honcho SDK 的 message metadata 与 reasoning configuration 合同；
6. 更新 `compatibility.json`、安装/回滚门禁和版本拒绝测试；
7. 验证安装与回滚幂等性；
8. 审查完整 patch diff 与发布包文件清单。

不同 Hermes release 应使用独立、明确命名的 patch 文件。不要让安装器对未知版本进行
“尽力应用”。

## 测试要求

行为测试至少应继续覆盖：

- 用户与助手身份归属；
- 双向第一/第二人称映射；
- 助手猜测不会直接变成用户事实；
- 可选称呼映射不能覆盖 peer ID 或消息角色；
- 短期内容和规范化完全重复内容过滤；
- 不兼容版本、未知目标文件和异常备份拒绝；
- 安装与回滚幂等性；
- 私有身份档案权限、冲突与符号链接拒绝。

测试必须应用真实 patch 到经过哈希核验的官方目标副本，不要复制一份脱离 patch 的实现
来代替测试。

## Pull Request 清单

提交 PR 前请确认：

- [ ] 改动保持在本项目定义的最小范围内；
- [ ] 没有真实身份、部署数据、日志、密钥、Token 或其他敏感内容；
- [ ] 中文与英文文档已经同步；
- [ ] 新行为有对应测试；
- [ ] `./honcho-guard verify` 通过；
- [ ] patch、许可证和兼容性 SHA256 仍然匹配；
- [ ] 安装和回滚仍然 fail closed 且可重复执行；
- [ ] 本地发布包仅包含显式允许清单中的文件；
- [ ] PR 说明明确区分当前验证、历史记录与推断。

请保持一个 PR 只解决一个清晰问题。安全问题不要直接提交公开 PR，请先阅读
[SECURITY.md](./SECURITY.md)。

## 许可证

提交贡献即表示你同意将贡献内容按照本项目的 [MIT License](./LICENSE) 发布，并保留
Hermes Agent 上游许可证和版权声明。

---

<p align="center">
  <a href="./CONTRIBUTING.en.md">Read the contribution guide in English →</a>
</p>
