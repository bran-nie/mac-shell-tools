# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：dsize [目录] [选项]

以树形展示占用最大的目录，父目录在前，同级目录按占用从大到小排列。
默认目录为 .，默认深度为 2，默认最多显示 25 条。

  -d N, --depth N, --depth=N  显示深度，十进制整数 0–1000
  -n N, --lines N, --lines=N  最大行数，十进制整数 1–1000000
  --flat                     使用原来的平铺排行，最大条目在最后
  -V, --version              查看已加载工具的版本
  -h, --help                 显示帮助
  --                         停止解析选项，后面至多一个目录

目录和选项可交错；同一选项重复时最后一次生效。支持前导零。
深度只限制显示层级，计算总量仍会遍历更深内容。
行数包含根目录和父目录；树形大小使用可读单位。
结果是目录占用汇总，文件大小计入所属目录，不逐个列出文件。
父目录包含子目录，不能将输出相加；这里只统计磁盘占用，不清理文件。
退出码：0 成功或帮助，2 参数错误，1 扫描不完整或依赖执行失败。' ;;
    error.integer) printf '%s\n' '%s必须是十进制整数（%s–%s）。' ;;
    error.range) printf '%s\n' '%s范围为 %s–%s。' ;;
    error.value) printf '%s\n' '%s 缺少数值。' ;;
    error.directory_count) printf '%s\n' '只允许一个目录。' ;;
    error.option) printf '%s\n' '未知选项 %s。' ;;
    error.missing) printf '%s\n' '路径不存在：%s' ;;
    error.directory) printf '%s\n' '不是目录：%s' ;;
    error.dependency) printf '%s\n' '缺少命令 %s。' ;;
    error.interrupted) printf '%s\n' '扫描已中断，结果可能不完整。' ;;
    error.partial) printf '%s\n' '不完整扫描；部分目录无法读取或 du 执行失败。' ;;
    error.pipeline) printf '%s\n' '排序、截取或格式化输出失败。' ;;
    label.depth) printf '%s\n' '深度' ;;
    label.lines) printf '%s\n' '条数' ;;
    completion.depth) printf '%s\n' '显示深度，默认 2' ;;
    completion.lines) printf '%s\n' '最大行数，默认 25' ;;
    completion.flat) printf '%s\n' '平铺大小排行，最大条目在最后' ;;
    completion.help) printf '%s\n' '显示帮助' ;;
    completion.version) printf '%s\n' '显示版本' ;;
    completion.directory) printf '%s\n' '目录' ;;
    *) return 1 ;;
  esac
}
