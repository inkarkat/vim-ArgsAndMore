" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - ArgsAndMore.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	29-Jul-2012	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_ArgsAndMore') || (v:version < 700)
    finish
endif
let g:loaded_ArgsAndMore = 1

" Note: No -bar for the :...do commands; they can take a sequence of Vim
" commands.

command! -nargs=1 -complete=command Windo    call ArgsAndMore#Windo(<f-args>)
command! -nargs=1 -complete=command Winbufdo call ArgsAndMore#Winbufdo(<f-args>)
command! -nargs=1 -complete=command Tabdo    call ArgsAndMore#Tabdo(<f-args>)
command! -nargs=1 -complete=command Tabwindo call ArgsAndMore#Tabwindo(<f-args>)


" Note: No -bar; can take a sequence of Vim commands.
" Note: Cannot use -range and <line1>, <line2>, because in them, identifiers
" like ".+1" and "$" are translated into buffer line numbers, and we need
" argument indices! Instead, use -count=0 as a marker, and extract the original
" range from the command history. (This means that we can only use the command
" interactively, not in a script.)
command! -count=0 -nargs=1 -complete=command Argdo call ArgsAndMore#ArgdoWrapper(<count>, <f-args>)


command! -nargs=1 -complete=expression ArgsFilter call ArgsAndMore#ArgsFilter(<q-args>)

command! -bang -nargs=+ -complete=file ArgsNegated call ArgsAndMore#ArgsNegated('<bang>', <f-args>)

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
