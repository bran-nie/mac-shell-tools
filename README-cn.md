# mac-shell-tools

[English](README.md)

面向 macOS 的轻量 Zsh 工具集。首个工具 `dsize` 用一条命令查看目录中占用空间最大的条目，并提供目录、选项及数值的 Tab 补全。

需要 macOS、Zsh 和系统自带的基础命令，目标用户已使用 Oh My Zsh。不需要 `sudo`、Homebrew、Node.js、Python 或额外运行时；安装器不会安装 Oh My Zsh。

## 安装

在本地仓库执行：

```sh
sh install.sh
```

`install.sh` 是自包含单文件，可单独复制、分享，在任意目录运行，不需要旁边存在仓库源码。

仓库 `main` 分支发布 `install.sh` 后，可下载再运行：

```sh
curl -fsSL -o install.sh "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh"
sh install.sh
```

也可以一条命令安装：

```sh
curl -fsSL "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh" | sh
```

安装完成后重新打开终端，或在 Zsh 中执行安装器打印的 `source` 命令。默认路径下是：

```zsh
source "$HOME/.zshrc"
dsize --help
```

安装器作为子进程运行，当前 Shell 需要重新加载配置后才会启用工具。

## 使用 dsize

```zsh
dsize
dsize ~/Library
dsize ~/Library/Caches -n 50
dsize ~/Library -d 3 -n 50
dsize -n 50 ~/Library
dsize ~/Library --depth=3 --lines=30
dsize "$HOME/Library/Application Support" -n 30
dsize -- ./-example
```

| 参数 | 默认值 | 允许值 |
| --- | --- | --- |
| 目录 | `.` | 一个存在的目录 |
| `-d N`、`--depth N`、`--depth=N` | `2` | 十进制整数，0–1000 |
| `-n N`、`--lines N`、`--lines=N` | `25` | 十进制整数，1–1000000 |
| `-h`、`--help` | | 显示帮助 |
| `--` | | 停止解析选项，后面至多一个目录 |

目录与选项可以交错，同一选项重复时最后一次生效。前导零按十进制处理。空格路径使用标准 Shell 引号或反斜杠转义；不会用 `eval` 执行或展开输入字符串。

输出保持 `du` 的普通格式：可读单位、按大小升序排列、保留最大的 N 行，**最大的条目在最后一行**。默认包含目标目录总量，不添加表头、颜色或百分比。

退出码：成功或帮助为 `0`，参数或路径错误为 `2`，扫描不完整、中断或依赖执行失败为 `1`。`du` 失败时仍可输出已有结果，并在 stderr 给出简短诊断，不会重复显示大量权限报错。

### Tab 补全

`dsize <Tab>` 补全目录，包括带空格的路径；还支持短选项、长选项、帮助，以及深度建议 `0 1 2 3 4 5` 和条数建议 `10 25 50 100`。支持 `--depth=`、`--lines=`，数值建议不会限制真实取值。补全不会启动磁盘扫描。

请在 **Oh My Zsh 或 `compinit` 完成补全初始化后**加载工具。工具只在 `compdef` 可用时注册，不会重复执行 `compinit`。没有补全系统时，统计命令仍可使用。

## 路径与配置

默认安装结构：

```text
~/.config/zsh/tools/
├── init.zsh
└── dsize.zsh
```

- 工具目录：`${XDG_CONFIG_HOME:-$HOME/.config}/zsh/tools`。
- 主配置：`${ZDOTDIR:-$HOME}/.zshrc`。
- 变量未设置或为空时采用默认值，非空相对路径会报错。

例如：

```sh
XDG_CONFIG_HOME="$HOME/Custom Config" ZDOTDIR="$HOME/Custom Zsh" sh install.sh
```

安装器在主配置末尾、现有 Oh My Zsh 初始化之后添加一个带起止标记的管理块。管理块先检查 `init.zsh` 是否存在，再加载它。引用使用安装时解析的绝对路径，并进行 Zsh 字符串转义；之后修改环境变量不会自动迁移这条引用。需要换位置时，用目标路径重新运行安装器。父目录中的符号链接会被解析定位，链接本身保留。

`init.zsh` 根据自身位置显式加载注册工具。加载过程安静，不改变工作目录，不遍历执行未注册脚本或备份。再次 source 可以刷新函数和补全。

## 更新、备份与恢复

重复运行新版 `install.sh` 即可更新。相同内容不会重写。修改已有 `dsize.zsh`、`init.zsh` 或 `.zshrc` 前，会创建备份：

```text
<文件名>.bak.YYYYMMDD-HHMMSS.<随机后缀>
```

每个备份位置都会打印。恢复时将选定备份复制回原路径，再重新加载配置。已有 `init.zsh` 只更新工具注册管理区域，其他引用和注释保留；`.zshrc` 保留无关内容，将项目管理块放到末尾。

入口来源不明、管理标记损坏或重复、目标类型错误、配置文件或最终工具目录为符号链接时，安装会停止，保留链接及其目标。请手动处理后重试。同一工具目录的并发安装会被拒绝；只有确认没有安装器运行后，才可手动移除残留的 `.mac-shell-tools-install.lock` 目录。

所有内容先准备并做语法检查，再通过同目录暂存文件逐个替换；先安装工具和入口，最后更新主配置。失败时可能已有部分文件更新，但备份保留。修复报错后可重复安装，或从备份恢复。

不会自动改写其他 `source` 行或手写函数。如果已经自行定义 `dsize()`、`_dsize()` 或 `compdef _dsize dsize`，请按实际需要手动删除重复定义，包括 `.zshrc_alias` 中的定义。任意自定义加载顺序仍可能覆盖同名函数。

## 卸载

1. 如果没有其他工具依赖集中入口，移除 `.zshrc` 中 `# >>> mac-shell-tools >>>` 至 `# <<< mac-shell-tools <<<` 的整个管理块。入口还有个人工具时，保留入口引用，仅移除 `dsize.zsh` 注册。
2. 确认归属后删除已安装的 `dsize.zsh`；只有在 `init.zsh` 中没有需要保留的个人引用或注释时，才删除入口文件。
3. 保留其他工具和仍需使用的备份，重新打开终端以清除已加载的函数定义。

不要为卸载而直接删除整个共享工具目录。

## 数字解读

这里统计的是**磁盘占用**，不承诺等于文件逻辑大小、Finder 数字、macOS“系统数据”，或删除后实际释放的空间。硬链接和 APFS 特性会影响数字。父目录包含子目录，因此输出不能简单相加。

深度限制的是展示层级，为计算总量仍会遍历更深内容；降低深度不保证扫描明显变快。权限受限可能产生不完整结果。输出保留 `du` 的文本格式，包含 Tab 或换行的文件名不能无歧义地表示为记录。工具只统计，不删除、不清理文件。

## 开发与验证

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

检查需要 macOS，所有配置验证使用临时 HOME 和隔离目录。覆盖真实 BSD 管道、参数和权限错误、依赖失败、中断、安装更新、备份、配置保留、独立脚本及 stdin 安装，以及 Zsh 伪终端中的真实 Tab 补全。CI 在 macOS 上运行同一命令。

新增工具、同步生成安装器和简短的终端人工检查见[维护说明](docs/development.md)。

项目许可证尚未选择。
