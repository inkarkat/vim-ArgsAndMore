" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - ArgsAndMore.vim autoload script
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.30.012	30-Jan-2015	Support the -addr=arguments attribute in Vim
"				7.4.530 or later for :Argdo... commands. With
"				that, relative addressing can also be used
"				non-interactively.
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

command! -nargs=1 -complete=command Bufdo       call ArgsAndMore#Bufdo(<q-args>, '')
command! -nargs=1 -complete=command BufdoWrite  call ArgsAndMore#Bufdo(<q-args>, 'update')
command! -nargs=1 -complete=command Windo       call ArgsAndMore#Windo(<q-args>)
command! -nargs=1 -complete=command Winbufdo    call ArgsAndMore#Winbufdo(<q-args>)
command! -nargs=1 -complete=command Tabdo       call ArgsAndMore#Tabdo(<q-args>)
command! -nargs=1 -complete=command Tabwindo    call ArgsAndMore#Tabwindo(<q-args>)


" Note: No -bar; can take a sequence of Vim commands.
if v:version == 704 && has('patch530') || v:version > 704
command! -addr=arguments -range=-1 -nargs=1 -complete=command Argdo             call ArgsAndMore#ArgdoAddr((<count> == -1), <line1>, <line2>, <q-args>, '')
command! -addr=arguments -range=-1 -nargs=1 -complete=command ArgdoWrite        call ArgsAndMore#ArgdoAddr((<count> == -1), <line1>, <line2>, <q-args>, 'update')
command! -addr=arguments -range=-1 -nargs=1 -complete=command ArgdoConfirmWrite call ArgsAndMore#ConfirmResetChoice() |
\                                                                               call ArgsAndMore#ArgdoAddr((<count> == -1), <line1>, <line2>, <q-args>, 'call ArgsAndMore#ConfirmedUpdate()')
else
" Note: Cannot use -range and <line1>, <line2>, because in them, identifiers
" like ".+1" and "$" are translated into buffer line numbers, and we need
" argument indices! Instead, use -range=-1 as a marker, and extract the original
" range from the command history. (This means that we can only use the command
" interactively, not in a script.)
command! -range=-1 -nargs=1 -complete=command Argdo             call ArgsAndMore#ArgdoWrapper((<count> == -1), <q-args>, '')
command! -range=-1 -nargs=1 -complete=command ArgdoWrite        call ArgsAndMore#ArgdoWrapper((<count> == -1), <q-args>, 'update')
command! -range=-1 -nargs=1 -complete=command ArgdoConfirmWrite call ArgsAndMore#ConfirmResetChoice() |
\                                                               call ArgsAndMore#ArgdoWrapper((<count> == -1), <q-args>, 'call ArgsAndMore#ConfirmedUpdate()')
endif

command! -bar ArgdoErrors call ArgsAndMore#ArgdoErrors()
command! -bar ArgdoDeleteSuccessful call ArgsAndMore#ArgdoDeleteSuccessful()


command! -nargs=1 -complete=expression ArgsFilter call ArgsAndMore#ArgsFilter(<q-args>)

command! -bang -nargs=+ -complete=file ArgsNegated call ArgsAndMore#ArgsNegated('<bang>', <q-args>)

" Note: Must use * instead of ?; otherwise (due to -complete=file), Vim
" complains about globs with "E77: Too many file names".
command! -bar -bang -nargs=* -complete=file ArgsList call ArgsAndMore#ArgsList(<bang>0, <q-args>)
command! -bar -bang -nargs=* -complete=file CList call ArgsAndMore#QuickfixList(getqflist(), <bang>0, <q-args>)
command! -bar -bang -nargs=* -complete=file LList call ArgsAndMore#QuickfixList(getloclist(0), <bang>0, <q-args>)

command! -bar ArgsToQuickfix call ArgsAndMore#ArgsToQuickfix()

command! -bar -bang  CListToArgs    call ArgsAndMore#QuickfixToArgs(getqflist(), 0, 0, '<bang>')
command! -bar -count CListToArgsAdd call ArgsAndMore#QuickfixToArgs(getqflist(), 1, <count>, '')
command! -bar -bang  LListToArgs    call ArgsAndMore#QuickfixToArgs(getloclist(0), 0, 0, '<bang>')
command! -bar -count LListToArgsAdd call ArgsAndMore#QuickfixToArgs(getloclist(0), 1, <count>, '')

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
