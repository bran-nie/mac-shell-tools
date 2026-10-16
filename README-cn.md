# mac-shell-tools

[English](README.md)

面向 macOS 和 Linux 的轻量 Zsh 工具管理器。先安装 **mst**，再选择需要的工具。

需要 Zsh 和系统基础命令，在线同步还需要 curl 和 tar；Linux 使用 GNU Coreutils 或兼容命令。共享入口会复用已有补全系统（包括 Oh My Zsh），交互式 Zsh 尚未初始化补全时自动初始化。管理器安装到用户配置目录，无需 `sudo`。参见 [Ubuntu 24.04 依赖准备](docs/installation-cn.md#支持的系统与-zsh)。

## 安装 mst

推荐从 GitHub 安装管理器：

```sh
mac_shell_tools_installer="$(curl -fsSL "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh")" &&
  sh -c "$mac_shell_tools_installer"
```

轻量引导会下载一份源码快照，安装 **mst** 并同步普通工具脚本到本地仓库，**不会启用工具**。在交互终端中，成功变更后会在当前窗口启动新的 Zsh 登录会话，随即可以使用 `mst`。退出后可能回到原会话。

随后可在任意目录查看并选择工具：

```sh
mst list
mst install dsize
```

需要全部工具时，执行 `mst install --all`。后续无需保留仓库或安装脚本。

## 管理工具

| 命令 | 行为 |
| --- | --- |
| `mst list` | 离线查看工具、安装状态、已安装和可用版本 |
| `mst install dsize` | 从本地仓库安装或重新安装指定工具 |
| `mst install --all` | 从本地仓库安装全部可用工具 |
| `mst update` | 同步最新脚本，再更新已安装工具 |
| `mst update dsize` | 更新指定的已安装工具 |
| `mst upgrade` | 升级 mst 并同步工具脚本，保留已安装工具 |
| `mst uninstall dsize` | 卸载指定工具，删除前备份 |
| `mst uninstall --all` | 卸载全部已登记工具，保留 mst |
| `mst config language` | 查看保存的语言，默认英文 |
| `mst config language list` | 列出支持的语言，标记当前生效的语言 |
| `mst config language en` | 将 mst 和工具的语言保存为英文 |
| `mst config language zh-CN` | 将 mst 和工具的语言保存为简体中文 |
| `mst --help` | 查看命令和参数 |

`upgrade` 和 `update` 从 GitHub `main` 同步源码快照。普通工具的 `install`、`list` 和 `uninstall` 离线可用；声明了额外在线资源的工具在安装时联网下载并校验资源。项目发布新工具后，执行 `mst upgrade`，再通过 `mst list` 查看、`mst install <工具名>` 选择安装。`upgrade` 和 `update` 不会安装新工具，也不会重新安装已卸载的工具。

工具命令支持同时传入多个名称。`install` 不带名称时表示全部可用工具，`update` 不带名称时表示全部已安装工具。`--all` 不能与工具名混用。

交互终端中有变更时会启动新的 Zsh 登录会话。使用 `--no-run-zsh`、`--unattended` 或 `RUNZSH=no` 可关闭自动启动；查询、内容不变、管道输入和输出重定向也会跳过。需要手动启用时，在 Zsh 中按打印的命令操作；当前使用 Bash 时先执行 `zsh -l`。卸载后启动全新的 Zsh 或执行 `exec zsh -l`，清除已加载的函数。新会话会重新读取配置，原会话中未导出的变量和函数不会带入。

## 工具

| 工具 | 简介 | 文档 |
| --- | --- | --- |
| `dsize` | 查看指定目录的磁盘占用排行（默认最多 25 条），支持目录 Tab 补全 | [使用说明](docs/tools/dsize/README-cn.md) |
| `portwho` | 查询一个或多个 TCP 端口的监听程序、PID、用户及地址 | [使用说明](docs/tools/portwho/README-cn.md) |
| `extract` | 将 ZIP 和常见 TAR 压缩包解压到新目录，支持预览和 Tab 补全 | [使用说明](docs/tools/extract/README-cn.md) |
| `npmg` | 在共享目录中安装、更新、卸载和查看 npm 全局包，需要 Node 和 npm | [使用说明](docs/tools/npmg/README-cn.md) |
| `aliases` | 加载常用别名及个人 Zsh 文件，支持查看来源和当前终端重载 | [使用说明](docs/tools/aliases/README-cn.md) |

## 配置

默认安装根目录是 `~/.config/zsh/mac-shell-tools/`：

```text
~/.config/zsh/mac-shell-tools/
├── init.zsh              # 集中入口，由 .zshrc 引用
├── manager/              # mst、管理器版本和语言包
├── repository/           # 已同步的清单及全部工具脚本，不会自动加载
├── tools/
│   ├── installed.list    # 已安装工具及版本清单
│   ├── dsize/            # 每个工具独立存放源码、版本和语言包
│   ├── portwho/          # 只出现已选择安装的工具
│   ├── extract/
│   ├── npmg/
│   └── aliases/
├── config.conf           # 保存的偏好，设置时创建
├── npmg.conf             # 可选的 npmg prefix 配置，卸载后保留
├── aliases.conf          # 可选的个人 Zsh 文件路径，卸载后保留
└── backups/              # 修改或删除文件前的备份
```

`mst` 是 Zsh 函数，无需修改 PATH。首次安装前，可将 `XDG_CONFIG_HOME` 和 `ZDOTDIR` 设为绝对路径来自定义位置；已安装的管理命令会记住原路径。

已安装在 `~/.config/zsh/tools` 的用户通过 `mst upgrade` 迁移。工具内容保持不变，没有版本记录的工具先显示 `unknown`，更新工具后再记录实际版本。个人文件及旧备份保留在原位置，详见[安装与恢复说明](docs/installation-cn.md)。

本地安装可在仓库中执行 `sh install.sh`。`curl ... | sh` 也能安装 mst，但需要手动启用。

## 语言与版本

输出默认使用英文。保存语言后，mst 和工具的帮助、错误及补全说明会在下一次调用时生效，无需重开终端：

```sh
mst config language zh-CN   # 保存为简体中文
mst config language en      # 保存为英文
mst config language         # 查看保存的语言
mst config language list    # 列出语言，* 表示当前生效的语言
mst --lang zh-CN list        # 仅本次命令使用中文
mst --version
dsize --version
```

`mst config language list` 展示 `en`（English）和 `zh-CN`（简体中文），不会修改配置。`*` 标记遵循 `--lang` → `MST_LANG` → 保存的偏好 → 英文的优先级。`mst config language` 及其参数支持 Tab 补全。

项目使用 `主版本.次版本.修订号`，发布标签为 `vX.Y.Z`；每个工具独立维护版本，开发版本包含 `-dev` 和该工具自身的源码摘要。新增工具、修改管理器或文档不改变其他工具的可用版本；共享运行依赖变化会更新受影响的工具版本。`mst upgrade` 保留已安装版本，`mst update` 更新已安装工具，详见[版本与发布](docs/development.md#版本与发布)。

## 开发与验证

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

检查使用临时 HOME、配置目录和模拟下载，包括伪终端中的真实 Tab 补全及登录会话验证。PR/main 按变更范围在 macOS 上运行，手动、发布及每周全量检查同时覆盖 macOS 和 Ubuntu；可用 `sh scripts/check.sh --tool npmg` 验证单个工具，报告保存在 `.artifacts/`。详见[维护说明](docs/development.md)。

## 许可证

[MIT](LICENSE) © 2026 bran.nie。
