" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - ingo/msg.vim autoload script
"   - ingo/query/substitute.vim autoload script
"   - ingo/regexp/fromwildcard.vim autoload script
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.10.022	11-Feb-2015	Factor out ArgsAndMore/Args.vim module.
"   2.10.021	10-Feb-2015	Rename s:ArgExecute() to s:ArgOrBufExecute() to
"				better convey its dual use.
"				Implement :CDo... commands via
"				ArgsAndMore#QuickfixDo().
"   2.00.020	30-Jan-2015	Expose s:Argdo() and add a:range argument for
"				the :Argdo variant that can use the
"				-addr=arguments attribute.
"				ArgsAndMore#ArgdoWrapper() and s:ArgIterate()
"				aren't needed any more.
"				Add a:range argument for all :argdo / :bufdo /
"				:tabdo / :windo invocations to support the new
"				-addr attribute.
"				Switch to
"				ingo#regexp#fromwildcard#AnchoredToPathBoundaries()
"				to correctly enforce path boundaries in
"				:ArgsList {glob}.
"   1.23.019	29-Jan-2015	Vim 7.4.605 makes the alternate file register "#
"				writable, so we don't need to revisit the buffer.
"				FIX: :Argdo may fail to restore the original
"				buffer. Ensure that argidx() actually points to
"				valid argument; this may not be the case when
"				arguments have only been :argadd'ed, but not
"				visited yet.
"   1.23.018	27-Jan-2015	ENH: Keep previous (last accessed) window on
"				:Windo and :Winbufdo. Thanks to Daniel Hahler
"				for the patch.
"				ENH: Keep alternate buffer (#) on :Argdo and
"				:Bufdo commands. Thanks to Daniel Hahler for the
"				suggestion.
"				Handle modified buffers together with :set
"				nohidden when restoring the original buffer
"				after :Argdo and :Bufdo by using :hide.
"   1.23.017	05-May-2014	Use ingo#msg#WarningMsg().
"   1.22.016	24-Mar-2014	Also catch custom exceptions and errors caused
"				by the passed user command (or configured
"				post-command).
"				Add :ArgdoConfirmWrite variant of :ArgdoWrite.
"   1.22.015	11-Dec-2013	Factor out s:List() and
"				s:GetQuickfixFilespecs(). Reuse them for
"				ArgsAndMore#QuickfixList().
"				FIX: :ArgsList printed "cnt" is zero-based, not
"				1-based.
"				Do not print title on :ArgsList when there are
"				no arguments.
"   1.21.014	26-Oct-2013	Move from the simplistic
"				ingo#regexp#FromWildcard() to
"				ingo#regexp#fromwildcard#Convert() to handle all
"				wildcards.
"   1.21.013	07-Oct-2013	Don't just check for 'buftype' of "nofile"; also
"				exclude "nowrite", quickfix and help buffers.
"   1.21.012	08-Aug-2013	Move escapings.vim into ingo-library.
"   1.20.011	14-Jun-2013	Minor: Make matchstr() robust against
"				'ignorecase'.
"   1.20.010	01-Jun-2013	ENH: Enable syntax highlighting on :Argdo /
"				:Bufdo on freshly loaded buffers when the
"				command is an interactive one (:s///c, according
"				to g:ArgsAndMore_InteractiveCommandPattern), but
"				for performance reasons not in the general case.
"				In :{range}Argdo, emulate the behavior of the
"				built-in :argdo to disable syntax highlighting
"				during to speed up the iteration, but consider
"				our own enhancement, the exception for
"				interactive commands.
"			    	Move ingofile.vim into ingo-library.
"   			    	Move ingofileargs.vim into ingo-library.
"   1.20.009	24-May-2013	Move ingosearch.vim to ingo-library.
"   1.20.008	09-Apr-2013	ENH: Allow postCommand execute for :Argdo and
"				:Bufdo.
"   1.12.007	15-Mar-2013	Use ingo/msg.vim error functions. Obsolete
"				s:ErrorMsg() and s:MsgFromException().
"				ENH: Add errors from :Argdo and :Bufdo to the
"				quickfix list to allow easier rework.
"   1.12.006	21-Feb-2013	Move ingocollections.vim to ingo-library.
"   1.11.005	15-Jan-2013	FIX: Factor out s:sort() and also use numerical
"				sort in the one missed case.
"   1.10.004	09-Sep-2012	Factor out common try..execute..catch into
"				s:Execute().
"				Add g:ArgsAndMore_AfterCommand hook before
"				buffer switching.
"				Add :Bufdo, with error summary like for :Argdo.
"   1.01.003	27-Aug-2012	Do not use <f-args> because of its unescaping
"				behavior.
"				FIX: "E480: No match" on :ArgsNegated with
"				../other/path relative argument; need to issue a
"				dummy :chdir to convert relative args before
"				doing the :argdelete.
"   1.00.002	30-Jul-2012	ENH: Implement :CListToArgs et al.
"				ENH: Avoid the hit-enter prompt on :Argdo, do
"				summary reporting. Add :ArgdoErrors and
"				:ArgdoDeleteSuccessful to further analyse and
"				filter the processed arguments.
"				ENH: Restore the argument index in addition to
"				the current file on :Argdo.
"	001	29-Jul-2012	file creation from ingocommands.vim
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
	    execute a:range 'windo call s:Execute(a:command)'
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

	    execute a:range 'windo'
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
	execute a:range 'tabdo call s:Execute(a:command)'
    execute l:originalTabNr . 'tabnext'
endfunction

function! ArgsAndMore#Tabwindo( range, command )
    let l:originalTabNr = tabpagenr()
	execute a:range 'tabdo call ArgsAndMore#Windo("", a:command)'
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
