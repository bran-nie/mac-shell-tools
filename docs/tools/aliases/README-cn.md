# aliases

[English](README.md)

在当前 Zsh 中加载常用别名，以及你明确指定的个人配置文件。内置别名随工具安装，个人文件由你维护。

## 安装和试用

```sh
mst install aliases
aliases list
aliases show ll
ll
```

安装只需要 mst 的 Zsh 和基础命令，不要求 Node/npm 等额外运行时。

从源码试用时，在 Zsh 执行 `source /你的仓库路径/tools/aliases/aliases.zsh`，再使用上述命令。源码加载不会安装工具或修改 `.zshrc`。

## 内置别名

| 别名 | 实际命令 | 用途 |
| --- | --- | --- |
| `ll` | `ls -alh` | 详细列出文件（含隐藏文件），以易读单位显示文件大小 |
| `duls` | `du -h -d 1 -c` | 以易读单位显示目录及其下一级子目录的磁盘占用，并输出合计 |

已有同名 alias 或函数时跳过内置定义；`aliases list` 会显示状态。

## 接入个人配置

可以直接沿用已有的 Zsh 文件：

```sh
aliases config file ~/.zshrc_alias
aliases config show
aliases reload
```

`config file <路径>` 校验文件可读及 Zsh 语法后，只保存路径；**执行 `aliases reload` 或打开新终端才加载**。支持相对路径、加引号的 `~/...`、中文空格路径和个人文件符号链接。路径不能包含换行。未指定文件时只加载内置配置，不自动寻找 `~/.zshrc_alias`。

文件可以使用原生 Zsh 语法：

```zsh
alias ll='ls -al'
alias work='cd "$HOME/work"'

function mkcd {
  mkdir -p -- "$1" && cd -- "$1"
}
```

个人文件在当前 Shell 中 source，可以执行其中的命令；请只指定自己信任的文件。普通 alias 和函数定义会被跟踪，环境变量、工作目录、全局/后缀别名、钩子等其他脚本效果不在撤销范围。函数建议只在调用时执行操作。

如果 `.zshrc` 原来已有 `source ~/.zshrc_alias`，迁移时移除那条旧引用，并打开新终端，让同一个文件只经 aliases 加载。首次加载前就存在的相同定义不会被认领为工具所有，避免之后删除你的原有配置。工具不会自动改写 `.zshrc` 中的个人内容。

内置配置随 `mst install aliases` 出现在新电脑；个人文件需要通过自己的私有 dotfiles 仓库等方式同步，再设置路径。工具不会上传文件或提供远端同步。

## 查看和重载

| 命令 | 行为 |
| --- | --- |
| `aliases`、`aliases --help` | 显示帮助 |
| `aliases list` | 查看本工具跟踪的 alias、函数、来源、状态和当前定义 |
| `aliases show <名称>` | 查看完整定义，包含多行函数体 |
| `aliases reload` | 在当前终端重新加载个人配置和内置默认值 |
| `aliases config file` | 输出保存的个人文件路径；未设置时输出空行 |
| `aliases config file <路径>` | 保存路径，等待重载或新会话 |
| `aliases config file --reset` | 清除路径设置，保留个人文件；等待重载或新会话 |
| `aliases config show` | 查看配置文件、保存/已加载的个人路径及上次加载退出码 |
| `aliases --version` | 查看当前已加载的工具版本 |

列表的来源为内置或个人，类型 `alias`/`function` 保持不变。列表表示当前 Shell 的定义，不会为了查看配置或补全而再次执行个人文件。状态包括：生效、已跳过、已手动修改、已移除、被别名遮蔽。

个人 alias/函数优先于内置默认值。重载时，已删除的受管定义会被移除；覆盖过更早定义的，恢复更早定义。只有当前内容与上次加载内容一致时才撤销。终端中后续手动修改或删除过的名称，在本会话后续重载时都保持手动状态；新终端重新按照配置加载。

个人文件语法错误或不可读时不改变现有定义；source 返回非零时恢复加载前的 alias/函数定义。任意个人脚本的其他副作用无法回滚。启动加载静默，出错后可用 `aliases list`、`aliases config show` 查看状态，再执行 `aliases reload` 查看具体原因。重载会显示个人文件自身的输出。

## 配置与更新

路径设置以纯文本 `file=/绝对路径` 保存到安装根目录的 `aliases.conf`，与共享 `init.zsh` 相邻。安装位置固定后不受后来修改 `XDG_CONFIG_HOME` 影响。直接从源码加载时使用 `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/aliases.conf`。该设置文件不执行代码，拒绝链接及非普通文件；个人 Zsh 文件则允许符号链接，方便接入 dotfiles。

`mst update aliases` 更新内置定义及工具实现，保留个人文件和路径设置。`mst uninstall aliases` 同样保留个人配置；卸载后启动新终端或执行 `exec zsh -l` 清除旧会话中已加载的定义。离线重新安装后继续使用保留的设置。

帮助、状态、错误和补全说明跟随 mst 的语言设置，支持 `MST_LANG` 临时覆盖。别名名称及命令内容不翻译。Tab 支持子命令、已跟踪名称、配置文件路径、重置及帮助/版本选项。

退出码：`0` 成功，`2` 参数/配置/语法错误，`1` source 或写入失败。`list` 在上次加载失败时返回 `1` 并提示重载；`config show` 仍可用于诊断。
