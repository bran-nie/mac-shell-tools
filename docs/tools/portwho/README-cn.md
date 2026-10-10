# portwho

[English](README.md) · [mac-shell-tools](../../../README-cn.md)

在 macOS 或 Linux 上使用 `lsof` 查询 TCP 监听端口，显示程序、PID、用户和监听地址。支持同时查询多个端口，不带参数时列出所有可见的 TCP 监听。

## 安装

[安装 mst](../../../README-cn.md#安装-mst) 后执行：

```sh
mst upgrade
mst install portwho
```

需要 `lsof`，macOS 自带；Ubuntu 缺少时可执行 `sudo apt install lsof`。运行 portwho 不需要网络。

## 用法

```zsh
portwho 3000
portwho 80 443
portwho
portwho --help
portwho --version
```

| 参数 | 行为 |
| --- | --- |
| `端口 ...` | 一个或多个十进制 TCP 端口，1–65535 |
| 不指定端口 | 列出所有可见的 TCP 监听 |
| `-h`、`--help` | 显示帮助 |
| `-V`、`--version` | 显示当前 Shell 已加载的版本 |
| `--` | 停止解析选项 |

前导零按十进制处理，重复端口只查询一次。不接受范围、服务名称或逗号分隔的端口。Tab 补全选项及常见端口号，不执行 lsof。

保留 `lsof` 原生表格，其中 `COMMAND` 是程序、`PID` 是进程号、`USER` 是用户、`NAME` 是监听地址。不通过网络解析主机名或服务名，只选择 `LISTEN` 状态的 TCP 套接字，不包含 UDP 或已建立的客户端连接。程序名来自操作系统，例如 `node` 或 `python`，不是完整启动参数。

结果受当前用户权限限制。无结果表示**没有匹配的可见监听**，不能据此证明端口空闲。工具不自动执行 sudo，也不终止进程。底层警告或执行失败会返回错误，并保留已有的部分输出。

## 语言与版本

帮助、状态、错误及补全说明默认英文。`mst config language zh-CN` 或 `mst config language en` 保存的偏好在下一次调用时生效；`MST_LANG=zh-CN portwho --help` 仅覆盖本次调用。原生 lsof 数据、表头及底层诊断保留原有格式和语言。

`portwho --version` 显示已加载函数的来源版本、提交和源码状态。`mst update portwho` 一起更新源码、版本记录及语言包。关闭自动启用后，需要 source 打印的入口来加载新函数。

## 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 有结果、无可见匹配、帮助或版本 |
| `2` | 参数或语言配置错误 |
| `1` | 缺少依赖、查询失败、警告或中断 |
