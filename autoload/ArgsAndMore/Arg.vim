" ArgsAndMore/Arg.vim: Commands around arguments.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2019-2026 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ArgsAndMore#Arg#Merge( count, filePatternsString ) abort
    let l:filespecs = map(
    \   (empty(a:filePatternsString)
    \       ? [expand('%')]
    \       : ingo#collections#Flatten1(
    \           map(
    \               ingo#cmdargs#file#SplitAndUnescape(a:filePatternsString),
    \               'glob(v:val, 0, 1)'
    \           )
    \       )
    \   ), 'ingo#fs#path#Canonicalize(v:val, 1)'
    \)

    let l:argumentFilespecs = ingo#collections#ToDict(map(argv(), 'ingo#fs#path#Canonicalize(v:val, 1)'))
    let l:newFilespecs = filter(l:filespecs, '! has_key(l:argumentFilespecs, v:val)')

    if empty(l:newFilespecs)
	call ingo#err#Set(printf('No new file%s', (len(l:filespecs) == 1 ? '' : 's')))
	return 0
    endif

    try
	execute a:count . 'argadd' join(map(l:newFilespecs, 'ingo#compat#fnameescape(v:val)'))
	echomsg printf('Added %d new file%s', len(l:newFilespecs), (len(l:newFilespecs) == 1 ? '' : 's'))
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

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

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
