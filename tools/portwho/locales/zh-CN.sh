# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：portwho [端口 ...] [选项]

使用 lsof 查看可见的 TCP 监听信息：程序、PID、用户及监听地址。
不指定端口时列出所有可见的 TCP 监听。不包含 UDP。

  端口              一个或多个十进制端口，1–65535
  -V, --version     显示已加载的工具版本
  -h, --help        显示帮助
  --                停止解析选项

示例：portwho 3000；portwho 80 443；portwho
前导零按十进制处理，重复端口只查询一次。
结果受当前权限限制，无结果不能证明端口空闲。
保留 lsof 原生表格，不终止进程，不自动执行 sudo。
退出码：0 有结果/无可见匹配/帮助，2 参数错误，1 查询失败。' ;;
    empty) printf '%s\n' '没有匹配的可见 TCP 监听。结果受当前权限限制，不能据此证明端口空闲。' ;;
    error.option) printf '%s\n' '未知选项：%s' ;;
    error.port) printf '%s\n' '无效端口：%s（请输入 1–65535 的十进制整数）。' ;;
    error.dependency) printf '%s\n' '缺少必要命令：%s' ;;
    error.temporary) printf '%s\n' '无法创建临时目录。' ;;
    error.query) printf '%s\n' 'lsof 执行失败或报告结果不完整。' ;;
    error.interrupted) printf '%s\n' '查询已中断，结果可能不完整。' ;;
    completion.help) printf '%s\n' '显示帮助' ;;
    completion.version) printf '%s\n' '显示版本' ;;
    completion.port) printf '%s\n' 'TCP 端口' ;;
    *) return 1 ;;
  esac
}
