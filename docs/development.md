# 开发与维护

## 源码边界

| 路径 | 职责 |
| --- | --- |
| `tools/dsize.zsh` | 统计函数、帮助、参数校验和独立补全 |
| `tools/init.zsh` | 使用自身位置显式注册工具；管理区之外允许用户自定义 |
| `scripts/tools.list` | 生成安装器时打包及安装的工具文件名，不包含 `init.zsh` |
| `scripts/installer.sh.in` | POSIX sh 安装、合并、备份及失败处理 |
| `scripts/build-installer.sh` | 合并安装逻辑与运行时代码，生成单文件安装器 |
| `install.sh` | 可独立分发的生成产物，不手动编辑内嵌实现 |
| `tests/` | 不依赖额外测试框架的 macOS 隔离行为检查 |

运行时没有包管理器、构建运行时或网络依赖。不新增其他工具或通用插件协议，直到出现明确需求。许可证由仓库所有者决定。

## 修改与生成

修改 `tools/` 中的唯一工具源码或安装模板后执行：

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

只检查产物是否同步：

```sh
sh scripts/build-installer.sh --check
```

生成过程只使用基础 Shell 工具，无时间或机器信息，因此结果可重复。清单中使用每行一个 `.zsh` 简单文件名，不放注释、重复项或路径。提交时同时包含源码及生成的 `install.sh`。

## 新增工具

1. 在 `tools/` 新建独立文件，例如 `git-tools.zsh`，包含自己的函数、帮助和补全，内部函数用项目及工具前缀避免重名。
2. 在 `init.zsh` 的管理区域显式 source，并检查文件存在。不要 glob 执行目录中的所有 `.zsh`。
3. 将文件名加入 `scripts/tools.list`，重新生成 `install.sh`。
4. 增加实际行为检查，同步英文 `README.md` 和中文 `README-cn.md`。
5. 在真实 macOS 上运行完整门禁。用户重复安装后通过同一集中入口加载新工具，不再增加 `.zshrc` 引用。

工具只做函数定义和必要补全注册。不要在 source 或补全中扫描磁盘、联网、输出启动信息、运行 `compinit` 或更改调用者的选项及工作目录。

## 安装配置契约

主配置管理标记：

```text
# >>> mac-shell-tools >>>
# <<< mac-shell-tools <<<
```

集中入口工具管理标记：

```text
# >>> mac-shell-tools managed tools >>>
# <<< mac-shell-tools managed tools <<<
```

标记要求每对唯一且顺序完整。无管理标记的已有入口不能自动覆盖。入口自定义区域保持；主配置只重置项目块并放在末尾，不搜索删除其他 source 行或函数。

安装顺序为全部暂存与语法检查 → 所有目标预检 → 工具 → 入口 → 主配置。写入前备份，备份名称用时间加随机后缀；逐文件同目录暂存后重命名，保留已有文件权限。安装不是跨文件事务；中途失败按报错修复后重试或恢复备份。文件符号链接和最终工具目录符号链接直接拒绝，父目录链接通过物理目录定位保留。并发锁只保护同一工具目录。

## 验证门禁

`sh scripts/check.sh` 在 macOS 上执行：

- POSIX sh 与 Zsh 语法检查，生成产物一致性。
- `tests/dsize.zsh`：实际 BSD 命令结果比对、参数和路径矩阵、部分扫描、各管道阶段失败、中断、加载和调用隔离。
- `tests/install.sh`：临时 HOME 中的首次及重复安装、升级与恢复、同时间戳备份、用户区域、引号及中文路径、类型及权限错误、符号链接和单文件/stdin 分发。
- `tests/completion.zsh`：系统 Zsh、`compinit` 和 `zpty` 中真实按 Tab，验证编辑缓冲区、选项数值、等号、参数顺序、`--`、无第二目录和无扫描。

配置验证绝不指向真实 HOME。权限验证在可绕过权限的身份下会明确输出 SKIP；受控 du 失败检查仍执行。CI 使用 macOS runner；不以 Linux 通过替代 BSD 平台证据。

## 人工终端检查

自动化覆盖语义，以下项目用于检查个人终端和 Oh My Zsh 插件的显示及兼容性：

1. 安装后重新打开终端；确认 `dsize --help` 可用，无无关启动输出。
2. 输入 `dsize -` 后按 Tab，查看短、长及帮助选项；分别对 `-d `、`-n `、`--depth=` 和 `--lines=` 查看候选及提示文字。
3. 对带空格或中文的目录按 Tab；交换选项和目录位置，并尝试 `dsize -- ./-`。
4. 确认个人补全主题和菜单显示正常，重复 source 能刷新定义；有同名函数时检查自定义加载顺序。

不用为了人工检查而修改项目之外的配置；可在独立 Zsh 中先初始化补全，再 source `tools/init.zsh`。
