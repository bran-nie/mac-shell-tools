# Real Tab cases, sourced by tests/helpers/completion.zsh.
expect_completion 空格目录 'dsize sp' 'dsize space\ directory/'
expect_completion 中文目录 'dsize 中' 'dsize 中文目录/'
expect_completion 选项先于目录 'dsize -n 25 sp' 'dsize -n 25 space\ directory/'
expect_completion 帮助长选项 'dsize --he' 'dsize --help '
expect_completion 帮助短选项 'dsize -h' 'dsize -h '
expect_completion 版本长选项 'dsize --ver' 'dsize --version '
expect_completion 版本短选项 'dsize -V' 'dsize -V '
expect_completion 深度短选项 'dsize -d' 'dsize -d '
expect_completion 条数短选项 'dsize -n' 'dsize -n '
expect_completion 深度长选项 'dsize --dep' 'dsize --depth=' 'dsize --depth '
expect_completion 条数长选项 'dsize --li' 'dsize --lines=' 'dsize --lines '
expect_completion 深度短选项值 'dsize -d 5' 'dsize -d 5 '
expect_completion 条数短选项值 'dsize -n 100' 'dsize -n 100 '
expect_completion 深度等号 'dsize --depth=5' 'dsize --depth=5 '
expect_completion 条数等号 'dsize --lines=100' 'dsize --lines=100 '
expect_completion 长选项独立值 'dsize --depth 5' 'dsize --depth 5 '
expect_completion 目录先于选项 'dsize ordinary --lines=100' 'dsize ordinary --lines=100 '
expect_completion 重复短选项 'dsize -d 2 -d 5' 'dsize -d 2 -d 5 '
expect_completion 重复长选项 'dsize --depth=2 --depth=5' 'dsize --depth=2 --depth=5 '
expect_completion 分隔符目录 'dsize -- -da' 'dsize -- -dashdir/'
expect_completion 数值不当目录 'dsize -d sp' 'dsize -d sp'
expect_completion 不补全第二目录 'dsize ordinary sp' 'dsize ordinary sp'
expect_completion 英文选项列表 'dsize -' 'dsize -'
read_until "Show help"
read_until "Maximum lines, default 25"
set_language zh-CN
expect_completion 中文选项列表 'dsize -' 'dsize -'
read_until "显示帮助"
read_until "25"
expect_completion 中文目录补全 'dsize sp' 'dsize space\ directory/'
