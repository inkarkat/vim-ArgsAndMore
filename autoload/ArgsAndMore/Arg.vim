" ArgsAndMore/Arg.vim: Commands around arguments.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ArgsAndMore#Arg#Drop( bang, count ) abort
    let l:argIndex = argidx()
    if argv(l:argIndex) !=# expand('%') && empty(a:bang)
	call ingo#err#Set('Not editing a file from the argument list (add ! to force)')
	return 0
    endif

    try
	execute '.' . (a:count > 1 ? ',.+' . (a:count - 1) : '') . 'argdelete'
	execute (l:argIndex + 1) . 'argument' . a:bang
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
