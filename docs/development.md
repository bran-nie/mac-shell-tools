# 开发与维护

## 源码边界

| 路径 | 职责 |
| --- | --- |
| `VERSION` | 管理器及整包的发布版本 |
| `tools/<名称>/VERSION` | 工具独立的语义版本 |
| `tools/<名称>/package.meta` | 生成的工具版本、来源提交、状态及组件摘要 |
| `tools/<名称>/<名称>.zsh` | 工具函数、参数校验和补全 |
| `tools/<名称>/locales/` | 工具自己的英文及中文文案 |
| `tools/init.zsh` | 由 loader 模板和工具清单生成的显式加载入口，不手动编辑 |
| `scripts/loader.zsh.in` | 源码入口的共享加载逻辑；安装时仍按选择渲染管理区 |
| `lib/mst.zsh` | 任意目录可用的 Zsh 管理函数，定位已安装启动器 |
| `lib/i18n.sh`、`locales/` | 纯数据配置读取、语言选择和管理器文案 |
| `scripts/tools.list` | 可用工具文件名，不含保留的 init.zsh 和 mst.zsh |
| `lib/manager.sh` | 引导与常驻管理器共用的 POSIX sh 实现 |
| `lib/repository.sh` | 独立工具仓库同步、组件渲染及在线资源安装 |
| `scripts/bootstrap.sh.in` | 定位本地源码或下载源码归档，委托共享管理器 |
| `scripts/build-installer.sh` | 生成轻量引导及纯数据来源记录，不嵌入工具 |
| `install.sh` | 轻量引导生成产物，不手动修改 |
| `package.meta` | 四行纯数据：版本、来源提交、源码状态、摘要 |
| `tests/core/`、`tests/fixtures/` | 公共能力测试及固定的合成工具包，不复制真实工具目录 |
| `tests/tools/<名称>/` | 自动发现的工具行为、补全及可选安装测试 |
| `scripts/ci/` | 变更规划、隔离执行、计时报告及结果汇总 |
| `docs/tools/<名称>/` | 每个工具独立的英文及中文文档 |

普通工具安装、查询和卸载不需要网络；源码同步使用系统 curl 和 tar。在线工具只在安装或更新时下载其声明的额外资源。工具使用系统命令：dsize 依赖 du/sort，树形输出使用 awk，--flat 使用 tail；portwho 依赖 lsof，extract 按格式依赖 tar 或支持 ZipInfo 的 unzip；npmg 需要当前 PATH 中的 Node 和 npm，实际包操作沿用 npm 的联网行为。完整测试额外使用 Python 3 创建回环监听及压缩包边界用例，使用 zip 创建加密测试包，两者不是工具运行依赖。npmg 契约测试使用隔离替身，不要求机器已安装 Node/npm。

## 修改与生成

修改运行时源码、语言包、版本、清单、许可或生成脚本后执行：

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

只检查产物是否同步：

```sh
sh scripts/build-installer.sh --check
```

生成过程使用基础 Shell 工具，SHA-256 优先使用 sha256sum，缺少时使用 shasum；同一次构建批量计算每个唯一输入文件的摘要，整包及工具摘要复用这些结果，保持原有顺序及摘要格式；下次构建重新读取所有输入，不跨构建缓存可变样例。安装后的运行时不需要这两个构建命令。不嵌入时间或绝对机器路径。源码相同时，常规构建复用已记录的提交来源，结果可重复。检查使用同一来源重新生成并比较全部内容，发布生成产物后的新提交不会让检查误报过期。

工具清单每行一个 .zsh 文件名，标识以小写字母或数字开头，仅允许小写字母、数字和连字符。不放注释、重复项、路径或保留文件名。生成器使用运行时解析器校验工具清单、组件版本、安装方式和在线资源清单，并检查引导脚本语法；提交时包含同步生成的 install.sh、tools/init.zsh、根 package.meta 和各工具的 package.meta。新增工具只改变来源记录，不增加引导逻辑或源码载荷。

## 版本与发布

根目录 VERSION 控制管理器及整包版本；每个工具的 tools/<名称>/VERSION 独立控制该工具的版本，当前均为 `0.1.0-dev`。采用 MAJOR.MINOR.PATCH：正式稳定版本的破坏性接口变更提升主版本，兼容功能增加提升次版本，修复提升修订号。开发阶段保留 -dev；首次正式发布使用 0.1.0，后续 0.x 的不兼容调整提升次版本并说明。发布工具时只修改受影响工具的 VERSION。

开发包附加 12 位源码摘要，例如 `0.1.0-dev+0123456789ab`，涵盖受控运行时源码、版本、清单、生成脚本和许可。包头记录完整摘要、来源 Git 提交及 clean / modified / unknown 状态。工具版本常量在同步到本地工具仓库时替换，以便 --version 表示当前已加载的函数，而非磁盘上可能已经更新的文件。源码直接加载显示 `development (unbuilt; unknown)`。

每个工具的摘要独立计算，包含自身 VERSION、Zsh 脚本、语言包、dependencies.list、install.mode、downloads.list、随包 LICENSE，以及有语言包时分发的 lib/i18n.sh。根 VERSION、管理器、其他工具、文档、测试及生成的元数据不参与工具摘要。因此新增 npmg 不改变 dsize 的版本；修改共享 i18n 运行文件会改变所有使用它的工具版本。各 tools/<名称>/package.meta 同样是四行纯数据，安装时读取对应记录，普通安装不需要 Git 或摘要计算工具。

普通开发构建如实标记尚未提交的源码；工具状态仅检查其摘要输入文件。`--refresh-revision` 显式刷新整包来源及尚未确认提交的工具来源；已记录 clean 且内容未变的工具保留原来源提交。没有 Git 信息且没有可复用记录时标记 unknown。来源提交是构建依据的源码快照，可以早于生成安装包的发布提交，不冒充后者。

正式发布步骤：

1. 更新整包及受影响工具的 VERSION 为各自的目标版本，整理更新记录，构建并完成目标平台门禁。
2. 提交受控源码，确保这些源文件干净；生成产物可以留到下一步提交。
3. 执行 `sh scripts/build-installer.sh --refresh-revision`，再次运行门禁，核对包头的版本、来源提交和 clean 状态。
4. 提交生成的 install.sh、根 package.meta 和 tools/*/package.meta，为整包发布提交打 vX.Y.Z 标签并发布。随后将对应 VERSION 改为下一版本的 -dev。生成脚本不自动提交、打标签或推送。

`manager/version` 与 `tools/<名称>/version` 各保存三行：组件版本、来源提交、源码状态。`tools/installed.list` 每行以 Tab 分隔记录工具文件名和上述三项，未知来源写 unknown。旧安装的整包版本记录继续保留，只有显式安装或更新该工具时才切换成独立工具版本，不在 list 或 upgrade 时改写安装记录。

mst upgrade 不改工具版本；mst update 更新工具源码、版本和配套语言包。mst list 的可用版本来自 repository/tools/<名称>/version，与管理器版本独立；在线同步获取 main 的源码快照，不按版本比较选取发布。

## 语言包

语言标识为 en 与 zh-CN，默认英文。管理器文案在根 locales/，工具文案在 tools/<名称>/locales/。使用固定消息键和 printf 参数，不拼接执行文案，不使用 eval。新增文案同步两种语言的键及格式参数；中文缺键时回退英文。

lib/i18n.sh 按纯文本读取根 config.conf 的 language=en|zh-CN，不 source 配置。命令每次调用读取偏好，不缓存到父 Shell，因此语言切换不需要重新 source。管理器优先级为 --lang、MST_LANG、保存的偏好、英文；工具支持环境覆盖及保存的偏好。

管理器引导读取源码目录的独立语言包，安装后读取 manager/locales/。每个工具保存自己的共享帮助函数及语言包副本，随工具更新，避免管理器升级破坏旧工具的消息键。只翻译帮助、错误、状态及补全说明；数据、参数、工具标识及版本保持一致。

## 新增工具

1. 新建 tools/<名称>/<名称>.zsh 和单行 tools/<名称>/VERSION，定义函数和补全；内部函数使用项目及工具前缀。帮助与错误放入组件的 locales/en.sh 和 locales/zh-CN.sh，使用共享 i18n 接口。
2. 将文件名加入 scripts/tools.list；生成器从 scripts/loader.zsh.in 生成 tools/init.zsh 的显式注册，不 glob 执行目录中的脚本。
3. 运行 sh scripts/build-installer.sh，同步 tools/init.zsh、install.sh、根 package.meta 和 tools/*/package.meta。同源码快照中的脚本、语言包及许可在同步时渲染成 repository/tools/<名称>/ 下的独立组件。
4. 添加 tests/tools/<名称>/behavior.zsh 和 completion.zsh；需要专门的安装用例时添加 install.sh。补全用例调用共享 expect_completion / read_until / set_language，不实现另一套 PTY 驱动。添加工具独立的双语 README；根 README 表格只添加名称、简介和链接。CI 自动发现目录，不再修改工作流或公共测试列表。
5. 在工具声明支持的平台上运行完整门禁，确认 BSD / GNU 命令参数与行为。用户通过 mst upgrade 获取新工具目录，再按需 mst install <名称>。

源码入口用于直接加载，安装器根据目标机器清单渲染，不会全量启用。管理测试使用 sample、second、third、dependent 组成的固定合成包，按用例裁剪或增添替身，验证选择安装、迁移和独立版本。真实工具分别执行通用安装契约，并通过完整目录的加载冒烟检查验证组合。工具默认仅定义函数并注册必要补全；npmg 额外在加载时读取纯文本 npmg.conf，去重追加生效 prefix 的 bin 目录到 PATH，保留当前 Node/npm 优先级，不创建目录或持久化 npm 自身配置。配置命令保存独立 prefix 并同步当前 PATH，配置及 npm 包不纳入工具卸载资源。source 时不扫描磁盘、不联网、不输出启动信息、不运行 compinit、不改变调用者的选项或工作目录；补全不执行工具后端或联网查询，仅在请求目录/文件补全时遍历对应路径。共享入口在交互式 Zsh 缺少 compdef 时运行标准 compinit；已有补全系统及非交互加载均跳过初始化。

aliases 额外在 source 时注册 ll/duls 默认别名，跳过已有同名 alias/函数；可选的 aliases.conf 仅保存个人文件路径。只有用户明确选择的个人 Zsh 文件才会执行，启动静默，不自动查找 dotfiles。个人文件先于默认别名加载；跟踪普通 alias 和函数的实际变更，重载按所有权恢复/撤销，保留会话内后续手动修改。个人脚本的变量、目录、钩子、全局/后缀别名等副作用不在回滚范围。配置路径文件不执行，个人文件是有意 source 的代码，两者契约见 [aliases 文档](tools/aliases/README-cn.md)。

## 分发与本地工具仓库

工具可以用 `tools/<名称>/dependencies.list` 声明安装及更新前置命令，每行一个命令名，允许字母、数字、下划线和连字符，必须以字母或数字开头；不允许空行、重复项、参数或路径。声明作为纯数据校验并参与源码摘要，随组件复制并登记所有权，不执行安装钩子。安装器在写入前检查选中工具的命令是否可从当前 PATH 找到；多个工具及全量安装在缺少依赖时整体停止。同步目录、查询及卸载不检查这些命令。npmg 声明 node 与 npm，运行包操作时也会重新检查。

`install.sh` 只包含引导、下载和归档预检。远端执行时获取一个完整源码快照，在临时目录加载 `lib/manager.sh`；完整仓库本地执行时直接使用独立源文件。保留旧引导标记，使已经发布的管理器仍可通过 `mst upgrade` 升级。引导和常驻管理器都不内嵌工具源码。

同步写入 `repository/catalog.tsv` 和 `repository/tools/<名称>/`，清单每行是工具文件名及安装方式（Tab 分隔）。组件拥有独立 `version`、`files.list`、语言包和 LICENSE。本地仓库缺失时可通过 mst upgrade 重新同步，卸载仍依据独立的安装记录工作。普通工具默认采用 `local` 安装方式，`mst install` 只从本地仓库复制并登记。`mst upgrade` 更新管理器及工具仓库，保留已安装文件和记录；`mst update` 先同步仓库，再更新选中的已安装组件，保留管理器。可用版本因此可以高于管理器版本。目录清单在其组件写入后发布，移除的受管资源会备份并清理，个人文件保留。

需要额外下载资源时，在该工具目录添加单行 `install.mode`，内容为 `online`，并提供 `downloads.list`。每行四列，以 Tab 分隔：

```text
bin/client<TAB>https://example.org/client<TAB>64位小写SHA-256<TAB>executable
assets/data<TAB>https://example.org/data<TAB>64位小写SHA-256<TAB>file
```

资源只允许 HTTPS，路径为组件内的安全相对路径；类型显式使用 `file` 或 `executable`。不能覆盖组件已有文件、脚本、文件清单或版本记录。安装先下载至暂存目录并校验 SHA-256，全部完成后才进入目标预检及写入；下载文件纳入组件所有权清单，更新与卸载一并处理。不执行安装钩子。同步仅保存声明，不下载在线资源。普通脚本的运行时联网行为不需要声明为在线安装。

## 安装配置契约

支持 Darwin 和 Linux；Linux 使用 GNU Coreutils 或兼容命令，运行时依赖 Zsh，在线同步还依赖 curl 和 tar。引导由 POSIX sh 执行，检查 Zsh 是否可用，不以 $SHELL 或引导解释器判断用户当前 Shell，不自动安装系统依赖或修改默认 Shell。

默认根目录为 `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools`。manager/mst.sh 固定解析后的根目录及主配置路径，mst.zsh 根据自身位置找到它。首次引导和下载委托共用实现；.zshrc → init.zsh → manager/mst.zsh，启动时不联网。项目加载入口仅在 Zsh 中执行；交互式加载根据实时 compdef 状态决定是否初始化补全，不检查 Oh My Zsh 目录，不在安装时执行用户配置，重复加载复用已有补全与个人注册。

主配置和入口分别使用唯一且完整的标记：

```text
# >>> mac-shell-tools >>>
# <<< mac-shell-tools <<<

# >>> mac-shell-tools managed tools >>>
# <<< mac-shell-tools managed tools <<<
```

主配置的项目块位于末尾；管理块外内容保留，不搜索删除其他 source 行、函数或别名。无已知管理标记的现存入口不自动覆盖。只有显式 install 不带工具名时才全量安装，不带参数的引导仅安装管理器。

安装顺序为准备及语法检查 → 目标预检 → 管理器（需要时）→ 选中工具组件 → 入口 → 主配置 → 清单。管理器升级跳过工具和清单写入。卸载先移除注册，再备份及删除已登记的组件文件，最后更新或删除清单；保留 mst、共享入口、主配置引用及个人文件。

备份集中在根 backups/，镜像组件相对路径，主配置放 backups/zshrc/，迁移文件放 backups/legacy/；名称含时间及随机后缀。每个文件通过同目录暂存后重命名，保留已有权限。操作不是跨文件事务，中途失败修复报错后重试或配套恢复备份。受管理文件和组件子目录链接直接拒绝，根目录之上的父目录链接通过物理路径定位保留。

原 zsh/tools 安装使用双锁和迁移状态记录升级。只迁移清单或精确注册中的工具，保留字节并标记未知版本；个人入口留在原路径供新入口引用。旧启动器转发到新管理器，原文件及旧备份不自动删除。迁移完成记录最后写入，中断后可重试。

安装清单、资源清单和语言偏好都作为数据校验，不执行。自动会话仅在有文件变更且 stdin/stdout 都为终端时启动；语言配置、查询和帮助不启动新会话。启动新 Zsh 前必须清理暂存和本进程的锁。完整用户契约见[安装说明](installation-cn.md)。

## 验证门禁

`sh scripts/check.sh` 检查语法、生成产物一致性，并在当前 macOS 或 Linux 的隔离环境运行：

- dsize：真实磁盘占用的树形结构、同级排序及行数截取，--flat 的平台原生 BSD / GNU 管道结果，以及参数和路径矩阵、权限、阶段失败、中断、加载及调用隔离。
- portwho：测试自有的本地回环 TCP/UDP 套接字、多个端口、数字边界、权限提示、底层失败及中断，不访问远程网络。
- extract：ZIP 与 TAR/gzip/bzip2/xz 实际解压、预览、中文空格路径、拒绝覆盖、越界与链接条目、快照清理、失败保留及环境隔离。
- npmg：快捷安装与子命令、简写、参数边界与默认覆盖顺序、npm 输出/退出码/标准输入、运行时依赖、PATH 去重与优先级；安装依赖声明及缺少依赖时批量安装无写入。
- aliases：内置/个人优先级、alias/函数归属、重复加载、删除与恢复、会话手动修改保留、加载失败回滚、纯数据路径配置、真实 Tab，以及固定配置位置和卸载保留。
- install：首次与重复安装、备份、用户内容保留、路径转义、链接及权限、写入失败恢复、独立文件及 stdin 分发。
- management：双工具包中的选择安装、更新与卸载、清单校验、缺失修复、资源归属及个人文件保护。
- mst：任意目录入口、默认仅管理器、模拟在线发布、更新与升级分离、无效下载保留文件、固定自定义路径。
- package：每个真实工具与一个合成同伴组成小包，验证选择/全量安装、资源与所有权、版本、已加载函数语言切换、环境优先级、缺失翻译回退、拒绝可执行配置、重载前后的版本、逐项/全量卸载，保留个人文件及管理器。
- repository：轻量引导大小、源码与启用版本隔离、普通工具离线重装、在线资源及校验失败、可执行权限、废弃资源清理和不安全归档拒绝。
- versions-language：版本来源和独立记录、加载版本与磁盘版本、构建及发布可重复性、语言切换、优先级、回退、纯数据配置。消息键和格式参数一致性在 base 静态检查中覆盖所有真实语言包。
- tool-versions：新增工具及管理器变更不改变已有工具版本、独立脚本和依赖更新、共享运行文件变更、旧记录过渡及工具元数据校验。
- migration：原目录、原清单和旧会话兼容、自定义路径、不可用工具、相对个人引用、双锁、中断及恢复、冲突与缺失保护。
- platform：模拟系统标识验证允许及拒绝分支、Bash 启动与加载边界、缺少 Zsh 时不写配置、非交互加载不初始化补全。模拟标识不代替真实 Linux 验证。
- completion：裸 Zsh 中共享入口自动初始化后的真实 Tab 编辑缓冲区、双语说明、版本选项、数值及等号、顺序、分隔符、目录限定及不扫描。
- sessions：真实伪终端中新登录 Zsh、补全自动初始化及已有补全复用、个人注册保留、重复加载、固定 ZDOTDIR、锁和暂存清理、禁用参数、语言配置不启动会话、管道及输出重定向。

测试不指向真实 HOME，下载使用本地 curl 替身，不安装远端代码。文件身份使用按平台选择的 BSD / GNU stat 参数；补全使用各平台 Zsh 自带的 fpath。可绕过权限的身份下会明确输出权限用例 SKIP，受控失败仍执行。普通 PR 与 main 推送使用 macOS runner；手动、发布和每周全量检查同时运行 macOS 与 Ubuntu。真实平台结果分别记录，不以模拟 uname 或 macOS 结果宣称 Ubuntu 实测通过。

## 按影响范围运行 CI

工作流始终触发，在工作流内部选择任务。顺序是 `plan → base → 并行测试 → ci-result`。base 始终检查语法、生成产物、组件/测试目录约定、双语文案、文档链接及 CI 规划器的回归用例；这里没有真实工具业务调用。

| 变更 | 行为检查范围 |
| --- | --- |
| README、docs、CHANGELOG | base，不执行行为测试 |
| tools/<名称>/ 源码或 tests/tools/<名称>/ | 对应工具的行为、补全、安装契约及可选安装测试，加全部工具的快速加载冒烟 |
| 新增工具或从清单删除工具 | 新工具自身测试、公共管理/分发/会话测试、真实组件安装契约及加载冒烟；其他工具不重跑业务用例 |
| 根 locales/ | 管理器语言及补全测试 |
| lib/manager.sh、lib/repository.sh、lib/mst.zsh | 公共能力、真实组件安装契约及加载冒烟 |
| lib/i18n.sh、加载模板、构建/引导、共享测试设施、CI、未知路径 | 保守全量 |
| 只改变生成文件 | base 重新生成并逐字比较，手动改坏产物同样失败 |
| 手动、release 发布、每周一 03:17 UTC | macOS 和 Ubuntu 全量 |

工具版本是否变化不参与选测。PR 使用完整合并基线到本次测试提交的差异；main 推送使用本工作流最近一次成功且属于当前历史的 main 提交作为基线，覆盖其后的所有提交，包括源码提交和单独的来源记录提交。API 不可用、基线不存在、历史不可用时执行全量。重命名保留新旧两个路径，删除也参与规划。PR 新运行取消旧运行；main 不主动取消进行中的运行。

公共能力拆成 manager、distribution、language、sessions 四组，每个真实工具一个任务，最多同时运行四个任务。短小用例在组内执行，共享组内固定样例，避免为每个断言启动 runner。新增工具会增加自己的测试任务，公共能力用例的假工具数量保持固定。

`ci-result` 是稳定的最终检查名，适合设置为分支保护的必需检查。它校验 plan/base/矩阵结果、每个预期任务和每个预期测试套件的报告；失败、取消、报告缺失、重复、旧提交报告和意外 skipped 都不能得到成功。文档变更只允许计划内的矩阵跳过，base 仍必须成功。

本地入口：

```sh
# 完整验证
sh scripts/check.sh
# 一种工具，附带 base 和快速加载检查
sh scripts/check.sh --tool npmg
# 只运行指定公共能力组
sh scripts/check.sh --target language
# 检查已提交的完整变更范围，再执行该计划
python3 scripts/ci/plan.py --base <已验证提交> --head HEAD --output .artifacts/plan.json
sh scripts/check.sh --plan .artifacts/plan.json
```

报告默认写入 `.artifacts/<平台>-<任务>/`，每个套件保留完整输出、耗时和退出码；PTY 用例另存 terminal.log。CI 同时把失败上下文放入错误注释和步骤摘要，并保存报告及选测计划 14 天。单套件有超时，超时终止该套件的进程组并记为失败，不重试掩盖故障。语言状态列是 ASCII 协议字段，解析使用 C locale，避免 macOS awk 在 en_US.UTF-8 下把中文标题与星号比较为相等；展示文案仍按用户选择的语言输出。

## 人工终端检查

在隔离配置中确认安装后进入新 Zsh，mst list 可用且无工具；选择安装后检查 dsize --help 和 --version。切换中英文，检查帮助、错误和补全说明。尝试带空格与中文的路径、重复选项、等号及 --，确认个人补全主题兼容。

不用修改项目之外的配置；可在隔离 HOME 的交互式 Zsh 中 source tools/init.zsh，分别检查裸 Zsh 和已初始化补全的配置。
