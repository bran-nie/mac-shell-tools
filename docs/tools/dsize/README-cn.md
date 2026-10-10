# dsize

[English](README.md) · [mac-shell-tools](../../../README-cn.md)

使用 macOS 自带的 `du`、`sort` 和 `tail`，查看指定目录的磁盘占用排行，默认最多显示 25 条结果，支持目录 Tab 补全。

## 安装

[安装 mst](../../../README-cn.md#安装-mst) 后执行：

```sh
mst install dsize
```

## 用法

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
| `-V`、`--version` | | 显示当前 Shell 已加载的版本 |
| `--` | | 停止解析选项，后面至多一个目录 |

目录与选项可以交错，同一选项重复时最后一次生效。前导零按十进制处理。空格路径使用标准 Shell 引号或反斜杠转义；不会通过 `eval` 执行输入字符串。

输出保留 `du` 的普通格式：可读单位、按大小升序排列、保留最大的 N 行，**最大的条目在最后一行**。结果是目录占用汇总，包含目标目录总量；文件占用计入所属目录，不逐个列出文件。不添加表头、颜色或百分比。

## Tab 补全

`dsize <Tab>` 补全目录，包括带空格的路径；还支持短选项、长选项、帮助，以及深度建议 `0 1 2 3 4 5` 和条数建议 `10 25 50 100`。支持 `--depth=`、`--lines=`；建议不限制实际取值，补全不会启动磁盘扫描。

在 Oh My Zsh 或 `compinit` 完成初始化后加载工具。工具只在 `compdef` 可用时注册，不会运行 `compinit`；没有补全系统时统计命令仍可使用。

## 语言与版本

帮助、错误及补全说明默认英文。执行 `mst config language zh-CN` 或 `mst config language en` 保存共享偏好，下一次调用即生效，无需重新加载。`MST_LANG=zh-CN dsize --help` 仅覆盖本次调用。缺少译文时回退英文，磁盘占用数据及退出码不变。

`dsize --version` 显示已加载函数的来源版本、提交及源码状态。执行 `mst update dsize --no-run-zsh` 后，需要 source 打印的入口才能使用新函数。源码、版本记录和语言包放在 `~/.config/zsh/mac-shell-tools/tools/dsize/`，随工具一起更新。

## 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功或帮助 |
| `2` | 参数或路径错误 |
| `1` | 扫描不完整、中断或依赖执行失败 |

`du` 失败时仍可输出已有结果，并在 stderr 给出简短诊断，不会重复显示大量权限报错。

## 数字解读

这里统计的是**磁盘占用**，可能不同于文件逻辑大小、Finder 数字、macOS“系统数据”或删除后实际释放的空间。硬链接和 APFS 特性会影响数字。父目录包含子目录，输出不能简单相加。

深度限制展示层级，为计算总量仍会遍历更深内容；降低深度不保证扫描更快。权限受限时可能得到不完整结果。

输出保留 `du` 的文本格式，带 Tab 或换行的文件名不能无歧义地表示为记录。工具只统计磁盘占用，不删除或清理文件。
