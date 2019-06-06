" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - ArgsAndMore.vim autoload script
"   - ArgsAndMore/Args.vim autoload script
"   - ArgsAndMore/Iteration.vim autoload script
"   - ingo/err.vim autoload script
"   - Requires Vim 7.0 or higher.
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.11.016	13-Feb-2018	ENH: Support [range] for :ArgsFilter (without
"                               workaround for older Vim versions, though).
"                               ENH: Add :ArgsFilterDo variant.
"                               Use proper error aborting for :Bufdo, :Argdo,
"                               and :[CL]Do*.
"   2.11.015	13-Feb-2018	Refactoring: Define s:hasArgumentAddressing to
"                               avoid repetition of the conditional.
"   2.10.014	11-Feb-2015	Factor out ArgsAndMore/Args.vim and
"				ArgsAndMore/Iteration.vim modules.
"   2.10.013	10-Feb-2015	FIX: :Bufdo..., :Win..., :Tab... in recent Vim
"				7.4 defaults to wrong range. Forgot -range=%
"				argument.
"				Add :CDoFile, :CDoEntry commands for iteration
"				over quickfix / location list.
"   2.00.012	30-Jan-2015	Support the -addr=arguments attribute in Vim
"				7.4.530 or later for :Argdo... commands. With
"				that, relative addressing can also be used
"				non-interactively.
"				Support ranges in :Bufdo..., :Windo...,
"				:Tabdo... if supported by Vim.
"				Support ranges in :ArgsList and :ArgsToQuickfix
"				if supported by Vim.
"   1.22.011	24-Mar-2014	Add :ArgdoConfirmWrite variant of :ArgdoWrite.
"   1.22.010	11-Dec-2013	Add :CList and :LList, analog to :ArgsList.
"   1.21.009	24-Jul-2013	FIX: Use the rules for the /pattern/ separator
"				as stated in :help E146.
"   1.20.008	21-Apr-2013	Change -range=-1 default check to use <count>,
"				which maintains the actual -1 default, and
"				therefore also delivers correct results when on
"				line 1.
"   1.20.007	09-Apr-2013	ENH: Add :ArgdoWrite and :BufdoWrite variants
"				that also perform an automatic :update.
"   1.12.006	15-Mar-2013	Avoid script errors when using :Argdo 3s/foo/bar
"				by using -range=-1 instead of -count=0 (which
"				parses a number from the leading argument) as
"				the test for a passed range.
"   1.10.005	09-Sep-2012	Add g:ArgsAndMore_AfterCommand hook before
"				buffer switching and use this by default to add
"				a small delay, which allows for aborting an
"				interactive :s///c substitution by pressing
"				CTRL-C twice within the delay. Cp.
"				http://stackoverflow.com/questions/12328007/in-vim-how-to-cancel-argdo
"				Add :Bufdo command for completeness and to get
"				the hook functionality.
"   1.01.004	27-Aug-2012	Do not use <f-args> because of its unescaping
"				behavior.
"   1.00.003	30-Jul-2012	ENH: Implement :CListToArgs et al.
"				ENH: Add :ArgdoErrors and :ArgdoDeleteSuccessful
"				to further analyse and filter the processed
"				arguments.
"	002	29-Jul-2012	Add :ArgsFilter, :ArgsList, :ArgsToQuickfix
"				commands.
"	001	29-Jul-2012	file creation from ingocommands.vim

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_ArgsAndMore') || (v:version < 700)
    finish
endif
let g:loaded_ArgsAndMore = 1
let s:save_cpo = &cpo
set cpo&vim

"- configuration ---------------------------------------------------------------

if ! exists('g:ArgsAndMore_AfterCommand')
    let g:ArgsAndMore_AfterCommand = 'sleep 100m'
endif
if ! exists('g:ArgsAndMore_InteractiveCommandPattern')
    let g:ArgsAndMore_InteractiveCommandPattern = 's\%[ubstitute]\([[:alnum:]\\"|]\@![\x00-\xFF]\).*\1\%([egiInp#lr]\)*c'
endif


"- commands --------------------------------------------------------------------

" Note: No -bar for the :...do commands; they can take a sequence of Vim
" commands.

let s:hasArgumentAddressing = (v:version == 704 && has('patch542') || v:version > 704)
if s:hasArgumentAddressing
command! -addr=buffers -bang -range=% -nargs=1 -complete=command Bufdo       if ! ArgsAndMore#Iteration#Bufdo(<q-bang>, '<line1>,<line2>', <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -bang -range=% -nargs=1 -complete=command BufdoWrite  if ! ArgsAndMore#Iteration#Bufdo(<q-bang>, '<line1>,<line2>', <q-args>, 'update') | echoerr ingo#err#Get() | endif
command! -addr=windows -bang -range=% -nargs=1 -complete=command Windo       call ArgsAndMore#Windo('<line1>,<line2>', <q-args>)
command! -addr=windows -bang -range=% -nargs=1 -complete=command Winbufdo    call ArgsAndMore#Winbufdo('<line1>,<line2>', <q-args>)
command! -addr=tabs    -bang -range=% -nargs=1 -complete=command Tabdo       call ArgsAndMore#Tabdo('<line1>,<line2>', <q-args>)
command! -addr=tabs    -bang -range=% -nargs=1 -complete=command Tabwindo    call ArgsAndMore#Tabwindo('<line1>,<line2>', <q-args>)
else
command!               -bang          -nargs=1 -complete=command Bufdo       if ! ArgsAndMore#Iteration#Bufdo(<q-bang>, '', <q-args>, '') | echoerr ingo#err#Get() | endif
command!               -bang          -nargs=1 -complete=command BufdoWrite  if ! ArgsAndMore#Iteration#Bufdo(<q-bang>, '', <q-args>, 'update') | echoerr ingo#err#Get() | endif
command!               -bang          -nargs=1 -complete=command Windo       call ArgsAndMore#Windo('', <q-args>)
command!               -bang          -nargs=1 -complete=command Winbufdo    call ArgsAndMore#Winbufdo('', <q-args>)
command!               -bang          -nargs=1 -complete=command Tabdo       call ArgsAndMore#Tabdo('', <q-args>)
command!               -bang          -nargs=1 -complete=command Tabwindo    call ArgsAndMore#Tabwindo('', <q-args>)
endif


" Note: No -bar; can take a sequence of Vim commands.
if s:hasArgumentAddressing
command! -addr=arguments -range=% -nargs=1 -complete=command Argdo             if ! ArgsAndMore#Iteration#Argdo(<q-bang>, '<line1>,<line2>', <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=arguments -range=% -nargs=1 -complete=command ArgdoWrite        if ! ArgsAndMore#Iteration#Argdo(<q-bang>, '<line1>,<line2>', <q-args>, 'update') | echoerr ingo#err#Get() | endif
command! -addr=arguments -range=% -nargs=1 -complete=command ArgdoConfirmWrite call ArgsAndMore#ConfirmResetChoice() |
\                                                                              if ! ArgsAndMore#Iteration#Argdo(<q-bang>, '<line1>,<line2>', <q-args>, 'call ArgsAndMore#ConfirmedUpdate()') | echoerr ingo#err#Get() | endif
else
" Note: Cannot use -range and <line1>, <line2>, because in them, identifiers
" like ".+1" and "$" are translated into buffer line numbers, and we need
" argument indices! Instead, use -range=-1 as a marker, and extract the original
" range from the command history. (This means that we can only use the command
" interactively, not in a script.)
command! -range=-1 -nargs=1 -complete=command Argdo             if ! ArgsAndMore#Iteration#ArgdoWrapper(<q-bang>, (<count> == -1), <q-args>, '') | echoerr ingo#err#Get() | endif
command! -range=-1 -nargs=1 -complete=command ArgdoWrite        if ! ArgsAndMore#Iteration#ArgdoWrapper(<q-bang>, (<count> == -1), <q-args>, 'update') | echoerr ingo#err#Get() | endif
command! -range=-1 -nargs=1 -complete=command ArgdoConfirmWrite call ArgsAndMore#ConfirmResetChoice() |
\                                                               if ! ArgsAndMore#Iteration#ArgdoWrapper(<q-bang>, (<count> == -1), <q-args>, 'call ArgsAndMore#ConfirmedUpdate()') | echoerr ingo#err#Get() | endif
endif

command! -bar ArgdoErrors call ArgsAndMore#Iteration#ArgdoErrors()
command! -bar ArgdoDeleteSuccessful call ArgsAndMore#Iteration#ArgdoDeleteSuccessful()


if s:hasArgumentAddressing
command! -addr=arguments       -range=% -nargs=1 -complete=expression ArgsFilter   if ! ArgsAndMore#Args#Filter('ArgsAndMore#Args#FilterDirect',  '',       <line1>, <line2>, <q-args>) | echoerr ingo#err#Get() | endif
command! -addr=arguments -bang -range=% -nargs=1 -complete=expression ArgsFilterDo if ! ArgsAndMore#Args#Filter('ArgsAndMore#Args#FilterIterate', <q-bang>, <line1>, <line2>, <q-args>) | echoerr ingo#err#Get() | endif
else
command!                                -nargs=1 -complete=expression ArgsFilter   if ! ArgsAndMore#Args#Filter('ArgsAndMore#Args#FilterDirect',  '',       1, argc(), <q-args>) | echoerr ingo#err#Get() | endif
command!                 -bang          -nargs=1 -complete=expression ArgsFilterDo if ! ArgsAndMore#Args#Filter('ArgsAndMore#Args#FilterIterate', <q-bang>, 1, argc(), <q-args>) | echoerr ingo#err#Get() | endif
endif

command! -bang -nargs=+ -complete=file ArgsNegated call ArgsAndMore#Args#Negated('<bang>', <q-args>)

" Note: Must use * instead of ?; otherwise (due to -complete=file), Vim
" complains about globs with "E77: Too many file names".
command! -bar -bang -nargs=* -complete=file CList call ArgsAndMore#Args#QuickfixList(getqflist(), <bang>0, <q-args>)
command! -bar -bang -nargs=* -complete=file LList call ArgsAndMore#Args#QuickfixList(getloclist(0), <bang>0, <q-args>)
if s:hasArgumentAddressing
command! -bar -bang -addr=arguments -range=% -nargs=* -complete=file ArgsList       call ArgsAndMore#Args#List(<line1>, <line2>, <bang>0, <q-args>)
command! -bar       -addr=arguments -range=%                         ArgsToQuickfix call ArgsAndMore#Args#ToQuickfix(<line1>, <line2>)
else
command! -bar -bang -nargs=* -complete=file ArgsList call ArgsAndMore#Args#List(1, argc(), <bang>0, <q-args>)
command! -bar ArgsToQuickfix call ArgsAndMore#Args#ToQuickfix(1, argc())
endif

command! -bar -bang  CListToArgs    call ArgsAndMore#Args#QuickfixToArgs(getqflist(), 0, 0, '<bang>')
command! -bar -count CListToArgsAdd call ArgsAndMore#Args#QuickfixToArgs(getqflist(), 1, <count>, '')
command! -bar -bang  LListToArgs    call ArgsAndMore#Args#QuickfixToArgs(getloclist(0), 0, 0, '<bang>')
command! -bar -count LListToArgsAdd call ArgsAndMore#Args#QuickfixToArgs(getloclist(0), 1, <count>, '')

if s:hasArgumentAddressing
command! -addr=buffers -range=% -nargs=1 -complete=command CDoEntry    if ! ArgsAndMore#Iteration#QuickfixDo(0, 0, '', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -range=% -nargs=1 -complete=command LDoEntry    if ! ArgsAndMore#Iteration#QuickfixDo(1, 0, '', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -range=% -nargs=1 -complete=command CDoFile     if ! ArgsAndMore#Iteration#QuickfixDo(0, 1, '', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -range=% -nargs=1 -complete=command LDoFile     if ! ArgsAndMore#Iteration#QuickfixDo(1, 1, '', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -range=% -nargs=1 -complete=command CDoFixEntry if ! ArgsAndMore#Iteration#QuickfixDo(0, 0, 'CDoFixEntry', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
command! -addr=buffers -range=% -nargs=1 -complete=command LDoFixEntry if ! ArgsAndMore#Iteration#QuickfixDo(1, 0, 'LDoFixEntry', <line1>, <line2>, <q-args>, '') | echoerr ingo#err#Get() | endif
else
command!                        -nargs=1 -complete=command CDoEntry    if ! ArgsAndMore#Iteration#QuickfixDo(0, 0, '', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
command!                        -nargs=1 -complete=command LDoEntry    if ! ArgsAndMore#Iteration#QuickfixDo(1, 0, '', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
command!                        -nargs=1 -complete=command CDoFile     if ! ArgsAndMore#Iteration#QuickfixDo(0, 1, '', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
command!                        -nargs=1 -complete=command LDoFile     if ! ArgsAndMore#Iteration#QuickfixDo(1, 1, '', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
command!                        -nargs=1 -complete=command CDoFixEntry if ! ArgsAndMore#Iteration#QuickfixDo(0, 0, 'CDoFixEntry', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
command!                        -nargs=1 -complete=command LDoFixEntry if ! ArgsAndMore#Iteration#QuickfixDo(1, 0, 'LDoFixEntry', 0, 0, <q-args>, '') | echoerr ingo#err#Get() | endif
endif

unlet! s:hasArgumentAddressing
let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
