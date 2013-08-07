" ArgsAndMore.vim: Apply commands to multiple buffers and manage the argument list.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"   - ingo/cmdargs/file.vim autoload script
"   - ingo/collections.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/regexp.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
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
"				ENH: Add errors from :Argdo and :BufDo to the
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

function! s:sort( list )
    return sort(a:list, 'ingo#collections#numsort')
endfunction

function! s:AfterExecute()
    execute g:ArgsAndMore_AfterCommand
endfunction
function! s:Execute( command )
    try
	execute a:command
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry

    call s:AfterExecute()
endfunction

function! ArgsAndMore#Windo( command )
    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
	let l:originalWinNr = winnr()
	    windo call s:Execute(a:command)
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
	    \       call s:Execute(a:command)
	    \   endif

	execute l:originalWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ArgsAndMore#Tabdo( command )
    let l:originalTabNr = tabpagenr()
	tabdo call s:Execute(a:command)
    execute l:originalTabNr . 'tabnext'
endfunction

function! ArgsAndMore#Tabwindo( command )
    let l:originalTabNr = tabpagenr()
	tabdo call ArgsAndMore#Windo(a:command)
    execute l:originalTabNr . 'tabnext'
endfunction


function! s:ArgumentListRestoreCommand()
    " Restore the current argument index.
    let l:restoreCommand = (argidx() + 1) . 'argument'

    " When the current file isn't in the argument list, restore that buffer,
    " too.
    " argidx() doesn't tell whether we're in the N'th file of the argument list,
    " or in an unrelated file. Need to compare the actual filenames to be sure.
    if argc() == 0 || argv(argidx()) !=# expand('%')
	let l:restoreCommand .= '|' . bufnr('') . 'buffer'
    endif

    return l:restoreCommand
endfunction
let s:errors = []
function! s:ErrorToQuickfixEntry( error )
    let l:entry = {'bufnr': a:error[1], 'text': a:error[2]}
    if len(a:error) >= 4
	let l:entry.lnum = a:error[3]
    endif
    if len(a:error) >= 5
	let l:entry.col = a:error[4]
    endif
    return l:entry
endfunction
function! s:ErrorsToQuickfix( command )
    if len(s:errors) == 0
	return
    endif

    silent execute 'doautocmd QuickFixCmdPre' a:command | " Allow hooking into the quickfix update.
	call setqflist(map(copy(s:errors), "s:ErrorToQuickfixEntry(v:val)"))
    silent execute 'doautocmd QuickFixCmdPost' a:command | " Allow hooking into the quickfix update.
endfunction
function! s:IsInteractiveCommand( command )
    return (! empty(g:ArgsAndMore_InteractiveCommandPattern) && a:command =~# g:ArgsAndMore_InteractiveCommandPattern)
endfunction
function! s:IsSyntaxSuppressed()
    return (index(split(&eventignore, ','), 'Syntax') != -1)
endfunction
function! s:EnableSyntaxHighlightingForInteractiveCommands( command )
"****D echomsg '****' exists('g:syntax_on') exists('b:current_syntax') string(&l:filetype) string(&l:buftype) index(split(&eventignore, ','), 'Syntax')
    " Note: Some plugins set up scratch windows with a custom filetype, but
    " don't set b:current_syntax. To avoid clearing their custom highlightings
    " when processing their buffer, we try to detect them via 'buftype'.
    if
    \   exists('g:syntax_on') &&
    \   ! exists('b:current_syntax') &&
    \   ! empty(&l:filetype) &&
    \   &l:buftype !=# 'nofile' &&
    \   s:IsSyntaxSuppressed()
	let l:save_eventignore = &eventignore
	set eventignore-=Syntax
	try
	    set syntax=ON
	finally
	    let &eventignore = l:save_eventignore
	endtry
    endif
endfunction
function! s:ArgExecute( command, postCommand, isEnableSyntax )
    if a:isEnableSyntax
	call s:EnableSyntaxHighlightingForInteractiveCommands(a:command)
    endif

    try
	let v:errmsg = ''
	execute a:command
	if ! empty(v:errmsg)
	    call add(s:errors, [argidx(), bufnr(''), v:errmsg, line('.'), col('.')])
	endif
	if ! empty(a:postCommand)
	    let v:errmsg = ''
	    execute a:postCommand
	    if ! empty(v:errmsg)
		call add(s:errors, [argidx(), bufnr(''), v:errmsg, line('.'), col('.')])
	    endif
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	call add(s:errors, [argidx(), bufnr(''), ingo#msg#MsgFromVimException(), line('.'), col('.')])
	call ingo#msg#VimExceptionMsg()
    endtry

    call s:AfterExecute()
endfunction
function! s:Argdo( command, postCommand )
    let l:restoreCommand = s:ArgumentListRestoreCommand()

    " Temporarily turn off 'more', as this interferes with the "automated batch
    " execution" the user has in mind: Arguments are processed until the screen
    " is full of (e.g. file write) messages, then stops. <Enter> steps until the
    " next message, <Space> a full page, "G" until the end. Unfortunately,
    " turning 'more' off also disables the |g<| command, which may be useful to
    " review the messages after the fact.
    " Instead, we capture all error messages and make them available through a
    " new :ArgdoErrors command.
    let l:save_more = &more
    set nomore

    let s:range = []
    let s:errors = []

    " The :argdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	" Individual commands need to be enclosed in try..catch, or the :argdo
	" iteration will be aborted. (We can't use :silent! because we want to
	" see the error message.)
	let l:isEnableSyntax = s:IsInteractiveCommand(a:command)
	argdo call s:ArgExecute(a:command, a:postCommand, l:isEnableSyntax)
    catch /^Vim\%((\a\+)\)\=:E/
	call add(s:errors, [argidx(), bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    endtry

    silent! execute l:restoreCommand

    call s:ErrorsToQuickfix('argdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', (s:errors[0][0] + 1), bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:argumentNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[0] + 1')))
	call ingo#msg#ErrorMsg(printf('%d error%s in argument%s %s', len(s:errors), (len(s:errors) == 1 ? '' : 's'), (len(l:argumentNumbers) == 1 ? '' : 's'), join(l:argumentNumbers, ', ')))
    endif

    " To avoid a hit-enter prompt, we have to restore this _after_ the summary
    " error message.
    let &more = l:save_more
endfunction
function! s:ArgIterate( startIdx, endIdx, command, postCommand )
    " Structure here like in s:Argdo().

    let l:restoreCommand = s:ArgumentListRestoreCommand()

    if ! s:IsInteractiveCommand(a:command) && ! s:IsSyntaxSuppressed()
	" Emulate the behavior of the built-in :argdo to disable syntax
	" highlighting during to speed up the iteration, but consider our own
	" enhancement, the exception for interactive commands.
	let l:undoSuppressSyntax = 1
	set eventignore+=Syntax
    endif

    let l:save_more = &more
    set nomore

    let s:range = [a:startIdx, a:endIdx]
    let s:errors = []

    try
	for l:idx in range(a:startIdx, a:endIdx)
	    " This is not :argdo; the printed error messages will be overwritten
	    " by the messages resulting from the switch to the next argument. To
	    " avoid this and keep both file changes as well as error messages
	    " interspersed on the screen, capture the output from the file
	    " change and :echo it ourselves.
	    redir => l:nextArgumentOutput
		silent execute l:idx . 'argument'
	    redir END
	    let l:nextArgumentOutput = substitute(l:nextArgumentOutput, '^\_s*', '', '')
	    if ! empty(l:nextArgumentOutput)
		echo l:nextArgumentOutput
	    endif

	    call s:ArgExecute(a:command, a:postCommand, 0)  " Without :argdo, we control the syntax suppression; no need to enable syntax during iteration.
	endfor
    catch /^Vim\%((\a\+)\)\=:E/
	call add(s:errors, [argidx(), bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    finally
	if exists('l:undoSuppressSyntax')
	    set eventignore-=Syntax
	endif
    endtry

    silent! execute l:restoreCommand

    call s:ErrorsToQuickfix('argdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', (s:errors[0][0] + 1), bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:argumentNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[0] + 1')))
	call ingo#msg#ErrorMsg(printf('%d error%s in argument%s %s', len(s:errors), (len(s:errors) == 1 ? '' : 's'), (len(l:argumentNumbers) == 1 ? '' : 's'), join(l:argumentNumbers, ', ')))
    endif

    let &more = l:save_more
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
function! ArgsAndMore#ArgdoWrapper( isNoRangeGiven, command, postCommand )
    if a:isNoRangeGiven
	call s:Argdo(a:command, a:postCommand)
    else
	try
	    let l:range = matchstr(histget('cmd', -1), '\C\%(^\||\)\s*\zs[^|]\+\ze\s*A\%[rgdo] ')
	    if empty(l:range) | throw 'Invalid range' | endif
	    let l:limits = s:InterpretRange(l:range)
	    if len(l:limits) != 2 || l:limits[0] > l:limits[1] | throw 'Invalid range' | endif
	    call s:ArgIterate(l:limits[0], l:limits[1], a:command, a:postCommand)
	catch
	    call ingo#msg#ErrorMsg('Invalid range' . (empty(l:range) ? '' : ': ' . l:range))
	endtry
    endif
endfunction

function! ArgsAndMore#ArgdoErrors()
    let l:argidxByError = {}
    for l:error in s:errors
	let [l:argidx, l:bufnr, l:errorMsg] = l:error[0:2]
	let l:argidxByError[l:errorMsg] = get(l:argidxByError, l:errorMsg, []) + [[l:argidx, l:bufnr]]
    endfor

    for l:errorMsg in s:sort(keys(l:argidxByError))
	echohl ErrorMsg
	echo l:errorMsg
	echohl None

	for [l:argidx, l:bufnr] in l:argidxByError[l:errorMsg]
	    echo printf('%3d %s', (l:argidx + 1), bufname(l:bufnr))
	endfor
    endfor
endfunction
function! ArgsAndMore#ArgdoDeleteSuccessful()
    if empty(s:range)
	let l:originalArgNum = argc()
	let [l:startIdx, l:endIdx] = [0, l:originalArgNum - 1]
    else
	let [l:startIdx, l:endIdx] = s:range
	let l:originalArgNum = l:endIdx - l:startIdx + 1
    endif

    let l:argIdxDict = ingo#collections#ToDict(map(copy(s:errors), 'v:val[0]'))
    try
	" To keep the indices valid, remove the arguments starting with the
	" last argument.
	for l:argIdx in range(l:endIdx, l:startIdx, -1)
	    if ! has_key(l:argIdxDict, l:argIdx)
		execute (l:argIdx + 1) . 'argdelete'
	    endif
	endfor
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry

    echo printf('Deleted %d successfully processed from %d arguments', (l:originalArgNum - len(l:argIdxDict)), l:originalArgNum)
endfunction

function! ArgsAndMore#Bufdo( command, postCommand )
    " Structure here like in s:Argdo().

    let l:originalBufNr = bufnr('')

    let l:save_more = &more
    set nomore

    let s:errors = []

    " The :bufdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	let l:isEnableSyntax = s:IsInteractiveCommand(a:command)
	bufdo call s:ArgExecute(a:command, a:postCommand, l:isEnableSyntax)
    catch /^Vim\%((\a\+)\)\=:E/
	call add(s:errors, [-1, bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    endtry

    silent! execute l:originalBufNr . 'buffer'

    call s:ErrorsToQuickfix('bufdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', s:errors[0][1], bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:bufferNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[1]')))
	call ingo#msg#ErrorMsg(printf('%d error%s in buffer%s %s', len(s:errors), (len(s:errors) == 1 ? '' : 's'), (len(l:bufferNumbers) == 1 ? '' : 's'), join(l:bufferNumbers, ', ')))
    endif

    let &more = l:save_more
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
	call ingo#msg#VimExceptionMsg()
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

function! ArgsAndMore#ArgsNegated( bang, filePatternsString )
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
	execute l:chdirCommand escapings#fnameescape(getcwd())

	execute 'argdelete' join(l:argNegationGlobs)
	execute 'first' . a:bang
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry
endfunction



function! ArgsAndMore#ArgsList( isBang, fileglob )
    let l:isFullPath = (! empty(a:fileglob) || a:isBang)
    if ! empty(a:fileglob)
	let l:pattern = ingo#regexp#FromWildcard(a:fileglob, '')
    endif

    echohl Title
    echo '   cnt	file'
    echohl None

    for l:argIdx in range(argc())
	let l:argFilespec = argv(l:argIdx)
	if l:isFullPath
	    let l:argFilespec = fnamemodify(l:argFilespec, ':p')
	endif
	if ! empty(a:fileglob) && (! a:isBang && l:argFilespec !~ l:pattern || a:isBang && l:argFilespec =~ l:pattern)
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
"   a:excommand	    Ex command to be invoked
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
	call ingo#msg#ErrorMsg('No items')
	return
    endif

    if ! a:isArgAdd && argc() > 0
	silent execute printf('1,%dargdelete', argc())
    endif

    let l:addedBufnrs = {}
    let l:filespecs = []
    let l:existingArguments = ingo#collections#ToDict(argv())
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

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
