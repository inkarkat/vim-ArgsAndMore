" ArgsAndMore/Iteration.vim: Commands for iteration over arguments etc. that is more than a simple wrapper.
"
" DEPENDENCIES:
"   - ingo/buffer.vim autoload script
"   - ingo/collections.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/window/quickfix.vim autoload script
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.10.003	12-Feb-2015	Factor out s:SetQuickfix() from
"				s:ErrorsToQuickfix().
"				Replace s:GetCurrentQuickfixIdx() with different
"				algorithm that counts the quickfix entries for a
"				skipped buffer (by using the current index to
"				go forward through the quickfix list until
"				another buffer is encountered), avoiding the
"				costly re-determining of the current index.
"				Clone quickfix entries of skipped buffers over
"				to the fix command quickfix list.
"				s:DetermineSkippedEntries() already knows the
"				skipped indices and just needs to return the
"				entries for ArgsAndMore#Iteration#Quickfix() to
"				accumulate. To keep the errors of non-skipped
"				entries in the right position, these need to be
"				interspersed; s:ConsumeErrors() does this during
"				skipping, and once more after iteration for the
"				remaining ones.
"   2.10.002	11-Feb-2015	ENH: Implement :CDoFixEntry command via
"				additional a:fixCommand argument on
"				ArgsAndMore#Iteration#QuickfixDo().
"				Correct error reporting of :CDo... commands to
"				list entries (renamed from "locations") without
"				off-by-one, and additionally the buffer(s).
"				Extend s:ArgOrBufExecute() to pass in quickfix
"				entry index, to capture this also when the
"				individual a:command fails.
"   2.10.001	11-Feb-2015	file creation from autoload/ArgsAndMore.vim
let s:save_cpo = &cpo
set cpo&vim

function! s:sort( list )
    return sort(a:list, 'ingo#collections#numsort')
endfunction
function! s:JoinCommands( commands )
    return join(
    \   map(a:commands, '"hide " . v:val'),
    \   '|'
    \)
endfunction
function! s:RestoreAlternateBuffer( restoreCommands )
    if bufnr('#') != -1
	if v:version == 704 && has('patch605') || v:version > 704
	    call add(a:restoreCommands, 'let @# = ' . bufnr('#'))
	else
	    " Since the # register is read-only, we have to briefly revisit the
	    " buffer before the last command that restores the original buffer.
	    call insert(a:restoreCommands, bufnr('#') . 'buffer', -1)
	endif
    endif
endfunction
function! s:BufferListRestoreCommand()
    let l:restoreCommands = [bufnr('') . 'buffer']
    call s:RestoreAlternateBuffer(l:restoreCommands)

    return s:JoinCommands(l:restoreCommands)
endfunction
function! s:ArgumentListRestoreCommand()
    let l:restoreCommands = []

    " Restore the current argument index.
    if argidx() < argc()    " The index can be beyond if arguments have been :argadd'ed, but not yet visited.
	call add(l:restoreCommands, (argidx() + 1) . 'argument')
    endif

    " When the current file isn't in the argument list, restore that buffer,
    " too.
    " argidx() doesn't tell whether we're in the N'th file of the argument list,
    " or in an unrelated file. Need to compare the actual filenames to be sure.
    if argc() == 0 || argv(argidx()) !=# expand('%')
	call add(l:restoreCommands, bufnr('') . 'buffer')
    endif

    call s:RestoreAlternateBuffer(l:restoreCommands)
"****D echomsg '****' string(l:restoreCommands)
    return s:JoinCommands(l:restoreCommands)
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
function! s:SetQuickfix( command, entries )
    if len(a:entries) == 0
	return
    endif

    silent execute 'doautocmd QuickFixCmdPre' a:command | " Allow hooking into the quickfix update.
	call setqflist(a:entries)
    silent execute 'doautocmd QuickFixCmdPost' a:command | " Allow hooking into the quickfix update.
endfunction
function! s:ErrorsToQuickfix( command )
    call s:SetQuickfix(a:command, map(copy(s:errors), 's:ErrorToQuickfixEntry(v:val)'))
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
    \   ingo#buffer#IsPersisted() &&
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
function! s:ArgOrBufExecute( command, postCommand, isEnableSyntax, ... )
    if a:isEnableSyntax
	call s:EnableSyntaxHighlightingForInteractiveCommands(a:command)
    endif
    let l:location = (a:0 ? a:1 : argidx())
    let l:isSuccess = 1

    try
	let v:errmsg = ''
	execute a:command
	if ! empty(v:errmsg)
	    call add(s:errors, [l:location, bufnr(''), v:errmsg, line('.'), col('.')]) " As this is used for both arguments and buffers, record both.
	    let l:isSuccess = 0
	endif
	if ! empty(a:postCommand)
	    let v:errmsg = ''
	    execute a:postCommand
	    if ! empty(v:errmsg)
		call add(s:errors, [l:location, bufnr(''), v:errmsg, line('.'), col('.')])
		let l:isSuccess = 0
	    endif
	endif
    catch /^Vim\%((\a\+)\)\=:/
	call add(s:errors, [l:location, bufnr(''), ingo#msg#MsgFromVimException(), line('.'), col('.')])
	call ingo#msg#VimExceptionMsg()
	let l:isSuccess = 0
    catch /^ArgsAndMore: Aborted/
	throw v:exception
    catch
	call add(s:errors, [l:location, bufnr(''), v:exception, line('.'), col('.')])
	call ingo#msg#ErrorMsg(v:exception)
	let l:isSuccess = 0
    endtry

    call ArgsAndMore#AfterExecute()

    return l:isSuccess
endfunction
function! ArgsAndMore#Iteration#Argdo( range, command, postCommand )
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
    let l:isAborted = 0

    " The :argdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	" Individual commands need to be enclosed in try..catch, or the :argdo
	" iteration will be aborted. (We can't use :silent! because we want to
	" see the error message.)
	let l:isEnableSyntax = s:IsInteractiveCommand(a:command)
	execute a:range . 'argdo call s:ArgOrBufExecute(a:command, a:postCommand, l:isEnableSyntax)'
    catch /^Vim\%((\a\+)\)\=:/
	call add(s:errors, [argidx(), bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    catch /^ArgsAndMore: Aborted/
	" This internal exception is thrown to stop the iteration through the
	" argument list.
	let l:isAborted = 1
    endtry

    if ! l:isAborted
	silent! execute l:restoreCommand
    endif

    call s:ErrorsToQuickfix('argdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', (s:errors[0][0] + 1), bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:argumentNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[0] + 1')))
	call ingo#msg#ErrorMsg(printf('%d error%s in argument%s %s',
	\   len(s:errors), (len(s:errors) == 1 ? '' : 's'),
	\   (len(l:argumentNumbers) == 1 ? '' : 's'), join(l:argumentNumbers, ', ')
	\))
    endif

    " To avoid a hit-enter prompt, we have to restore this _after_ the summary
    " error message.
    let &more = l:save_more
endfunction
if v:version < 704 || v:version == 704 && ! has('patch530')
function! s:ArgIterate( startArg, endArg, command, postCommand )
    " Structure here like in ArgsAndMore#Iteration#Argdo().

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

    let s:range = [a:startArg, a:endArg]
    let s:errors = []
    let l:isAborted = 0

    try
	for l:arg in range(a:startArg, a:endArg)
	    " This is not :argdo; the printed error messages will be overwritten
	    " by the messages resulting from the switch to the next argument. To
	    " avoid this and keep both file changes as well as error messages
	    " interspersed on the screen, capture the output from the file
	    " change and :echo it ourselves.
	    redir => l:nextArgumentOutput
		silent execute l:arg . 'argument'
	    redir END
	    let l:nextArgumentOutput = substitute(l:nextArgumentOutput, '^\_s*', '', '')
	    if ! empty(l:nextArgumentOutput)
		echo l:nextArgumentOutput
	    endif

	    call s:ArgOrBufExecute(a:command, a:postCommand, 0)  " Without :argdo, we control the syntax suppression; no need to enable syntax during iteration.
	endfor
    catch /^Vim\%((\a\+)\)\=:/
	call add(s:errors, [argidx(), bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    catch /^ArgsAndMore: Aborted/
	" This internal exception is thrown to stop the iteration through the
	" argument list.
	let l:isAborted = 1
    finally
	redir END

	if exists('l:undoSuppressSyntax')
	    set eventignore-=Syntax
	endif
    endtry

    if ! l:isAborted
	silent! execute l:restoreCommand
    endif

    call s:ErrorsToQuickfix('argdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', (s:errors[0][0] + 1), bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:argumentNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[0] + 1')))
	call ingo#msg#ErrorMsg(printf('%d error%s in argument%s %s',
	\   len(s:errors), (len(s:errors) == 1 ? '' : 's'),
	\   (len(l:argumentNumbers) == 1 ? '' : 's'), join(l:argumentNumbers, ', ')
	\))
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
function! ArgsAndMore#Iteration#ArgdoWrapper( isNoRangeGiven, command, postCommand )
    if a:isNoRangeGiven
	call ArgsAndMore#Iteration#Argdo('', a:command, a:postCommand)
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
endif

function! ArgsAndMore#Iteration#ArgdoErrors()
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
function! ArgsAndMore#Iteration#ArgdoDeleteSuccessful()
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
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#msg#VimExceptionMsg()
    endtry

    echo printf('Deleted %d successfully processed from %d arguments', (l:originalArgNum - len(l:argIdxDict)), l:originalArgNum)
endfunction

function! ArgsAndMore#Iteration#Bufdo( range, command, postCommand )
    " Structure here like in ArgsAndMore#Iteration#Argdo().

    let l:restoreCommand = s:BufferListRestoreCommand()

    let l:save_more = &more
    set nomore

    let s:errors = []

    " The :bufdo must be enclosed in try..catch to handle errors from buffer
    " switches (e.g. "E37: No write since last change" when :set nohidden and
    " the command modified, but didn't update the buffer).
    try
	let l:isEnableSyntax = s:IsInteractiveCommand(a:command)
	execute a:range 'bufdo call s:ArgOrBufExecute(a:command, a:postCommand, l:isEnableSyntax)'
    catch /^Vim\%((\a\+)\)\=:/
	call add(s:errors, [-1, bufnr(''), ingo#msg#MsgFromVimException()])
	call ingo#msg#VimExceptionMsg()
    endtry

    silent! execute l:restoreCommand

    call s:ErrorsToQuickfix('bufdo')
    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('%d %s: %s', s:errors[0][1], bufname(s:errors[0][1]), s:errors[0][2]))
    elseif len(s:errors) > 1
	let l:bufferNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[1]')))
	call ingo#msg#ErrorMsg(printf('%d error%s in buffer%s %s',
	\   len(s:errors), (len(s:errors) == 1 ? '' : 's'),
	\   (len(l:bufferNumbers) == 1 ? '' : 's'), join(l:bufferNumbers, ', ')
	))
    endif

    let &more = l:save_more
endfunction



function! s:GetCurrentQuickfixCnt( isLocationList )
    let l:currentEntryCommand = (a:isLocationList ? 'll' : 'cc')

    " The :cc command will echo something like "(3 of 42): ..." when the
    " quickfix window isn't open.
    let v:statusmsg = ''
    silent execute 'keepalt' l:currentEntryCommand

    if ! empty(v:statusmsg)
	let l:currentCnt = matchstr(v:statusmsg, '^(\zs\d\+\ze ')
	if ! empty(l:currentCnt)
	    return str2nr(l:currentCnt)
	endif
    endif

    " Else, the quickfix window must be open, so we have to go there and read
    " off the current line.
    let l:openCommand = (a:isLocationList ? 'l' : 'c') . 'open'

    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    try
	noautocmd execute l:openCommand
	let l:currentCnt = line('.')
	noautocmd execute l:previousWinNr . 'wincmd w'
	noautocmd execute l:originalWinNr . 'wincmd w'
	return l:currentCnt
    catch /^Vim\%((\a\+)\)\=:/
	return -1
    endtry
endfunction
function! s:Get( list, idx, default )
    let l:entry = get(a:list, a:idx, a:default)
    return (empty(l:entry) ? a:default : l:entry)
endfunction
function! s:GetQuickfixList( isLocationList )
    return (a:isLocationList ? getloclist(0) : getqflist())
endfunction
function! s:GetQuickfixEntry( isLocationList, quickfixIdx )
    return get(s:GetQuickfixList(a:isLocationList), a:quickfixIdx, {})
endfunction
function! s:ConsumeErrors( consumedErrorsCnt )
    let l:consumedErrors = s:errors[ a:consumedErrorsCnt : ]
    let l:consumedErrorsCnt = len(s:errors)
    return [l:consumedErrorsCnt, map(l:consumedErrors, 's:ErrorToQuickfixEntry(v:val)')]
endfunction
function! s:DetermineSkippedEntries( isLocationList, quickfixIdx, consumedErrorsCnt )
    let l:bufNr = bufnr('')
    let l:idx = a:quickfixIdx
    let l:list = s:GetQuickfixList(a:isLocationList)
    if l:list[l:idx].bufnr != l:bufNr
	call ingo#msg#WarningMsg(printf('Cannot associate buffer %d with entry %d; some entries may get lost.', l:bufNr, a:quickfixIdx))
	return [a:quickfixIdx, 0, []]
    endif

    " Progress until the last entry belonging to the current (skipped) buffer.
    while l:idx + 1 < len(l:list) && l:list[l:idx + 1].bufnr == l:bufNr
	let l:idx += 1
    endwhile

    let [l:consumedErrorsCnt, l:consumedErrors] = s:ConsumeErrors(a:consumedErrorsCnt)
    return [l:idx, l:consumedErrorsCnt, l:consumedErrors + l:list[ a:quickfixIdx : l:idx ]]
endfunction
function! s:JoinErrorWithQuickfix( isLocationList, errorMessage, quickfixIdx )
    let l:qfEntry = s:GetQuickfixEntry(a:isLocationList, a:quickfixIdx)
    let l:qfText = get(l:qfEntry, 'text', '')
    let l:qfCol = (empty(l:qfEntry) ? 0 : ingo#window#quickfix#TranslateVirtualColToByteCount(l:qfEntry))
    return [
    \   a:quickfixIdx,
    \   s:Get(l:qfEntry, 'bufnr', bufnr('')),
    \   a:errorMessage . (empty(l:qfText) ? '' : ' on: ' . l:qfText),
    \   s:Get(l:qfEntry, 'lnum', line('.')),
    \   (empty(l:qfCol) ? col('.') : l:qfCol)
    \]
endfunction
function! ArgsAndMore#Iteration#QuickfixDo( isLocationList, isFiles, fixCommand, startBufNr, endBufNr, command, postCommand )
    let l:prefix = (a:isLocationList ? 'l' : 'c')

    " Structure here like in ArgsAndMore#Iteration#Argdo().

    " Don't go to other windows / tabs that may already display a location.
    let l:save_switchbuf = &switchbuf
    set switchbuf=

    if ingo#window#quickfix#IsQuickfixList()
	" With empty 'switchbuf', the :cfirst command will find another window.
	" Since we don't want to emulate Vim's built-in algorithm to know this
	" target beforehand, just restore the original buffer (via the alternate
	" file), and go back to the quickfix window. This means that we're
	" losing the buffer's alternate file.
	let l:restoreCommand = s:JoinCommands(['buffer #', l:prefix . 'open'])
    else
	let l:restoreCommand = s:BufferListRestoreCommand()
    endif

    if ! s:IsInteractiveCommand(a:command) && ! s:IsSyntaxSuppressed()
	" Emulate the behavior of the built-in :argdo to disable syntax
	" highlighting during to speed up the iteration, but consider our own
	" enhancement, the exception for interactive commands.
	let l:undoSuppressSyntax = 1
	set eventignore+=Syntax
    endif

    let l:save_more = &more
    set nomore

    let s:errors = []
    let l:entries = []
    let l:idx = -1
    let l:seenBufNrs = {}
    let l:isAborted = 0
    let l:consumedErrorsCnt = 0

    let l:hasRange = (! empty(a:startBufNr) && ! empty(a:endBufNr))
    let l:firstIteration = l:prefix . 'first'
    let l:nextFileIteration = l:prefix . 'nfile'
    let l:nextIteration = l:prefix . (a:isFiles ? 'nfile' : 'next')
    let l:iterationCommand = l:firstIteration
    let l:originalEntryCommand = ''
    try
	let l:originalCnt = s:GetCurrentQuickfixCnt(a:isLocationList)
	if l:originalCnt != -1
	    let l:originalEntryCommand = s:JoinCommands([l:originalCnt . l:prefix . l:prefix])
	endif

	while 1
	    " This is not :argdo; the printed error messages will be overwritten
	    " by the messages resulting from the switch to the next location. To
	    " avoid this and keep both file changes as well as error messages
	    " interspersed on the screen, capture the output from the file
	    " change and :echo it ourselves.
	    let v:statusmsg = ''
	    redir => l:nextLocationOutput
		silent execute 'keepalt' l:iterationCommand
	    redir END
	    let l:idx += 1

	    if l:hasRange && (bufnr('') < a:startBufNr || bufnr('') > a:endBufNr) ||
	    \   a:isFiles && has_key(l:seenBufNrs, bufnr(''))
		" Entry outside of range; skip to next file (before echoing, so
		" that the iteration to that location is suppressed).
		" Or we're iterating over files and that particular buffer
		" already appeared earlier in the list. (Though the list is
		" usually sorted, it is not necessarily (e.g. one can use
		" :caddexpr to add entries out-of-band).)
		let l:iterationCommand = l:nextFileIteration

		" As we're skipping over quickfix entries, our simple l:idx
		" counter doesn't properly track the quickfix list any more.
		" Find out how many entries have been skipped (and store those
		" for a fix command).
		let [l:idx, l:consumedErrorsCnt, l:newEntries] = s:DetermineSkippedEntries(a:isLocationList, l:idx, l:consumedErrorsCnt)
		let l:entries += l:newEntries
		continue
	    endif

	    let l:nextLocationOutput = substitute(l:nextLocationOutput, '^\_s*', '', '')
	    if ! empty(l:nextLocationOutput)
		echo l:nextLocationOutput
	    elseif ! empty(v:statusmsg)
		" XXX: :redir only captures the :cfirst message, not the
		" subsequent :cnfile ones, also not :cnext when it switches to
		" another file. But we have that one in v:statusmsg, so fall
		" back to that.
		echo v:statusmsg
	    endif

	    let l:changedtick = b:changedtick
	    let l:isSuccess = s:ArgOrBufExecute(a:command, a:postCommand, 0, -1)
	    if l:isSuccess
		if ! empty(a:fixCommand) && b:changedtick == l:changedtick
		    " No change means the attempted fix failed.
		    call add(s:errors, s:JoinErrorWithQuickfix(a:isLocationList, 'Attempted fix failed', l:idx))
		    call ingo#msg#ErrorMsg('Attempted fix failed')
		endif
	    else
		" s:ArgOrBufExecute() has already captured the actual error;
		" append the text from the quickfix entry now to complete the
		" picture.
		let l:qfText = get(s:GetQuickfixEntry(a:isLocationList, l:idx), 'text', '')
		if ! empty(l:qfText)
		    let s:errors[-1][2] .= ' on: ' . l:qfText
		endif
	    endif

	    let l:seenBufNrs[bufnr('')] = 1

	    let l:iterationCommand = l:nextIteration
	endwhile
    catch /^Vim\%((\a\+)\)\=:E42:/ " E42: No Errors
	call ingo#msg#VimExceptionMsg()
	let l:isAborted = 1 " No need to restore; we haven't actually started iterating.
    catch /^Vim\%((\a\+)\)\=:E553:/ " E553: No more items
	" This is the expected end of iteration.
    catch /^Vim\%((\a\+)\)\=:/
	call add(s:errors, s:JoinErrorWithQuickfix(a:isLocationList, ingo#msg#MsgFromVimException(), l:idx))
	call ingo#msg#VimExceptionMsg()
    catch /^ArgsAndMore: Aborted/
	" This internal exception is thrown to stop the iteration through the
	" argument list.
	let l:isAborted = 1
    finally
	redir END

	if ! l:isAborted
	    " Restore the original quickfix entry.
	    silent! noautocmd execute 'keepalt' l:originalEntryCommand
	endif

	if exists('l:undoSuppressSyntax')
	    set eventignore-=Syntax
	endif

	let &switchbuf = l:save_switchbuf
    endtry

    if ! l:isAborted
	" Then restore the original buffer.
	silent! execute l:restoreCommand
    endif

    if ! empty(a:fixCommand)
	let l:entries += s:ConsumeErrors(l:consumedErrorsCnt)[1]
	call s:SetQuickfix(a:fixCommand, l:entries)
    endif

    if len(s:errors) == 1
	call ingo#msg#ErrorMsg(printf('entry %d, buffer %d %s: %s',
	\   (s:errors[0][0] == -1 ? '?' : s:errors[0][0] + 1),
	\   s:errors[0][1],
	\   bufname(s:errors[0][1]), s:errors[0][2]
	\))
    elseif len(s:errors) > 1
	let l:entryNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[0] == -1 ? "?" : v:val[0] + 1')))
	let l:bufferNumbers = s:sort(ingo#collections#Unique(map(copy(s:errors), 'v:val[1]')))
	call ingo#msg#ErrorMsg(printf('%d error%s in entr%s %s; buffer%s %s',
	\   len(s:errors), (len(s:errors) == 1 ? '' : 's'),
	\   (len(l:entryNumbers) == 1 ? 'y' : 'ies'), join(l:entryNumbers, ', '),
	\   (len(l:bufferNumbers) == 1 ? '' : 's'), join(l:bufferNumbers, ', ')
	\))
    endif

    let &more = l:save_more
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
