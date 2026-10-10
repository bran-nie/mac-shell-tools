# extract

[English](README.md) · [mac-shell-tools](../../../README-cn.md)

在 macOS 或 Linux 上，将一个 ZIP 或 TAR 压缩包解压到独立的新目录。支持预览内容，以及压缩包路径、目标目录的 Tab 补全。

## 安装

[安装 mst](../../../README-cn.md#安装-mst) 后执行：

```sh
mst upgrade
mst install extract
```

TAR 使用 `tar`，ZIP 使用支持 ZipInfo 的 `unzip`。macOS 自带；Ubuntu 可执行 `sudo apt install tar unzip`。压缩 TAR 还依赖底层命令的 gzip、bzip2 或 xz 支持，Ubuntu 对应软件包为 `gzip`、`bzip2` 和 `xz-utils`。使用工具不需要额外运行时或网络。

## 用法

```zsh
extract app.tar.gz                 # 创建 ./app/
extract ~/Downloads/app.zip        # 在当前目录创建 ./app/
extract app.zip -C ./unpacked      # 准确创建 ./unpacked/
extract --list app.zip             # 预览，不创建输出目录
extract "带空格的压缩包.tgz"
extract -- ./-archive.zip
```

支持以下扩展名，不区分大小写：`.zip`、`.tar`、`.tar.gz`、`.tgz`、`.tar.bz2`、`.tbz2`、`.tar.xz`、`.txz`。不支持单独的 `.gz`、RAR、7z 和加密 ZIP。

| 参数 | 行为 |
| --- | --- |
| `压缩包` | 一个可读压缩包 |
| `-C DIR`、`--directory DIR`、`--directory=DIR` | 使用准确的新目标目录，父目录必须已存在 |
| `-l`、`--list` | 只列出条目，不解压；不能与 `-C` 同时使用 |
| `-h`、`--help` | 显示帮助 |
| `-V`、`--version` | 显示当前 Shell 已加载的版本 |
| `--` | 停止解析选项 |

选项和压缩包可以交错，同一目标目录选项重复时最后一次生效。默认去掉压缩包的完整压缩扩展名，在**当前工作目录**中创建同名目录。目标处已有目录、文件或链接时直接停止，不合并到已有目录。源压缩包保持不变，Shell 的当前目录也不变。

Tab 补全支持的压缩包文件名、选项，以及 `-C` 或 `--directory=` 后的目录。补全已有目录用于选择父路径，之后请追加新的子目录名。补全不打开或解压压缩包。

## 解压行为

工具接受普通文件和目录，拒绝符号链接、硬链接及特殊条目。ZIP 缺少 Unix 文件类型元数据的条目由 unzip 按普通文件处理。创建目标目录前，检查列表中的绝对路径、上级目录组件、不支持的条目类型及加密 ZIP 条目，同时保留 tar/unzip 自身的路径保护。`--list` 是只读预览，可以展示解压时会被拒绝的条目。

工具将压缩包复制到私有临时目录，保证检查和解压使用同一份快照。需要为压缩包副本和解压结果预留空间。工具内部忽略底层命令的选项环境变量，不改变调用者的设置。TAR 不恢复压缩包内的所有者或完整权限，新建目标目录只允许当前用户访问。

目标创建后若解压失败或中断，会保留部分结果并打印路径。重试前请检查或移除这些内容，或选择另一个新目录。底层文本列表无法无歧义地表示所有特殊文件名，列表不明确的压缩包可能被拒绝。

## 语言与版本

帮助、状态、错误及补全说明默认英文。执行 `mst config language zh-CN` 或 `mst config language en` 保存共享偏好，下一次调用即生效；`MST_LANG=zh-CN extract --help` 仅覆盖本次调用。压缩包文件名和底层诊断不翻译。

`extract --version` 显示已加载函数的来源版本、提交和源码状态。`mst update extract` 一起更新源码、版本记录和语言包。关闭自动启用后，需要 source 打印的入口来加载新函数。

## 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 解压成功、预览、帮助或版本 |
| `2` | 参数或路径错误、目标已存在、格式不支持或条目被拒绝 |
| `1` | 缺少依赖、压缩包不可读或损坏、底层执行失败或中断 |
