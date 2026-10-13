# npmg

[English](README.md)

使用当前启用的 Node 和 npm，管理共享目录中的全局包，独立于 nvm 的版本目录。默认使用 `$HOME/.local/npm`，也可以保存其他 prefix。

## 安装

```sh
mst upgrade
mst install npmg
```

安装或更新 npmg 前，当前 PATH 中必须有 Node 和 npm。使用 nvm 时先启用一个 Node 版本。缺少依赖时，在写入工具前停止本次选装，多个工具及 `--all` 同样适用。`mst upgrade`、工具列表查询和卸载不要求 Node/npm。

安装 npmg 只离线复制封装工具，实际包操作使用当前 npm 配置，可能访问对应仓库。加载时读取 prefix 配置，将 `{prefix}/bin` 追加到 PATH，不重复添加，保留已有命令优先级。加载不创建目录、不修改 npm 配置。

## 配置 prefix

```sh
npmg config prefix "$HOME/tools/npm"
npmg config prefix
npmg config show
npmg config prefix --reset
```

`config prefix <目录>` 保存目录；相对路径按执行时的工作目录转为绝对路径，也支持加引号的 `~/...`。`config prefix` 输出当前生效目录。`config show` 展示目录、`saved`/`default` 来源、配置文件和 bin 目录。`--reset` 移除保存值，恢复 `$HOME/.local/npm`。

优先级是 **本次 npm `--prefix` > 保存的 prefix > 默认目录**。临时覆盖不改变保存值或 PATH。保存及重置会更新当前终端和后续加载的 PATH，npmg 只移除之前由它添加的目录，保留用户自行配置的目录。修改 prefix 不创建、迁移、复制或删除包目录，旧目录中的包会保留。

设置以纯文本 `npmg.conf` 保存在已安装的共享 `init.zsh` 旁，即使之后改变 `XDG_CONFIG_HOME`，仍使用安装时固定的位置。直接从源码目录加载时使用 `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/npmg.conf`。配置命令不要求 Node/npm，不修改 `.npmrc`，不设置持久的 `NPM_CONFIG_PREFIX`。保存需要系统 mkdir/mktemp/mv/rm 命令，拒绝空路径、冒号及换行，通过同目录私有临时文件写入。配置无效或为链接时，包操作及配置读取报错；`config prefix --reset` 可以修复格式错误，启动加载保持静默。

## 用法

| 命令 | 行为 |
| --- | --- |
| `npmg live-server` | 快捷安装，相当于 `npmg install live-server` |
| `npmg install playwright @larksuite/cli` | 安装一个或多个包 |
| `npmg update live-server` | 更新指定包 |
| `npmg update` | 更新 prefix 中的全部包 |
| `npmg uninstall live-server` | 卸载指定包 |
| `npmg list` | 查看已安装的包，默认 `--depth=0` |

简写：`i` 对应 `install`，`up` 对应 `update`，`rm` 对应 `uninstall`，`ls` 对应 `list`。

所有包操作默认带上 `-g --prefix <当前生效的目录>`。其余参数保留原有顺序及边界，显式 npm 参数可以覆盖默认值：

```sh
npmg live-server@latest --dry-run
npmg live-server --registry=https://registry.npmjs.org
npmg install live-server --prefix "$HOME/other-npm"
npmg list --depth=2 --json
npmg install ./local-package --global=false --prefix ./project
```

自动 PATH 设置覆盖当前保存或默认的 prefix。临时覆盖时，按需自行添加其 `bin` 目录。已有 PATH 中的命令保留优先级，包括当前 nvm 版本目录中已有的同名 CLI。

`npmg`、`npmg --help`、`npmg -h` 显示本工具帮助，`npmg --version`、`npmg -V` 显示已加载的工具版本。子命令后的 `--help`、`--version` 使用 npm 的含义，例如 `npmg install --help`。包名前的选项也走快捷安装。包名与子命令同名时，使用 `npmg install update` 或 `npmg -- update`。

不带参数的 `npmg` 显示帮助。显式执行不带包参数的 `npmg install` 则沿用 npm 行为，将当前包上下文全局安装。更新规则由 npm 决定，需要明确版本或标签时使用 install。

## 运行、资源归属与补全

每次包操作重新检查 Node/npm，保留 npm 输出、错误、标准输入行为和退出码。缺少依赖返回 `1`，mst 语言配置无效返回 `2`，本工具帮助或版本返回 `0`。npmg 的帮助、错误和补全跟随 mst 语言设置，npm 输出保持原样。

本工具不安装或选择 Node。共享包仍需支持当前 Node 版本，原生扩展在切换版本后可能需要重建。参见官方 [npm 目录说明](https://docs.npmjs.com/cli/v11/configuring-npm/folders/)、[更新规则](https://docs.npmjs.com/cli/v11/commands/npm-update/)、[重建说明](https://docs.npmjs.com/cli/v11/commands/npm-rebuild/)及 [nvm prefix 兼容性说明](https://github.com/nvm-sh/nvm#compatibility-issues)。

`mst update npmg` 更新封装工具，`npmg update` 更新 npm 包。`mst uninstall npmg` 保留已保存的配置、共享目录及其中的 npm 包。

Tab 提供子命令、简写及常用选项，`--prefix` 支持目录补全。补全不执行 npm、不查询远程仓库。没有补全提示的 npm 参数仍然可以传递。
