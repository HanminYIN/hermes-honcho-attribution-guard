# 安全策略

<p align="right">
  <strong>简体中文</strong> · <a href="./SECURITY.en.md">English</a>
</p>

`hermes-honcho-attribution-guard` 会修改 Hermes checkout 中的一个 Python 文件，
并可选保存身份称呼档案。安全报告应优先保护报告者、部署环境和用户数据。

## 支持范围

| 补丁包版本 | Hermes release | 安全支持 |
| --- | --- | --- |
| `0.3.0` | `v2026.8.31` / package `0.21.0` | 支持 |
| `0.2.0` | `v2026.8.19` / package `0.20.5` | 支持 |
| `0.1.0` | `v2026.8.3` / package `0.20.0` | 支持 |
| 其他版本 | 其他 Hermes release | 不支持，除非兼容记录明确列出 |

当前版本兼容范围的机器可读来源是 [compatibility.json](./compatibility.json)；旧版本
Release 保留各自的兼容记录。对未知版本强制应用补丁不属于受支持场景。

## 如何私密报告

本仓库已启用 GitHub Private Vulnerability Reporting。请使用
**[私密报告漏洞](https://github.com/HanminYIN/hermes-honcho-attribution-guard/security/advisories/new)**
提交报告；报告内容只对报告者、维护者及维护者邀请的协作者可见。这是首选方式。

如果 GitHub 暂时无法显示私密报告入口：

1. 不要在公开 Issue、Discussion、PR、日志或截图中粘贴漏洞细节或凭据；
2. 可以创建一个不包含技术细节和私人信息的公开 Issue，仅说明需要私密安全联系渠道；
3. 等待维护者提供私密渠道后，再发送完整报告。

请不要向本项目发送真实对话、完整配置、`.env`、API Key、Token、Cookie、数据库、
身份档案、服务器地址、域名、真实 peer/workspace/session ID 或未脱敏日志。使用合成值
和最小复现；如果秘密已经泄露，请先在其签发方撤销或轮换。

## 报告应包含

在不暴露私人数据的前提下，请提供：

- 补丁包版本与精确 Hermes release；
- 操作系统和必要的工具版本；
- 受影响的命令或文件路径；
- 使用合成数据的最小复现步骤；
- 预期结果与实际结果；
- 可能的影响和已知缓解措施；
- 是否已经在其他地方公开披露。

请不要附上整个 Hermes checkout 或线上备份。SHA256、经过净化的最小 diff 和合成测试
夹具通常足以定位问题。

## 适合报告的安全问题

包括但不限于：

- 安装或回滚绕过版本、SHA256、备份或符号链接门禁；
- 路径穿越、意外覆盖目标范围之外文件或不安全临时文件处理；
- 身份档案权限放宽、别名跨 peer 冲突绕过或私人值被写入日志/发布包；
- `MANIFEST.sha256`、`SHA256SUMS` 或发布允许清单被绕过；
- 恶意 patch 或未知本地修改在未确认的情况下被安装；
- 确定性 attribution metadata 与消息真实作者不一致。

以下情况通常不是本项目漏洞：

- Honcho 模型生成了一条质量不佳的结论，但 metadata 与本项目约束均正确传输；
- Hermes、Honcho 服务或 Honcho SDK 本身的独立漏洞；
- 对未列入 `compatibility.json` 的版本强制修改后出现问题；
- 多用户网关启用了明确标注为单用户限定的可选称呼档案。

若问题属于上游 Hermes 或 Honcho，请同时遵循对应上游项目的安全报告流程，不要在本
仓库公开上游零日漏洞细节。

## 处理方式

维护者会尽力确认收到报告、复现问题、评估影响并准备修复。响应与发布日期取决于影响、
复现条件和上游协调，不承诺固定 SLA。修复发布后，安全说明应只包含必要技术细节，且
不得暴露报告者或真实部署信息。

请在维护者确认修复或双方约定的披露日期之前保持报告私密。

---

<p align="center">
  <a href="./SECURITY.en.md">Read the security policy in English →</a>
</p>
