nmap <silent> <buffer>  :exec "call ExTWrapTaskCmd('s:showTask')"
nmap <silent> <buffer> dd :exec "call ExTWrapTaskCmd('s:delTask')"
nmap <silent> <buffer> R  :exec "call ExTList()"
nmap <silent> <buffer> r  :exec "call ExTWrapTaskCmd('s:refreshTask')"

setlocal cursorline
setlocal nonumber
setlocal norelativenumber
setlocal nowrap
setlocal nospell
setlocal noswapfile
setlocal buftype=nofile
"setlocal nobuflisted
