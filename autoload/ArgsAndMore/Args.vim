" ArgsAndMore/Args.vim: Commands around the argument list.
"
" DEPENDENCIES:
"   - ingo/cmdargs/file.vim autoload script
"   - ingo/collections.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/event.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/regexp/fromwildcard.vim autoload script
"
"
" Copyright: (C) 2015-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.11.003	13-Feb-2018	ENH: ArgsAndMore#Args#Filter(): Add a:startArg
"                               and a:endArg and slice argv() with them.
"                               Pass a:FilterGenerator to
"                               ArgsAndMore#Args#Filter() and extract
"                               ArgsAndMore#Args#FilterDirect() strategy.
"                               ENH: Add ArgsAndMore#Args#FilterArg() strategy
"                               that evaluates the filterExpression within the
"                               argument buffer, via :Argdo.
"   2.11.002	08-Dec-2017	Replace :doautocmd with ingo#event#Trigger().
"   2.10.001	11-Feb-2015	file creation from autoload/ArgsAndMore.vim
let s:save_cpo = &cpo
set cpo&vim

function! ArgsAndMore#Args#Filter( FilterGenerator, startArg, endArg, filterExpression )
    if a:endArg == 0
	call ingo#err#Set('No arguments')
	return 0
    endif

    let l:deletedArgs = []
    try
	let l:filteredArgs = call(a:FilterGenerator, [a:startArg, a:endArg, a:filterExpression])

	" To keep the indices valid, remove the arguments starting with the
	" last argument.
	for l:argIdx in range(len(l:filteredArgs) - 1, 0, -1)
	    if ! l:filteredArgs[l:argIdx]
		call insert(l:deletedArgs, argv(l:argIdx), 0)
		execute (l:argIdx + a:startArg) . 'argdelete'
	    endif
	endfor
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry

    if len(l:deletedArgs) == 0
	call ingo#msg#WarningMsg('No arguments filtered out')
    else
	let l:originalArgNum = a:endArg - a:startArg + 1
	echo printf('Deleted %d of %d: %s', len(l:deletedArgs), l:originalArgNum, join(l:deletedArgs))
    endif
    return 1
endfunction
function! ArgsAndMore#Args#FilterDirect( startArg, endArg, filterExpression )
    let l:arguments = argv()[(a:startArg - 1) : (a:endArg - 1)]
    return map(l:arguments, a:filterExpression)
endfunction
function! ArgsAndMore#Args#FilterIterate( startArg, endArg, filterExpression )
    let s:filteredArgs = []
    if ArgsAndMore#Iteration#Argdo(a:startArg . ',' . a:endArg, printf('call ArgsAndMore#Args#FilterArg(%s)', string(a:filterExpression)), '')
	let l:filteredArgs = s:filteredArgs
    else
	let l:filteredArgs = [] " Return empty List on error, so that no filtering takes place.
    endif
    unlet s:filteredArgs
    return l:filteredArgs
endfunction
function! ArgsAndMore#Args#FilterArg( filterExpression )
    try
	call add(s:filteredArgs, ingo#actions#EvaluateWithVal(a:filterExpression, argv(argidx())))
    catch /^Vim\%((\a\+)\)\=:/
	" The expression is erroneous; as this probably affects all arguments,
	" stop the iteration now.
	call ingo#msg#VimExceptionMsg()
	throw 'ArgsAndMore: Aborted'
    endtry
endfunction


function! ArgsAndMore#Args#Negated( bang, filePatternsString )
    let l:filePatterns = ingo#cmdargs#file#SplitAndUnescape(a:filePatternsString)

    " First add all files in the passed directories, then remove the glob
    " matches. This allows to exclude multiple patterns from the same directory,
    " e.g. :ArgsNegated foo* bar*
    let l:argDirspecGlobs = ingo#collections#Unique(map(copy(l:filePatterns), 'ingo#fs#path#Combine(fnamemodify(v:val, ":h"), "*")'))
    " The globs passed to :argdelete must match the format listed in :args, so
    " modify all passed globs to be relative to the CWD.
    let l:argNegationGlobs = map(copy(l:filePatterns), 'fnamemodify(v:val, ":p:.")')
"****D echomsg '****' string(l:argDirspecGlobs) string(l:argNegationGlobs)
    try
	if argc() > 0
	    silent! execute printf('1,%dargdelete', argc())
	endif
	execute 'argadd' join(l:argDirspecGlobs)

	" XXX: Need to issue a dummy :chdir to convert relative args
	" "../other/path" to a path relative to the CWD "/real/other/path".
	let l:chdirCommand = (haslocaldir() ? 'lchdir!' : 'chdir!')
	execute l:chdirCommand ingo#compat#fnameescape(getcwd())

	execute 'argdelete' join(l:argNegationGlobs)
	execute 'first' . a:bang
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#msg#VimExceptionMsg()
    endtry
endfunction



function! s:List( files, currentIdx, isBang, fileglob )
    let l:isFullPath = (! empty(a:fileglob) || a:isBang)
    if ! empty(a:fileglob)
	let l:pattern = ingo#regexp#fromwildcard#AnchoredToPathBoundaries(a:fileglob)
    endif

    let l:hasPrintedTitle = 0
    for l:fileIdx in range(len(a:files))
	let l:filespec = a:files[l:fileIdx]
	if l:isFullPath
	    let l:filespec = fnamemodify(l:filespec, ':p')
	endif
	if ! empty(a:fileglob) && (! a:isBang && l:filespec !~ l:pattern || a:isBang && l:filespec =~ l:pattern)
	    continue
	endif

	if ! l:hasPrintedTitle
	    let l:hasPrintedTitle = 1

	    echohl Title
	    echo '   cnt	file'
	    echohl None
	endif
	echo (l:fileIdx == a:currentIdx ? '*' : ' ') . printf('%3d', l:fileIdx + 1) . "\t" . l:filespec
    endfor
endfunction
function! ArgsAndMore#Args#List( startArg, endArg, isBang, fileglob )
    call s:List(
    \   argv()[a:startArg - 1 : a:endArg - 1],
    \   argidx() - a:startArg + 1,
    \   a:isBang,
    \   a:fileglob
    \)
endfunction


function! ArgsAndMore#Args#ToQuickfix( startArg, endArg )
    silent call ingo#event#Trigger('QuickFixCmdPre args') | " Allow hooking into the quickfix update.
	call setqflist(map(
	\   argv()[a:startArg - 1 : a:endArg - 1],
	\   "{'filename': v:val, 'lnum': 1}"
	\))
    silent call ingo#event#Trigger('QuickFixCmdPost args') | " Allow hooking into the quickfix update.
endfunction


function! s:GetQuickfixFilespecs( list, existingFilespecs )
    let l:existingFilespecs = ingo#collections#ToDict(a:existingFilespecs)
    let l:addedBufnrs = {}
    let l:filespecs = []
    for l:bufnr in map(a:list, 'v:val.bufnr')
	if has_key(l:addedBufnrs, l:bufnr)
	    continue
	endif
	let l:addedBufnrs[l:bufnr] = 1

	let l:filespec = bufname(l:bufnr)
	if has_key(l:existingFilespecs, l:filespec)
	    continue
	endif

	call add(l:filespecs, l:filespec)
    endfor

    return [len(l:addedBufnrs), l:filespecs]
endfunction
function! ArgsAndMore#Args#QuickfixList( list, isBang, fileglob )
    call s:List(s:GetQuickfixFilespecs(a:list, [])[1], -1, a:isBang, a:fileglob)
endfunction

function! s:ExecuteWithoutWildignore( excommand, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand with all a:filespecs passed as arguments while
"   'wildignore' is temporarily  disabled. This allows to introduce filespecs to
"   the argument list (:args ..., :argadd ...) which would normally be filtered
"   by 'wildignore'.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:excommand	    Ex command to be invoked
"   a:filespecs	    List of filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:save_wildignore = &wildignore
    set wildignore=
    try
	execute a:excommand join(map(copy(a:filespecs), 'ingo#compat#fnameescape(v:val)'), ' ')
    finally
	let &wildignore = l:save_wildignore
    endtry
endfunction
function! ArgsAndMore#Args#QuickfixToArgs( list, isArgAdd, count, bang )
    if empty(a:list)
	call ingo#msg#ErrorMsg('No items')
	return
    endif

    if ! a:isArgAdd && argc() > 0
	silent execute printf('1,%dargdelete', argc())
    endif

    let [l:quickfixBufferCnt, l:filespecs] = s:GetQuickfixFilespecs(a:list, argv())

    if len(l:filespecs) == 0
	echo printf('No new arguments in %d unique item%s', l:quickfixBufferCnt, (l:quickfixBufferCnt == 1 ? '' : 's'))
    else
	let l:command = (a:isArgAdd ? (a:count ? a:count : '') . 'argadd' : 'args' . a:bang)
	call s:ExecuteWithoutWildignore(l:command, l:filespecs)
	echo printf('%d file%s%s: %s', len(l:filespecs), (len(l:filespecs) == 1 ? '' : 's'), (a:isArgAdd ? ' added' : ''), join(l:filespecs))
    endif
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
