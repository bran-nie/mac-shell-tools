# Real Tab cases, sourced by tests/helpers/completion.zsh.
expect_completion 端口帮助 'portwho --he' 'portwho --help '
expect_completion 端口版本 'portwho --ver' 'portwho --version '
expect_completion 端口数值 'portwho 443' 'portwho 443 '
expect_completion 多个端口 'portwho 80 443' 'portwho 80 443 '
expect_completion 端口不补全目录 'portwho sp' 'portwho sp'
