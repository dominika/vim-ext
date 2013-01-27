" exttask.vim - 
" Author:   Dominika Stempniewicz
" Version:  0.9.0
" 

if exists('g:loaded_exttask') || &cp || v:version < 703 "version > 7.3 -> dict in viminfo
  finish
endif
let g:loaded_exttask= 1

if !exists('g:EXTTASKS')
  "TODO: watch out for viminfo += !
  let g:EXTTASKS = {}
endif

" extwnds
" {{{
if !exists('s:EXTWNDS')
  let s:EXTWNDS = { 
  \ 'tasks': 
  \   {'name': 'ExT', 'split': 'botright split','filetype': 'list'}, 
  \ 'files': 
  \   {'name': 'task', 'split': 'botright split','filetype': 'file'}
  \}
endif
"}}}

" ExTBind
" {{{
function! ExTBind(cmd,...)
  let opts = extend({'exclusive': 0,'highlight': "",'autowatch': 0, 'hidelist':0}, a:0 > 0 ? a:1 : {})

  let found = s:findTaskId(opts['exclusive'] == 1 ? substitute(a:cmd,' .*$','','g') : a:cmd)
  if found != -1
    call s:showTask(found)
  else 
    call s:createTask(a:cmd, filter(opts, "index(['highlight','autowatch','hidelist'], v:key) != -1"))
  endif
endfunction
"}}}

" ExTToggle
" {{{
function! ExTToggle()
  if s:focusBuffer('ExT') == -1
    call ExTList()
  else
    q
  endif
endfunction
"}}}

" managing windows
" {{{
function! s:prepareWnd(name,...)
  let wnd = s:EXTWNDS[a:name]

  let prevSplitBelow = &splitbelow
  let &splitbelow = 0

  let opts = extend({'buffer': wnd.name, 'statusline': wnd.name, 'highlight': "", 'autowatch': 0}, a:0 > 0 ? a:1 : {})

  if s:focusBuffer(opts['buffer']) == -1
    let buf_exists = bufexists(opts['buffer'])
    silent! exec wnd.split ." ". opts['buffer']
    if buf_exists == 0
      if opts['autowatch'] > 0
        call s:setAutoWatch(opts['buffer'], opts['autowatch'])
      endif
    endif
  else
    "TODO: au
    call s:runFunctions(["Refocus"], a:name)
  endif

  silent! exec "setlocal filetype=ext".wnd['filetype']
  if opts['highlight'] != ""
    exec "syn match ExTsearch /".opts['highlight']."/"
  endif
  "TODO: statusline
  "let &l:statusline = opts['statusline']
  let &splitbelow = prevSplitBelow
endfunction

function! s:focusBuffer(name)
  let currWnd = bufwinnr(a:name)
  if currWnd != -1
    exec currWnd." wincmd w" 
  endif
  return currWnd
endfunction

function! s:getValue()
  let prevZ = @z
  let @z = ""
  exec "normal! ^\"zyt:"
  let filepath = @z
  let @z = prevZ
  return filepath 
endfunction
"}}}

" managing tasks
" {{{
function! s:getTaskPids(ppid)
  "TODO check command as well, just in case
  let cmd = "ps -eo pid,ppid,command | gawk '/\\y".a:ppid."\\y/ { ii = ii \" \" $1 } END { print ii }'"
  return substitute(system(cmd), '\n','','g')
endfunction

function! s:taskStatus(pid)
  return  (s:getTaskPids(a:pid) == "") ? "done" : "running"
endfunction

function! s:findTaskByBufferName(name)
  let matched = -1
  for [k,v] in items(g:EXTTASKS)
    if (resolve(v.filename) == a:name) == 1
      let matched = k
      break
    endif
  endfor
  return matched
endfunction

function! s:findTaskId(cmd)
  let matched = -1
  for [k,v] in items(g:EXTTASKS)
    if match(v.cmd, a:cmd) != -1
      let matched = k 
      break
    endif
  endfor
  return matched
endfunction

function! ExTExtensionsCompletion(A,L,P)
  "if (!empty(s:extentions))
  return keys(s:extensions)
  "endif
endfunction

function! ExTFilterByExtension()
  let chosen_extension = input("extension: ", "", "customlist,ExTExtensionsCompletion")
  if !empty(chosen_extension)
    undo 1 | undo
    let cmd = "v/\\.".chosen_extension.":\\d/d"
    exec cmd
    normal gg
  endif
endfunction

function! s:showTask(id)
  let task = g:EXTTASKS[a:id]
  call s:prepareWnd("files", {'buffer': task.filename, 'statusline': task.cmd, 'highlight': task.highlight, 'autowatch': task.autowatch})
  let lines = getbufline(bufnr(task.filename), 1, "$") 
  let s:extensions = {}
  for line in lines
    let extension = matchlist(line, '\.\(\w*\):\d')
    if (!empty(extension))
      let old_count = get(s:extensions, extension[1], 0)
      let s:extensions[extension[1]] = old_count+1
    endif
  endfor
endfunction

function! s:delTask(id,...)
  let task = g:EXTTASKS[a:id]
  let pids = s:getTaskPids(task.pid)
  if pids != ""
    call system("kill -9 ".pids)
  endif
  let buf_num = bufnr(task.filename)
  if buf_num != -1
    exe "bd ".buf_num
  endif
  let soft_delete = a:0 > 0 ? 1 : 0
  if soft_delete == 0
    call remove(g:EXTTASKS, a:id)
  endif
  call ExTList()
endfunction

function! s:createTask(cmd, opts)
  let max = max(keys(g:EXTTASKS))+1
  let g:EXTTASKS[max] = extend({'cmd' : a:cmd}, a:opts)
  call s:runTask(max)
endfunction

function! s:refreshTask(id)
  call s:delTask(a:id, 1)
  call s:runTask(a:id)
endfunction

function! s:runTask(id)
  let task = g:EXTTASKS[a:id]
  let tempfile = tempname()
  "if 
    "let output = '/dev/null'
  "else
    let output = tempfile
  "endif
  let task['filename'] = tempfile
  let server_opts = has('clientserver') ?  ("&& (mvim --servername ". v:servername ." --remote-expr \"ExTWrapTaskCmd('s:showTask',". a:id .")\")") : ""
  let cmd = "( ((". task.cmd .") > ". task.filename ." 2>&1 0<&-) ". server_opts ." )& echo $! "
  let pid = substitute(system(cmd), '\n','','g')
  let task['pid'] = pid
  if task.hidelist == 0
    call ExTList()
  endif
endfunction
"}}}

" autowatch
" {{{
function! s:setAutoWatch(buffer, type)
  silent! exec "augroup ExT"
    au!
    au CursorHold * checktime
    au CursorHoldI * checktime
  augroup END
  silent! exec "augroup ExT".a:buffer
    au!
    exec "au FileChangedShell ".a:buffer." :call s:checkAutoWatch()"
    exec "au FileChangedShellPost ".a:buffer." :call s:refreshAutoWatch('".a:buffer."')"
    exec "au BufDelete ".a:buffer." :call s:removeAutoWatch('".a:buffer."')"
  augroup END
endfunction

function! s:removeAutoWatch(buffer)
  exec "silent! au! ExT".a:buffer." | silent! augroup! ExT".a:buffer
endfunction

function! s:checkAutoWatch()
  if v:fcs_reason == 'changed'
    let v:fcs_choice='reload'
  endif
endfunction

function! s:refreshAutoWatch(buffer)
  let v:fcs_choice=""
  let current_window = expand('%')
  if s:focusBuffer(a:buffer) != -1
    normal! G$
    call s:focusBuffer(current_window)
  endif
endfunction
"}}}

" tasks window setup
" {{{
function! ExTList()
  call s:prepareWnd("tasks")

  setlocal modifiable
  silent 1,$d _

  for [k,v] in items(g:EXTTASKS)
    call append(0, k.": ".v.cmd." ".s:taskStatus(v.pid))
  endfor

  call append(0, "")
  call append(0, "  R   refresh list")
  call append(0, "  r   refresh task")
  call append(0, "  dd  delete task")
  call append(0, "  ^M  open results")
  call cursor(len(g:EXTTASKS) == 0 ? 5 : 6,1)
  normal! zz
  setlocal nomodifiable
endfunction

function! s:tasksRefocus()
  "TODO
endfunction

function! ExTWrapTaskCmd(f,...)
  let value = a:0 > 0 ? a:1 : s:getValue()
  if (value == "")
    echo "Position yourself on a more sensible line!"
    return
  elseif (index(['s:refreshTask','s:runTask','s:showTask','s:delTask'], a:f) != -1)
    let Fn = function(a:f) 
    call Fn(value)
  endif
endfunction
"}}}

" files window setup
" {{{
function! s:filesRefocus()
  e!
  "normal! G
endfunction
"}}}

" helper functions
" {{{
function! s:runFunctions(fs, prefix)
  for name in a:fs
    let Fn = function("s:".a:prefix.name)
    call Fn()
  endfor
endfunction
"}}}

" mappings
" {{{
command! -nargs=* ExTRun call ExTBind(<args>)
command! -nargs=0 ExTToggle call ExTToggle()
command! -nargs=0 ExTFilterByExtension call ExTFilterByExtension()
"}}}
