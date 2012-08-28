if exists("b:current_syntax")
  finish
endif

syn match ExTid /[0-9]*/
syn match ExTstatus /[a-z]*$/
syn match ExTcmd / [a-z]* /
hi def link ExTid Label
hi def link ExTstatus Special
hi def link ExTcmd Type

let b:current_syntax = "extlist"
