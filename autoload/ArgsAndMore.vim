" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - ingocollections.vim autoload script (for :ArgsNegated)
"   - ingosearch.vim autoload script (for :ArgsList)
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	002	30-Jul-2012	ENH: Implement :CListToArgs et al.
"	001	29-Jul-2012	file creation from ingocommands.vim

function! s:ErrorMsg( text )
    let v:errmsg = a:text
    echohl ErrorMsg
    echomsg v:errmsg
    echohl None
endfunction
function! s:ExceptionMsg( exception )
    " v:exception contains what is normally in v:errmsg, but with extra
    " exception source info prepended, which we cut away.
    call s:ErrorMsg(substitute(a:exception, '^Vim\%((\a\+)\)\=:', '', ''))
endfunction

function! ArgsAndMore#Windo( command )
    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
	let l:originalWinNr = winnr()

	    windo
	    \   try |
	    \       execute a:command |
	    \   catch /^Vim\%((\a\+)\)\=:E/ |
	    \       call s:ExceptionMsg(v:exception) |
	    \   endtry

	execute l:originalWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ArgsAndMore#Winbufdo( command )
    let l:buffers = []

    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
	let l:originalWinNr = winnr()

	    windo
	    \   if index(l:buffers, bufnr('')) == -1 |
	    \       call add(l:buffers, bufnr('')) |
	    \       try |
	    \           execute a:command |
	    \       catch /^Vim\%((\a\+)\)\=:E/ |
	    \           call s:ExceptionMsg(v:exception) |
	    \       endtry |
	    \   endif

	execute l:originalWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ArgsAndMore#Tabdo( command )
    let l:originalTabNr = tabpagenr()
	tabdo
	    \   try |
	    \       execute a:command |
	    \   catch /^Vim\%((\a\+)\)\=:E/ |
	    \       call s:ExceptionMsg(v:exception) |
	    \   endtry
    execute l:originalTabNr . 'tabnext'
endfunction

function! ArgsAndMore#Tabwindo( command )
    let l:originalTabNr = tabpagenr()
	tabdo call ArgsAndMore#Windo(a:command)
    execute l:originalTabNr . 'tabnext'
endfunction


function! s:ArgumentListRestoreCommand()
    " argidx() doesn't tell whether we're in the N'th file of the argument list,
    " or in an unrelated file. Need to compare the actual filenames to be sure.
    if argc() == 0 || argv(argidx()) !=# expand('%')
	return bufnr('') . 'buffer'
    else
	return (argidx() + 1) . 'argument'
    endif
endfunction
function! s:Argdo( command )
    let l:restoreCmd = s:ArgumentListRestoreCommand()

    " The :argdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	" Individual commands need to be enclosed in try..catch, or the :argdo
	" iteration will be aborted. (We can't use :silent! because we want to
	" see the error message.)
	argdo
	\   try |
	\       execute a:command |
	\   catch /^Vim\%((\a\+)\)\=:E/ |
	\       call s:ExceptionMsg(v:exception) |
	\   endtry
    catch /^Vim\%((\a\+)\)\=:E/
	call s:ExceptionMsg(v:exception)
    endtry

    silent! execute l:restoreCmd
endfunction
function! s:ArgIterate( startIdx, endIdx, command )
    let l:restoreCmd = s:ArgumentListRestoreCommand()

    " The :argdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	" Individual commands need to be enclosed in try..catch, or the :argdo
	" iteration will be aborted. (We can't use :silent! because we want to
	" see the error message.)
	for l:idx in range(a:startIdx, a:endIdx)
	    execute l:idx . 'argument'
	    try
		execute a:command
	    catch /^Vim\%((\a\+)\)\=:E/
		call s:ExceptionMsg(v:exception)
	    endtry
	endfor
    catch /^Vim\%((\a\+)\)\=:E/
	call s:ExceptionMsg(v:exception)
    endtry

    silent! execute l:restoreCmd
endfunction
function! s:InterpretRange( rangeExpr )
    let l:range = a:rangeExpr
    let l:range = substitute(l:range, '%', '1,$', 'g')
    let l:range = substitute(l:range, '\.', argidx() + 1, 'g')
    let l:range = substitute(l:range, '\$', argc(), 'g')

    " Split and apply defaults.
    let l:limits = split(l:range, ',', 1)
    if empty(get(l:limits, 0, ''))
	let l:limits[0] = 1
    endif
    if empty(get(l:limits, 1, ''))
	let l:limits[1] = argc()
    endif

    " Finally evaluate arithmetics like ".+1".
    try	" Note: Must somehow explicitly try..catch around eval().
	return map(l:limits, 'eval(v:val)')
    catch
	return []
    endtry
endfunction
function! ArgsAndMore#ArgdoWrapper( count, command )
    if a:count == 0
	call s:Argdo(a:command)
    else
	try
	    let l:range = matchstr(histget('cmd', -1), '\%(^\||\)\s*\zs[^|]\+\ze\s*A\%[rgdo] ')
	    if empty(l:range) | throw 'Invalid range' | endif
	    let l:limits = s:InterpretRange(l:range)
	    if len(l:limits) != 2 || l:limits[0] > l:limits[1] | throw 'Invalid range' | endif
	    call s:ArgIterate(l:limits[0], l:limits[1], a:command)
	catch
	    call s:ErrorMsg('Invalid range' . (empty(l:range) ? '' : ': ' . l:range))
	endtry
    endif
endfunction



function! ArgsAndMore#ArgsFilter( filterExpression )
    let l:originalArgNum = argc()
    let l:deletedArgs = []
    try
	let l:filteredArgs = map(argv(), a:filterExpression)

	" To keep the indices valid, remove the arguments starting with the
	" last argument.
	for l:argIdx in range(len(l:filteredArgs) - 1, 0, -1)
	    if ! l:filteredArgs[l:argIdx]
		call insert(l:deletedArgs, argv(l:argIdx), 0)
		execute (l:argIdx + 1) . 'argdelete'
	    endif
	endfor
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endtry

    if len(l:deletedArgs) == 0
	let v:warningmsg = 'No arguments filtered out'
	echohl WarningMsg
	echomsg v:warningmsg
	echohl None
    else
	echo printf('Deleted %d/%d: %s', len(l:deletedArgs), l:originalArgNum, join(l:deletedArgs))
    endif
endfunction

function! ArgsAndMore#ArgsNegated( bang, ... )
    " First add all files in the passed directories, then remove the glob
    " matches. This allows to exclude multiple patterns from the same directory,
    " e.g. :ArgsNegated foo* bar*
    let l:argDirspecGlobs = ingocollections#unique(map(copy(a:000), 'ingofile#CombineToFilespec(fnamemodify(v:val, ":h"), "*")'))
    " The globs passed to :argdelete must match the format listed in :args, so
    " modify all passed globs to be relative to the CWD.
    let l:argNegationGlobs = map(copy(a:000), 'fnamemodify(v:val, ":p:.")')

    try
	if argc() > 0
	    silent! execute printf('1,%dargdelete', argc())
	endif
	execute 'argadd' join(l:argDirspecGlobs)
	execute 'argdelete' join(l:argNegationGlobs)
	execute 'first' . a:bang
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endtry
endfunction



function! ArgsAndMore#ArgsList( isBang, ... )
    let l:isFullPath = (a:0 || a:isBang)
    if a:0
	let l:pattern = ingosearch#WildcardExprToSearchPattern(a:1, '')
    endif

    echohl Title
    echo '   cnt	file'
    echohl None

    for l:argIdx in range(argc())
	let l:argFilespec = argv(l:argIdx)
	if l:isFullPath
	    let l:argFilespec = fnamemodify(l:argFilespec, ':p')
	endif
	if a:0 && (! a:isBang && l:argFilespec !~ l:pattern || a:isBang && l:argFilespec =~ l:pattern)
	    continue
	endif

	echo (l:argIdx == argidx() ? '*' : ' ') . printf('%3d', l:argIdx) . "\t" . l:argFilespec
    endfor
endfunction


function! ArgsAndMore#ArgsToQuickfix()
    silent doautocmd QuickFixCmdPre args | " Allow hooking into the quickfix update.
    call setqflist(map(argv(), "{'filename': v:val, 'lnum': 1}"))
    silent doautocmd QuickFixCmdPost args | " Allow hooking into the quickfix update.
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
"   a:excommand	    ex command to be invoked
"   a:filespecs	    List of filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:save_wildignore = &wildignore
    set wildignore=
    try
	execute a:excommand join(map(copy(a:filespecs), 'escapings#fnameescape(v:val)'), ' ')
    finally
	let &wildignore = l:save_wildignore
    endtry
endfunction
function! ArgsAndMore#QuickfixToArgs( list, isArgAdd, count, bang )
    if empty(a:list)
	call s:ErrorMsg('No items')
	return
    endif

    if ! a:isArgAdd && argc() > 0
	silent execute printf('1,%dargdelete', argc())
    endif

    let l:addedBufnrs = {}
    let l:filespecs = []
    let l:existingArguments = ingocollections#ToDict(argv())
    for l:bufnr in map(a:list, 'v:val.bufnr')
	if has_key(l:addedBufnrs, l:bufnr)
	    continue
	endif
	let l:addedBufnrs[l:bufnr] = 1

	let l:filespec = bufname(l:bufnr)
	if has_key(l:existingArguments, l:filespec)
	    continue
	endif

	call add(l:filespecs, l:filespec)
    endfor

    if len(l:filespecs) == 0
	echo printf('No new arguments in %d unique item%s', len(l:addedBufnrs), (len(l:addedBufnrs) == 1 ? '' : 's'))
    else
	let l:command = (a:isArgAdd ? (a:count ? a:count : '') . 'argadd' : 'args' . a:bang)
	call s:ExecuteWithoutWildignore(l:command, l:filespecs)
	echo printf('%d file%s%s: %s', len(l:filespecs), (len(l:filespecs) == 1 ? '' : 's'), (a:isArgAdd ? ' added' : ''), join(l:filespecs))
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
