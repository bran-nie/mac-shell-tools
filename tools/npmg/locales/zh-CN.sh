# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：npmg [命令] [包名 ...] [npm 参数]

使用当前启用的 Node 和 npm，管理全局包。
目录优先级：本次 --prefix、保存的 prefix、默认 $HOME/.local/npm。
直接输入包名相当于 install；不带参数显示帮助。

  install, i        安装包，支持版本和标签
  update, up        更新指定包；不指定包名时更新全部包
  uninstall, rm     卸载指定包
  list, ls          查看已安装的包，默认 --depth=0
  config prefix     查看当前生效的 prefix
  config prefix 目录 保存 prefix，相对路径转为绝对路径
  config prefix --reset
                    恢复默认 prefix
  config show       查看 prefix、来源、配置文件及 bin 目录
  -V, --version     显示已加载的 npmg 工具版本
  -h, --help        显示本工具帮助

包操作默认使用 -g --prefix <当前生效的目录>。
显式 npm 参数可覆盖默认值。其余参数、输出、错误及退出码由 npm 处理。
子命令后的 --help/--version 使用 npm 的含义。
包名与子命令同名时使用 npmg install <包名>，或 npmg -- <包名>。
加载 npmg 时将当前 prefix/bin 追加到 PATH，不重复添加，保留已有优先级。
保存或恢复 prefix 时同时更新当前终端，后续加载使用新配置。
配置命令不要求 Node/npm，不修改 npm 自身配置。
当前 PATH 中必须有 Node 和 npm；不会自动安装依赖。

示例：npmg live-server；npmg install playwright @larksuite/cli
      npmg update；npmg rm live-server；npmg ls --json
      npmg live-server@latest --dry-run；npmg install --help
单独的 install 沿用 npm 行为，将当前包上下文全局安装。
退出码：0 帮助/版本；2 语言配置错误；1 缺少依赖；包操作返回 npm 的退出码。' ;;
    error.dependency) printf '%s\n' '缺少必要命令：%s。请先让当前 PATH 中的 Node 和 npm 可用。' ;;
    error.config_dependency) printf '%s\n' '缺少配置操作所需命令：%s' ;;
    error.config_usage) printf '%s\n' '用法：npmg config show | npmg config prefix [目录|--reset]' ;;
    error.config_file) printf '%s\n' 'npmg 配置无效、不可读或为链接：%s' ;;
    error.config_write) printf '%s\n' '无法保存 npmg 配置：%s' ;;
    error.prefix) printf '%s\n' '无效的 prefix：%s（请使用非空路径，不包含冒号或换行）。' ;;
    config.show) printf '%s\n' 'Prefix：%s
来源：%s
配置文件：%s
Bin：%s' ;;
    config.saved) printf '%s\n' 'Prefix：%s' ;;
    completion.help) printf '%s\n' '显示 npmg 帮助' ;;
    completion.version) printf '%s\n' '显示 npmg 版本' ;;
    completion.npm_help) printf '%s\n' '显示 npm 子命令帮助' ;;
    completion.npm_version) printf '%s\n' '显示 npm 版本' ;;
    completion.command) printf '%s\n' '子命令或待安装的包名' ;;
    completion.package) printf '%s\n' 'npm 包规格' ;;
    completion.prefix) printf '%s\n' '覆盖共享安装目录' ;;
    completion.registry) printf '%s\n' 'npm 仓库地址' ;;
    completion.depth) printf '%s\n' '依赖展示深度' ;;
    completion.install) printf '%s\n' '安装全局包' ;;
    completion.update) printf '%s\n' '更新全局包' ;;
    completion.uninstall) printf '%s\n' '卸载全局包' ;;
    completion.list) printf '%s\n' '查看已安装的全局包' ;;
    completion.config) printf '%s\n' '配置 npmg' ;;
    completion.show) printf '%s\n' '查看当前生效配置' ;;
    completion.reset) printf '%s\n' '恢复默认 prefix' ;;
    *) return 1 ;;
  esac
}
