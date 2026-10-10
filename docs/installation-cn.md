# 安装与恢复

[English](installation.md) · [项目 README](../README-cn.md)

## 支持的系统与 Zsh

支持 macOS 和 Linux。mst、工具及补全依赖 Zsh，Oh My Zsh 可选。Linux 需要 GNU Coreutils 或支持相同工具参数的命令（dsize 使用 `du -h -d`、`sort -h`、`tail -n`），在线操作还需要 curl。

Ubuntu 24.04 LTS 缺少依赖时可先执行：

```sh
sudo apt-get update
sudo apt-get install -y zsh curl
```

安装器会在写入管理配置前检查 Zsh 是否可用。可以从 Bash 等其他 Shell 启动 POSIX 安装器；它不会修改默认 Shell 或安装系统软件包。交互安装按下文规则启动 Zsh。需要从其他 Shell 手动启用时，执行 `zsh -l`；打印的 `source` 命令只在 Zsh 中执行。项目入口在其他 Shell 中跳过加载。

共享入口加载时检查当前 Shell 的补全状态。交互式 Zsh 缺少 `compdef` 时，先执行 `autoload -Uz compinit` 和 `compinit`，再加载工具。Oh My Zsh 或手工配置已经初始化补全时直接复用，不会再次运行 `compinit`。仅存在 Oh My Zsh 目录不代表补全已就绪。非交互加载不初始化补全；保留 [Zsh 标准补全初始化](https://zsh.sourceforge.io/Doc/Release/Completion-System.html#Use-of-compinit)及其安全检查。

## 先安装管理器，再选择工具

项目 README 推荐的 GitHub 命令不带参数执行自包含的 `install.sh`，仅安装 mst 及共享入口，不启用具体工具。随后执行：

```sh
mst list
mst install dsize
```

配置加载后，Zsh 中的 `mst` 可在任意目录使用。它是一个函数，根据自身定义文件的位置找到已保存的启动器，无需修改 PATH 或保留原仓库。不带参数的 `mst` 显示帮助。

## 在线更新与离线命令

| 命令 | 来源和作用 |
| --- | --- |
| `mst list` | 读取本地可用工具目录和已安装清单 |
| `mst install <工具名>` | 获取最新安装包，安装指定工具，同时刷新管理器 |
| `mst install --all` | 获取最新安装包，安装全部可用工具 |
| `mst update [工具名 ...]` | 获取最新安装包，仅更新已安装工具，保留管理器版本 |
| `mst upgrade` | 获取最新管理器和可用工具目录，保留工具文件及安装选择 |
| `mst uninstall <工具名>` / `mst uninstall --all` | 离线删除已登记工具，保留 mst |

在线操作从 [GitHub main 安装包](https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh)获取内容。完整下载后，先检查内容、Shell 语法和支持的引导标记，再执行和修改配置。下载失败或内容无效时，现有管理文件保持不变。

`mst list` 使用上次保存的工具目录。执行 `mst upgrade` 可以发现项目新发布的工具，再按需安装。`upgrade` 和 `update` 都不会安装新工具或已卸载的工具；没有已安装工具时，`update` 直接返回，不联网。

工具命令接受多个名称。`install` 不带名称表示全部可用工具，`update` 不带名称表示全部已安装工具。`--all` 选择当前操作对应的全部工具，不能与名称混用。`uninstall` 必须提供名称或 `--all`；`upgrade` 和 `list` 不接受名称或 `--all`。

本地或单文件分发时，`sh install.sh` 也只安装 mst。显式执行 `sh install.sh install dsize` 等命令使用这份脚本内嵌的文件；安装后的 `mst` 则采用上表中的在线行为。

## 路径与归属

| 内容 | 路径 |
| --- | --- |
| 安装根目录 | `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools` |
| 集中入口 | `<根目录>/init.zsh` |
| 管理器实现 | `<根目录>/manager/manager-core.sh` |
| 启动器与 Zsh 函数 | `<根目录>/manager/mst.sh` 和 `mst.zsh` |
| 管理器版本及语言包 | `<根目录>/manager/version` 和 `locales/` |
| 工具组件 | `<根目录>/tools/<名称>/`，包括源码、`version`、`files.list` 和语言包 |
| 已安装工具清单 | `<根目录>/tools/installed.list` |
| 保存的偏好 | `<根目录>/config.conf` |
| 新产生的备份 | `<根目录>/backups/` |
| Zsh 主配置 | `${ZDOTDIR:-$HOME}/.zshrc` |

环境变量未设置或为空时采用默认值，非空相对路径会被拒绝。例如，下载安装脚本后：

```sh
XDG_CONFIG_HOME="$HOME/Custom Config" ZDOTDIR="$HOME/Custom Zsh" sh install.sh
```

入口引用使用解析后的 `init.zsh` 绝对路径，并按 Zsh 规则转义。已安装的启动器记录工具目录和 `.zshrc` 路径，委托新下载的安装包时也传递这两个位置。之后修改环境变量不会将 `mst` 指向另一套配置；mst 启动的新会话也使用已记录的配置目录。父目录中的符号链接会被解析定位，链接本身保留。

安装清单是纯文本，每行四个字段，以 Tab 分隔：工具文件名、来源版本、来源提交、源码状态（`clean`、`modified` 或 `unknown`）。更新和卸载按清单处理，不会执行清单内容。各组件还保存三行的 `version` 记录，工具通过 `files.list` 记录其管理的组件文件；卸载时保留工具目录中另行添加的个人文件。请将这些记录与已安装文件一起保留。

仅安装或升级管理器不修改工具记录，迁移旧目录时除外。没有安装清单时，只认可集中入口管理块中已知工具的精确注册行，版本记为 `unknown`；同名文件本身不代表归属本项目。

`list` 也会展示本地工具目录中已不提供的已登记工具，并标出文件缺失。不指定名称的 `update` 保留并跳过最新安装包不提供的工具，显式更新它们则报错。已登记工具即使不再提供，仍可卸载。

## 语言

默认使用英文，简体中文的标识是 `zh-CN`：

```sh
mst config language zh-CN
mst config language en
mst config language
mst --lang zh-CN list
```

保存的设置在下一次调用时应用到 mst 和工具的帮助、错误及补全说明，已经加载的工具也会读取新设置。语言切换不会启动新会话。`--lang` 仅覆盖本次管理器命令；`MST_LANG=en` 或 `MST_LANG=zh-CN` 可为管理器或工具设置环境覆盖。优先级为 `--lang` → `MST_LANG` → 保存的偏好 → 英文。查询命令显示保存的偏好。

偏好按数据校验，不作为 Shell 脚本执行。不支持的语言或损坏的配置会报错，可使用显式语言覆盖修复损坏配置。缺少译文时回退英文。工具名称、参数、路径、磁盘占用数据、版本和退出码不受语言影响。管理器语言包随 mst 升级；工具语言包随对应工具更新。

## 版本

`mst --version`（也可用 `mst version`）显示已安装管理器的来源版本、提交和源码状态。`dsize --version` 显示当前 Shell 已加载的函数版本；关闭自动启用后，更新工具还需要 source 打印的入口，才能加载并查看新函数的版本。

发布版本使用 `主版本.次版本.修订号`，Git 标签为 `vX.Y.Z`。未发布构建形如 `0.1.0-dev+<源码摘要>`。开发快照可能显示 `modified`，无法取得 Git 来源时记为 `unknown`。来源提交描述构建时的源码快照，可能早于生成安装包的发布提交。

`mst list` 分别展示已安装版本和本地目录中的可用版本。`mst upgrade` 更新管理器及工具目录，`mst update` 更新已安装工具的整个组件及版本记录。在线命令获取已发布到 `main` 的安装包，不通过比较版本号选择发布版本。

## 迁移原目录

已安装在 `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/tools` 时，执行 `mst upgrade` 即可迁移。原启动器记录了安装和配置位置，即使当前环境变量不同，也能保留自定义路径；重新执行新版引导安装也会识别默认位置的原安装。

仅复制已登记的工具到新的组件目录，保留原源码。没有版本信息的工具记为 `unknown`，执行 `mst update [工具名 ...]` 后才安装带版本的组件；更新之前，原工具也会继续使用原来的输出文案。新工具目录中不再提供的已登记工具继续保留，仍可卸载。

`.zshrc` 管理块改为引用新入口，旧入口中的工具注册被清空。旧入口的个人内容保留原路径，并由新入口加载，确保个人相对路径引用仍然有效。旧 mst 启动器转发到新启动器，让已有会话可以继续使用。原工具副本、个人文件和旧备份均保留；仍需兼容入口或个人引用时，请保留原目录。

迁移同时获取两处目录的锁并记录恢复状态。中途失败后，修复报错并重复升级或引导命令。遇到冲突文件、无效清单、已登记工具缺失或受管理目录为链接时，会保留并报错，不会静默覆盖。

## 配置保留

主配置使用以下唯一标记：

```text
# >>> mac-shell-tools >>>
# <<< mac-shell-tools <<<
```

入口管理块放在主配置末尾、现有 Oh My Zsh 初始化之后。`init.zsh` 从自身目录加载 mst 和显式登记的工具，不遍历执行其他脚本或备份。管理区域使用：

```text
# >>> mac-shell-tools managed tools >>>
# <<< mac-shell-tools managed tools <<<
```

管理块之外的内容保留。入口来源不明、标记损坏或重复、目标类型错误、被管理文件为符号链接、最终工具目录或管理器目录为符号链接时，停止变更。未登记的个人文件不会被卸载。

卸载最后一个工具后，保留 mst、集中入口及主配置引用，方便继续查询和安装；移除工具注册和空的工具清单。无关文件、备份和 `.zshrc` 文件本身也保留。

其他 `source` 行、手写函数和别名不会改写。同名定义仍可能覆盖项目函数，或在卸载后继续存在，需要单独管理。

## 会话生效方式

成功修改文件后，如果输入和输出都是终端，默认启动新的 Zsh 登录会话。启动前会释放锁、删除下载、引导及安装暂存文件。新会话重新加载配置，不会修改调用者原会话的内存状态。

`--no-run-zsh`、`--unattended` 或 `RUNZSH=no` 可关闭自动启动。查询、失败、内容不变、管道输入和输出重定向均不会启动新 Zsh。`RUNZSH` 接受 `yes` 或 `no`，未设置或为空时采用 `yes`。退出新会话后可能回到原会话；未导出的变量和函数不会带入新会话。

推荐的 `sh -c` 下载方式保留终端输入；`curl ... | sh` 的安装器输入是管道，因此需要手动启用。

安装或更新后，可在 Zsh 中执行打印的 `source` 命令，或执行 `zsh -l` 启动 Zsh。卸载后请启动全新的 Zsh 会话或运行 `exec zsh -l`；重新 source 配置不会清除内存中已有的函数。

## 备份与恢复

修改或删除已有文件前，包括管理器和工具记录，都会在 `<根目录>/backups/` 下按原相对路径创建备份：

```text
backups/tools/dsize/dsize.zsh.bak.YYYYMMDD-HHMMSS.<随机后缀>
backups/zshrc/.zshrc.bak.YYYYMMDD-HHMMSS.<随机后缀>
backups/legacy/init.zsh.bak.YYYYMMDD-HHMMSS.<随机后缀>
```

管理器会打印备份路径。相同文件不重写、不新增备份。变更前先准备内容、检查语法和所有目标的写权限；每个文件通过同目录暂存文件替换。

操作不是跨文件事务，后续写入或删除失败时，前面的变更可能已经完成。修复报错后重复命令，或配套恢复管理器、工具、清单、集中入口和主配置的备份，保持文件与注册关系一致，再启动新的 Zsh 会话。管理器缺失或损坏时，可以重新执行 GitHub 安装命令修复。

同一工具目录由 `.mac-shell-tools-install.lock` 互斥保护。只有确认没有管理操作运行后，才可手动删除残留锁。失败清理仅处理本次操作创建的锁和暂存文件。
