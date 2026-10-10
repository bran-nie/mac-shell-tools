# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：extract [选项] 压缩包

将一个 ZIP 或 TAR 压缩包解压到当前目录下的新目录中。
默认目录名为压缩包文件名去掉压缩扩展名。
支持：.zip .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz（不区分大小写）。

  -C DIR, --directory DIR, --directory=DIR  指定准确的新目标目录
  -l, --list                               只列出内容，不解压
  -V, --version                            显示已加载的工具版本
  -h, --help                               显示帮助
  --                                       停止解析选项

示例：extract app.tar.gz；extract app.zip -C ./unpacked；extract --list app.zip
不使用已有目标目录；目标的父目录必须已存在。
只接受普通文件和目录，拒绝链接及特殊条目。
解压前拒绝绝对路径及包含上级目录组件的条目。
压缩包快照需要临时空间；解压失败时保留已产生的部分内容。
不支持加密 ZIP；底层命令的诊断保留其原有语言。
退出码：0 成功/预览/帮助，2 参数错误或拒绝的条目，1 命令失败。' ;;
    success) printf '%s\n' '已解压到：%s' ;;
    error.option) printf '%s\n' '未知选项：%s' ;;
    error.value) printf '%s\n' '%s 需要一个非空目录。' ;;
    error.archive_count) printf '%s\n' '请指定且只指定一个压缩包。' ;;
    error.list_directory) printf '%s\n' '--list 不能与 --directory 同时使用。' ;;
    error.archive) printf '%s\n' '不是可读的压缩包文件：%s' ;;
    error.format) printf '%s\n' '不支持的压缩扩展名：%s' ;;
    error.exists) printf '%s\n' '目标已存在，请选择新目录：%s' ;;
    error.parent) printf '%s\n' '目标的父目录不存在：%s' ;;
    error.dependency) printf '%s\n' '缺少必要命令：%s' ;;
    error.temporary) printf '%s\n' '无法创建临时目录。' ;;
    error.read) printf '%s\n' '无法完整读取压缩包，未执行解压。' ;;
    error.path) printf '%s\n' '不支持或不安全的压缩包路径：%s' ;;
    error.type) printf '%s\n' '只支持普通文件和目录；发现链接、特殊条目或无法明确识别的列表。' ;;
    error.encrypted) printf '%s\n' '不支持加密 ZIP 条目，未执行解压。' ;;
    error.create) printf '%s\n' '无法创建新的目标目录：%s' ;;
    error.partial) printf '%s\n' '解压失败，已产生的部分内容保留在：%s' ;;
    error.interrupted) printf '%s\n' '解压已中断。' ;;
    completion.help) printf '%s\n' '显示帮助' ;;
    completion.version) printf '%s\n' '显示版本' ;;
    completion.list) printf '%s\n' '预览压缩包内容' ;;
    completion.directory) printf '%s\n' '新的目标目录' ;;
    label.archive) printf '%s\n' '压缩包' ;;
    label.directory) printf '%s\n' '目录' ;;
    *) return 1 ;;
  esac
}
