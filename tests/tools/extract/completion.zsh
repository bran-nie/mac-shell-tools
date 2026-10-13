# Real Tab cases, sourced by tests/helpers/completion.zsh.
expect_completion 解压帮助 'extract --he' 'extract --help '
expect_completion 解压版本 'extract --ver' 'extract --version '
expect_completion 解压预览 'extract --li' 'extract --list '
expect_completion 空格压缩包 'extract bun' 'extract bundle\ file.zip '
expect_completion 中文压缩包 'extract 归' 'extract 归档.ZIP '
expect_completion 解压目标目录 'extract -C sp' 'extract -C space\ directory/'
expect_completion 解压长目标目录 'extract --directory=sp' 'extract --directory=space\ directory/'
expect_completion 解压分隔符 'extract -- -bun' 'extract -- -bundle.tgz '
expect_completion 不补全第二压缩包 'extract sample.zip bun' 'extract sample.zip bun'
set_language zh-CN
expect_completion 中文解压选项 'extract -' 'extract -'
read_until "预览压缩包内容"
read_until "新的目标目录"
