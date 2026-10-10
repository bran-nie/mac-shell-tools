# mac-shell-tools 集中入口。
# 管理区域显式注册工具；其他区域由用户维护，更新时保留。

# >>> mac-shell-tools managed tools >>>
if [ -z "${ZSH_VERSION-}" ]; then return 0; fi
() {
  emulate -L zsh
  # Reuse completion initialized by Oh My Zsh or another Zsh configuration.
  if [[ -o interactive ]] && (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
  fi
  local mac_shell_tools_directory=${${(%):-%x}:A:h}
  if [[ -f "$mac_shell_tools_directory/manager/mst.zsh" ]]; then
    source "$mac_shell_tools_directory/manager/mst.zsh"
  fi
  if [[ -f "$mac_shell_tools_directory/tools/dsize/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/tools/dsize/dsize.zsh"
  elif [[ -f "$mac_shell_tools_directory/dsize/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/dsize/dsize.zsh"
  fi
}
# <<< mac-shell-tools managed tools <<<

# 用户自定义区域：可在此添加其他工具引用和注释。
# 定位此入口所在目录可使用 ${${(%):-%x}:A:h}，不要依赖当前工作目录。
