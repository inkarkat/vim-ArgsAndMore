" ArgsAndMore/Root.vim: Commands for root directory filtering.
"
" DEPENDENCIES:
"   - VcsRoot.vim plugin
"   - ingo-library.vim plugin
"
" Copyright: (C) 2026 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ArgsAndMore#Root#Filter( filespec ) abort
    let l:root = VcsRoot#Root()
    if empty(l:root)
	throw 'No root directory found'
    endif
    return ingo#fs#path#split#StartsWith(fnamemodify(a:filespec, ':p'), fnamemodify(l:root, ':p'))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
