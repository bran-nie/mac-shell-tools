# mac-shell-tools 常驻管理入口，由集中入口加载。
# 根据函数定义文件定位管理器，不依赖调用目录或后续环境变量变化。
mst() {
  emulate -L zsh
  local manager_directory=${${(%):-%x}:A:h}
  local manager_launcher="$manager_directory/mst.sh"
  if [[ ! -f "$manager_launcher" || -L "$manager_launcher" ]]; then
    print -ru2 -- "mst: 管理器入口缺失或为符号链接，请重新运行安装脚本：$manager_launcher"
    return 1
  fi
  command /bin/sh "$manager_launcher" "$@"
}
