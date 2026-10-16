# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：aliases [命令]

在当前终端加载常用别名，以及可选的个人 Zsh 配置文件。
内置：ll="ls -alh"，duls="du -h -d 1 -c"。

  list                 查看跟踪的 alias/函数、来源和当前状态
  show 名称            查看跟踪名称的当前定义
  reload               在当前终端重载，撤销已删除的受管定义
  config file          查看保存的个人文件路径，默认不设置
  config file 路径     保存可读的 Zsh 文件路径，相对路径转为绝对路径
  config file --reset  清除保存的路径，保留个人文件
  config show          查看保存/已加载路径及上次加载退出码
  -V, --version        显示已加载的 aliases 工具版本
  -h, --help           显示帮助

设置或重置路径后，执行 aliases reload 或打开新终端使其生效。
个人 alias/函数优先于内置；内置别名跳过已有名称。
终端中后续手动修改的名称保持不变，直至新会话。
重载只在当前定义仍与工具加载的定义一致时撤销，并恢复更早的定义。
个人文件是受信任的 Zsh 代码，source 可能执行其中的命令和函数。
仅跟踪普通 alias 和函数定义，其他脚本副作用无法撤销。
启动加载保持静默；list/config show 可查看上次加载失败的状态。
工具不会自动寻找、上传或修改个人文件。

示例：aliases list；aliases show ll
      aliases config file ~/.zshrc_alias；aliases reload
退出码：0 成功；2 参数或配置错误；1 加载或写入失败。' ;;
    error.usage) printf '%s\n' '用法：aliases list | show 名称 | reload | config ... | --help | --version' ;;
    error.config_usage) printf '%s\n' '用法：aliases config show | aliases config file [路径|--reset]' ;;
    error.config_file) printf '%s\n' 'aliases 配置无效、不可读或为链接：%s' ;;
    error.config_write) printf '%s\n' '无法保存 aliases 配置：%s' ;;
    error.path) printf '%s\n' '无效的个人文件路径：%s（请使用不包含换行的非空路径）。' ;;
    error.personal_file) printf '%s\n' '个人文件不是可读的普通文件：%s' ;;
    error.personal_syntax) printf '%s\n' '个人文件的 Zsh 语法无效：%s' ;;
    error.personal_load) printf '%s\n' '个人文件加载失败：%s（退出码 %s）。已恢复 alias 和函数定义。' ;;
    error.dependency) printf '%s\n' '缺少配置操作所需命令：%s' ;;
    error.unknown) printf '%s\n' 'aliases 未跟踪此名称：%s' ;;
    error.last_load) printf '%s\n' '上次加载失败，请执行 aliases reload 查看原因。' ;;
    error.recursive) printf '%s\n' '不支持递归重载 aliases。' ;;
    config.show) printf '%s\n' '配置文件：%s
保存的个人文件：%s
已加载个人文件：%s
上次加载退出码：%s' ;;
    config.saved) printf '%s\n' '配置已保存。执行 aliases reload 或打开新终端使其生效。' ;;
    reloaded) printf '%s\n' '已在当前终端重载别名。' ;;
    list.header) printf '%s\n' '名称               类型      来源         状态           当前定义' ;;
    show.header) printf '%s\n' '名称：%s
类型：%s
来源：%s
状态：%s' ;;
    show.absent) printf '%s\n' '（未定义）' ;;
    source.builtin) printf '%s\n' '内置' ;;
    source.personal) printf '%s\n' '个人' ;;
    state.active) printf '%s\n' '生效' ;;
    state.skipped) printf '%s\n' '已跳过' ;;
    state.overridden) printf '%s\n' '已手动修改' ;;
    state.removed) printf '%s\n' '已移除' ;;
    state.shadowed) printf '%s\n' '被别名遮蔽' ;;
    completion.command) printf '%s\n' 'Aliases 子命令' ;;
    completion.list) printf '%s\n' '查看来源和生效定义' ;;
    completion.show) printf '%s\n' '查看跟踪的别名或函数' ;;
    completion.reload) printf '%s\n' '在当前终端重载别名' ;;
    completion.config) printf '%s\n' '配置个人文件' ;;
    completion.file) printf '%s\n' '设置或查看个人 Zsh 文件' ;;
    completion.config_show) printf '%s\n' '查看保存和已加载的配置' ;;
    completion.reset) printf '%s\n' '清除保存的个人文件路径' ;;
    completion.help) printf '%s\n' '显示 aliases 帮助' ;;
    completion.version) printf '%s\n' '显示 aliases 版本' ;;
    *) return 1 ;;
  esac
}
