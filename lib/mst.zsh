# mac-shell-tools 常驻管理入口，由集中入口加载。
# 根据函数定义文件定位管理器，不依赖调用目录或后续环境变量变化。
mst() {
  emulate -L zsh
  local manager_directory=${${(%):-%x}:A:h}
  local manager_launcher="$manager_directory/mst.sh"
  if [[ ! -f "$manager_launcher" || -L "$manager_launcher" ]]; then
    print -ru2 -- "mst: Manager launcher is missing or linked; re-run the installation command: $manager_launcher"
    return 1
  fi
  command /bin/sh "$manager_launcher" "$@"
}

# Complete configuration locally without invoking the manager or changing files.
_mst() {
  setopt localoptions
  local state state_descr line
  local curcontext="$curcontext"
  local -A opt_args
  _arguments -C -S \
    '(-h --help)'{-h,--help} \
    '(-V --version)'{-V,--version} \
    '--all' '--no-run-zsh' '--unattended' \
    '--lang=:language:(en zh-CN)' \
    '1:command:(install update uninstall list upgrade version config)' \
    '2:setting:->setting' \
    '3:language:->language'
  case $state in
    setting)
      if [[ ${line[1]-} == config ]]; then compadd -- language; fi ;;
    language)
      # Language choices belong only to this setting, never to tool operands.
      if [[ ${line[1]-} == config && ${line[2]-} == language ]]; then
        compadd -- list en zh-CN
      fi ;;
  esac
}

if (( $+functions[compdef] )); then
  compdef _mst mst
fi
