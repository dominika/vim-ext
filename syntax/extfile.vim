if exists("b:current_syntax")
  finish
endif

syn match ExTpath /^.\{-}:/
syn match ExTLineNo /\d\+/
hi def link ExTpath Label
hi def link ExTLineNo Special
hi def link ExTsearch Type

let b:current_syntax = "extfile"
