" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ArgsAndMore#AfterExecute()
    execute g:ArgsAndMore_AfterCommand
endfunction
function! s:Execute( command )
    try
	execute a:command
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#msg#VimExceptionMsg()
    catch
	call ingo#msg#ErrorMsg(v:exception)    " Anything else.
    endtry

    call ArgsAndMore#AfterExecute()
endfunction

function! ArgsAndMore#Windo( range, command )
    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
	let l:originalWinNr = winnr()
	let l:previousWinNr = winnr('#') ? winnr('#') : 1
	    execute 'keepjumps' a:range 'windo call s:Execute(a:command)'
	execute l:previousWinNr . 'wincmd w'
	execute l:originalWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ArgsAndMore#Winbufdo( range, command )
    let l:buffers = []

    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
	let l:originalWinNr = winnr()
	let l:previousWinNr = winnr('#') ? winnr('#') : 1

	    execute 'keepjumps' a:range 'windo'
	    \   'if index(l:buffers, bufnr('')) == -1 |'
	    \       'call add(l:buffers, bufnr('')) |'
	    \       'call s:Execute(a:command)'
	    \   'endif'

	execute l:previousWinNr . 'wincmd w'
	execute l:originalWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ArgsAndMore#Tabdo( range, command )
    let l:originalTabNr = tabpagenr()
	execute 'keepjumps' a:range 'tabdo call s:Execute(a:command)'
    execute l:originalTabNr . 'tabnext'
endfunction

function! ArgsAndMore#Tabwindo( range, command )
    let l:originalTabNr = tabpagenr()
	execute 'keepjumps' a:range 'tabdo call ArgsAndMore#Windo("", a:command)'
    execute l:originalTabNr . 'tabnext'
endfunction



function! ArgsAndMore#ConfirmResetChoice()
    let s:choice = ''
endfunction
function! ArgsAndMore#ConfirmedUpdate()
    if ! &l:modified
	return
    endif

    if s:choice !=# 'a'
	redraw
	let s:choice = ingo#query#substitute#Get('Write changes')
    endif

    if s:choice =~# '[yla]'
	update

	if s:choice ==# 'l'
	    throw 'ArgsAndMore: Aborted'
	elseif s:choice ==# 'a'
	    " All subsequent invocations are automatically accepted.
	endif
    elseif s:choice ==# 'n'
	" Do nothing here.
    elseif s:choice ==# 'q'
	throw 'ArgsAndMore: Aborted'
    else
	throw 'ASSERT: Invalid choice: ' . s:choice
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
