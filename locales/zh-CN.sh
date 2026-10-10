# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    error.help) printf '%s\n' '运行 mst --help 查看用法。' ;;
    error.interrupted) printf '%s\n' '操作已中断；已生成的备份可用于恢复。' ;;
    error.runzsh) printf '%s\n' 'RUNZSH 只能为 yes 或 no。' ;;
    error.option) printf '%s\n' '未知参数：%s' ;;
    error.command) printf '%s\n' '未知命令：%s' ;;
    error.name) printf '%s\n' '无效工具名：%s' ;;
    error.all_names) printf '%s\n' '--all 不能与工具名同时使用。' ;;
    error.no_names) printf '%s\n' '%s 不接受工具名或 --all。' ;;
    error.uninstall_names) printf '%s\n' '请指定卸载工具，或使用 uninstall --all。' ;;
    error.language) printf '%s\n' '不支持的语言：%s（请使用 en 或 zh-CN）。' ;;
    error.language_value) printf '%s\n' '--lang 需要 en 或 zh-CN。' ;;
    error.config) printf '%s\n' '用法：mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s 必须是绝对路径：%s' ;;
    error.symlink) printf '%s\n' '目标为符号链接，已保留并停止变更：%s' ;;
    error.file_type) printf '%s\n' '目标不是普通文件：%s' ;;
    error.directory_type) printf '%s\n' '目标不是目录：%s' ;;
    error.markers) printf '%s\n' '管理标记损坏或重复：%s' ;;
    error.unknown_entry) printf '%s\n' '已有入口没有可识别的管理块：%s' ;;
    error.state) printf '%s\n' '安装清单记录无效或重复：%s' ;;
    error.assets) printf '%s\n' '工具文件清单无效：%s' ;;
    error.available) printf '%s\n' '当前安装包不提供工具：%s' ;;
    error.not_installed) printf '%s\n' '工具尚未安装：%s' ;;
    error.unknown_tool) printf '%s\n' '未知工具：%s' ;;
    error.escape) printf '%s\n' '无法转义配置路径：%s' ;;
    error.syntax) printf '%s\n' 'Shell 语法检查失败：%s' ;;
    error.dependency) printf '%s\n' '缺少基础命令：%s' ;;
    error.platform) printf '%s\n' '支持的系统：macOS 和 Linux。' ;;
    error.mkdir) printf '%s\n' '无法创建目录：%s' ;;
    error.enter) printf '%s\n' '无法进入目录：%s' ;;
    error.lock) printf '%s\n' '无法取得安装锁；确认没有其他操作运行后再处理：%s' ;;
    error.stage) printf '%s\n' '无法创建暂存目录。' ;;
    error.payload) printf '%s\n' '无法准备内嵌文件。' ;;
    error.readonly) printf '%s\n' '文件不可写：%s' ;;
    error.parent) printf '%s\n' '目录不可写或无法进入：%s' ;;
    error.backup) printf '%s\n' '无法创建完整备份：%s' ;;
    error.write) printf '%s\n' '无法写入或替换文件，请检查权限及剩余空间：%s' ;;
    error.remove) printf '%s\n' '无法删除文件：%s' ;;
    error.download) printf '%s\n' '下载失败；现有管理文件未变更。' ;;
    error.empty) printf '%s\n' '下载内容为空；现有文件未变更。' ;;
    error.download_syntax) printf '%s\n' '下载脚本语法错误；现有文件未变更。' ;;
    error.package) printf '%s\n' '下载内容不是支持的 mac-shell-tools 安装包；现有文件未变更。' ;;
    error.read_release) printf '%s\n' '无法读取下载的安装包。' ;;
    error.migration_conflict) printf '%s\n' '新安装与旧清单冲突，已保留两处内容：%s' ;;
    error.migration_source) printf '%s\n' '旧安装中缺少已登记工具：%s' ;;
    info.fetch) printf '%s\n' '正在获取：%s' ;;
    info.backup) printf '%s\n' '已备份：%s' ;;
    info.write) printf '%s\n' '已写入：%s' ;;
    info.remove) printf '%s\n' '已卸载：%s' ;;
    info.unchanged) printf '%s\n' '没有需要变更的文件。' ;;
    info.complete) printf '%s\n' '操作完成。' ;;
    info.login) printf '%s\n' '即将在当前终端启动新的 Zsh 登录会话；退出后可能回到原会话。' ;;
    info.activate) printf '%s\n' '请执行 zsh -l 进入 Zsh，或在当前 Zsh 执行：' ;;
    info.uninstall_activate) printf '%s\n' '请执行 exec zsh -l 启动全新的 Zsh；已有会话中的函数不会自动清除。' ;;
    info.empty) printf '%s\n' '尚未安装工具，无需更新。' ;;
    info.no_tools) printf '%s\n' '没有可处理的工具；可运行 mst list 查看状态。' ;;
    info.language) printf '%s\n' '语言：%s' ;;
    info.migrate) printf '%s\n' '正在迁移已登记安装：%s' ;;
    info.migrated) printf '%s\n' '迁移完成；个人文件与已有备份保留在 %s' ;;
    status.not_installed) printf '%s\n' '未安装' ;;
    status.installed) printf '%s\n' '已安装' ;;
    status.missing) printf '%s\n' '已安装（文件缺失）' ;;
    status.unavailable) printf '%s\n' '工具目录中已不提供' ;;
    list.header) printf '%s\n' '工具                 状态                         已安装版本                    可用版本' ;;
    help) printf '%s\n' '用法：mst <命令> [工具名 ...] [参数]
      sh install.sh [命令] [工具名 ...] [参数]

命令：
  install [工具名 ...]     安装指定工具；不指定时安装全部工具。
  update [工具名 ...]      仅更新已安装工具。
  uninstall 工具名 ...    卸载指定工具，删除前备份。
  uninstall --all         卸载全部工具，保留 mst。
  list                    查看本地可用工具、安装状态和版本。
  upgrade                 升级 mst 和可用工具目录，保留已安装工具。
  version                 查看 mst 的版本和源码修订。
  config language         查看已保存的语言，默认 en。
  config language en      为 mst 和工具保存英文设置。
  config language zh-CN   为 mst 和工具保存简体中文设置。

参数：
  --all                   选择全部工具，不能与名称混用。
  --lang en|zh-CN         仅本次命令使用指定语言。
  --no-run-zsh            不启动新的 Zsh 会话。
  --unattended            非交互操作，不启动 Zsh。
  -V, --version           查看 mst 版本。
  -h, --help              查看帮助。

不带命令运行 install.sh 时只安装 mst。
安装后的 mst install/update/upgrade 从 GitHub 获取最新安装包。
RUNZSH=no 也可关闭新的登录会话。
语言设置在下次调用时生效，无需启动新会话。' ;;
    *) return 1 ;;
  esac
}
