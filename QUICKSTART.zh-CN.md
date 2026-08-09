# 中文快速开始

如果是从 GitHub Release 下载，请同时下载压缩包与 `SHA256SUMS`，先校验再解压：

```bash
shasum -a 256 -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.1.0.tar.gz
cd hermes-honcho-attribution-guard-v0.1.0
shasum -a 256 -c MANIFEST.sha256
```

Linux 用户也可以把 `shasum -a 256 -c` 替换为 `sha256sum -c`。

之后只需要使用设置向导，不必直接操作补丁文件：

```bash
./honcho-guard setup
```

向导会检查 Hermes、确认安装，并询问是否配置可选身份称呼。

## 1. 查看状态

```bash
./honcho-guard status
```

如果当前目录不是 Hermes checkout，命令会提示输入 Hermes 根目录。也可以直接
把路径放在命令后面：

```bash
./honcho-guard status /path/to/hermes-agent
```

重点查看三项输出：

- `Hermes version: compatible`：版本匹配。
- `Target state: ready to install`：可以安装。
- `Backup state: verified`：已有可用回滚备份；第一次安装前显示 `missing`
  属于正常情况。

如果显示 `incompatible`、`unknown` 或 `invalid`，不要手动强行应用补丁。工具会
保持文件不变。

## 2. 一键安装

```bash
./honcho-guard install
```

安装器会自动完成版本和 SHA256 校验、临时打补丁、产物校验、原文件备份和原子
替换。重复执行同一命令是安全的；已安装时只会报告状态，不会重复修改文件。

安装完成后，请使用原有的服务管理方式重启 Hermes，使 Python 进程加载新代码。
本工具不会猜测你的部署方式，也不会自动重启服务、容器或控制面板。

## 3. 可选身份称呼

身份称呼用于帮助 Honcho 理解对话里的不同名字分别对应哪个稳定 peer ID。例如昵称、
英文名、网名和第三人称自称可以同时映射到同一个用户 peer；助手称呼维护在另一组。

它不用于判断“我”和“你”，也不能覆盖消息的真实作者。优先级始终是：peer ID、消息
角色、speaker/addressee 映射，最后才是可选称呼。

`v0.1.0` 的称呼档案仅支持单用户 Hermes 实例。多用户网关请跳过这一步；核心身份
归属补丁不依赖称呼档案，跳过后仍可正常使用。

```bash
./honcho-guard identity show    # 查看
./honcho-guard identity edit    # 修改
./honcho-guard identity clear   # 清除
```

身份档案只保存在目标 Hermes checkout 内，文件权限为 `0600`，不会进入补丁仓库、
Release 包或日志。为了让 Honcho 使用映射，称呼值会作为结构化消息 metadata 发送
到用户已经配置的 Honcho 后端。向导会在采集前明确提示，默认跳过；只有用户主动
同意后才会保存和使用。

## 4. 随时回滚

```bash
./honcho-guard rollback
```

回滚前会验证当前补丁文件和安装时保留的原始备份。遇到未知本地修改时会拒绝
覆盖。重复回滚也是安全的。

回滚完成后，同样需要使用原有方式重启 Hermes。

## 5. 无交互或自动化使用

可以通过环境变量固定 Hermes 路径：

```bash
export HAG_HERMES_ROOT=/path/to/hermes-agent
./honcho-guard status
./honcho-guard install
```

也可以继续直接调用底层脚本：

```bash
./scripts/status.sh /path/to/hermes-agent
./scripts/install.sh /path/to/hermes-agent
./scripts/rollback.sh /path/to/hermes-agent
```

## 6. 其他命令

```bash
./honcho-guard help       # 查看帮助
./honcho-guard version    # 查看补丁包与目标 Hermes 版本
./honcho-guard verify     # 执行完整开发者验证
```

普通安装不需要执行 `verify`；它主要用于维护者审查补丁包和公开上游来源。
