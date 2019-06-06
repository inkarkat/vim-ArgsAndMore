ARGS AND MORE
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

This plugin supports you with batch processing many files by extending the
built-in :windo, :argdo, etc. commands. You can filter the argument list,
add files _not_ matching a pattern, convert between arguments and quickfix
list, and apply arbitrary Ex commands (also partially) via :Argdo, then
analyze any errors and retry on an argument list where the successfully
processed arguments have been removed.

### SEE ALSO

### RELATED WORKS

- The :ArgsNegated command was inspired by the following Stack Overflow
  question:
    http://stackoverflow.com/questions/11547662/how-can-i-negate-a-glob-in-vim
- The https://github.com/nelstrom/vim-qargs plugin has a :Qargs command
  similar (but more simplistic) than :CListToArgs.
- Pretty Args ([vimscript #4681](http://www.vim.org/scripts/script.php?script_id=4681)) provides an :Arg command which takes
  filename-modifiers to print a shortened argument list, e.g. just the
  filenames.
- JustDo ([vimscript #4981](http://www.vim.org/scripts/script.php?script_id=4981)) provides a :BufDo command that skips unmodifiable
  buffers.

USAGE
------------------------------------------------------------------------------

    :[range]Bufdo[!] {cmd}  Execute {cmd} in each buffer in the buffer list, then
                            return back to the original one.
                            Any encountered errors are also put into the
                            quickfix list.

    :[range]BufdoWrite[!] {cmd}
                            Execute {cmd} in each buffer in the buffer list and
                            automatically persist any changes (:update).

    :[range]Windo {cmd}     Execute {cmd} in each window, then return back to the
                            original one.

    :[range]Winbufdo {cmd}  Execute {cmd} in each different buffer shown in one of
                            the windows in the current tab page (once per buffer),
                            then return back to the original one.

    :[range]Tabdo {cmd}     Execute {cmd} once in each tab page, then return back
                            to the original one.

    :[range]Tabwindo {cmd}  Execute {cmd} in each open window on each tab page,
                            then return back to the original one.

    :[range]Argdo[!] {cmd}  Execute {cmd} for each file in the argument list, then
                            return back to the original file and argument.
                            [range] is emulated for older Vim versions, but can
                            only be used interactively (not in scripts).

                            In contrast to :argdo, this also avoids the
                            hit-enter prompt (all files will be processed
                            without further interaction from you), and an error
                            summary will be printed.
                            To work on the errors / arguments with errors, you can
                            use :ArgdoErrors and :ArgdoDeleteSuccessful.
                            Also, any encountered errors are put into the
                            quickfix list.

    :[range]ArgdoWrite[!] {cmd}
                            Execute {cmd} in each buffer in the argument list and
                            automatically persist any changes (:update).
    :[range]ArgdoConfirmWrite[!] {cmd}
                            Like :ArgdoWrite, but confirm each write, allowing
                            to review the automatically applied changes of {cmd}
                            before persisting them. When you quit the argument
                            processing before the last argument, this will not
                            return to the original file (to make it easier to
                            process the remaining arguments again).

    :ArgdoErrors            List all error messages that occurred during the last
                            :Argdo command, and for each unique error, print the
                            argument number and filespec.

    :ArgdoDeleteSuccessful  Delete those arguments from the argument list that
                            didn't cause any error messages during the last
                            :Argdo command.

    :[range]ArgsFilter {expr}
                            Apply the filter() of {expr} to the argument list,
                            and keep only those where {expr} yields true. This
                            allows you to :argdelete multiple arguments at once
                            and to delete without specifying the full filename.

    :[range]ArgsFilterDo[!] {expr}
                            Apply the filter() of {expr} to the argument list
                            within the context of each argument, and keep only
                            those where {expr} yields true. In contrast to
                            :ArgsFilter, this allows filtering based on buffer
                            contents (or buffer variables, buffer settings).
                            For example, remove all arguments whose buffers have
                            more than 100 lines:
                                :ArgsFilterDo line('$') <= 100

    :ArgsNegated[!] {arglist}
                            Define all files except {arglist} as the new argument
                            list and edit the first one.

    :[range]ArgsList[!]     List each argument number and filespec in a neat list
                            (not just one after the other as :args). With [!],
                            expand all arguments to absolute filespecs.
    :[range]ArgsList[!] {glob}
                            List each argument number and filespec that matches
                            (with [!]: does not match) {glob} in a neat list.
                            Matching and printing is done to the full filespec.

    :[range]ArgsToQuickfix  Show all arguments as a quickfix list.

    :CListToArgs            Convert the files in the quickfix list to arguments.
    :[count]CListToArgsAdd

    :LListToArgs            Convert the files in the window's location list to
    :[count]LListToArgsAdd  arguments.

    :CList[!], :LList[!]    List each file that has listed errors in the quickfix
                            / location list in a neat list. With [!], expand all
                            to absolute filespecs.
    :CList[!] {glob}        List each file that has listed errors in the quickfix
    :LList[!] {glob}        / location list that matches (with [!]: does not
                            match) {glob} in a neat list. Matching and printing is
                            done to the full filespec.

    :[range]CDoEntry {cmd}  Execute {cmd} on each entry in the quickfix /
    :[range]LDoEntry {cmd}  location list (limited to buffers in [range]).

    :[range]CDoFile {cmd}   Execute {cmd} once on each file that appears in the
    :[range]LDoFile {cmd}   quickfix / location list (limited to buffers in
                            [range]).

    :[range]CDoFixEntry {cmd}
    :[range]LDoFixEntry {cmd}
                            Execute {cmd} on each entry in the quickfix / location
                            list (limited to buffers in [range]). If the {cmd}
                            does not abort and changes the buffer (i.e. increases
                            b:changedtick), that entry is removed from the
                            quickfix / location list. Else, the original entry is
                            augmented with error information. (Entries for buffers
                            outside [range] are kept as-is.)

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-ArgsAndMore
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim ArgsAndMore*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.035 or
  higher.

CONFIGURATION
------------------------------------------------------------------------------

After each {cmd}, an extra Ex command (sequence) can be executed. By default,
a delay of 100 ms is introduced here. This allows you to abort an interactive
:s///c substitution by pressing CTRL-C twice within the delay. (Without the
delay, it may or may not abort.) To also persist any changes to the buffer,
you could use:

    let g:ArgsAndMore_AfterCommand = 'update | sleep 100m'

During :argdo, syntax highlighting of freshly loaded buffers is turned off for
performance reasons, but for interactive commands, it is useful to have syntax
highlighting. Therefore, the :Argdo and :Bufdo commands detect interactive
commands and overrule the default syntax suppression then. By default, this
applies to the :substitute command with the :s\_c flag; you can adapt the
pattern to match other commands, too:

    let g:ArgsAndMore_InteractiveCommandPattern = '...'

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-ArgsAndMore/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### 2.11    RELEASEME
- Support [range] on :ArgsFilter.
- Add :ArgsFilterDo variant of :ArgsFilter.
- Use proper error aborting for :Bufdo, :Argdo, and :[CL]Do\*.
- FIX: Avoid creating jump on :bufdo / :windo / :tabdo.
- Support [!] on :Bufdo[Write], :Argdo[[Confirm]Write], ArgsFilterDo to force
  iteration when the current buffer has unpersisted modifications and 'hidden'
  isn't set (just like with the built-in :argdo, :bufdo).

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.035!__

##### 2.10    08-Mar-2015
- FIX: :Bufdo..., :Win..., :Tab... in recent Vim 7.4 defaults to wrong range.
  Forgot -range=% argument.
- Add :CDoFile, :CDoEntry, :CDoFixEntry commands for iteration over quickfix /
  location list.

##### 2.00    09-Feb-2015
- Use ingo#msg#WarningMsg().
- ENH: Keep previous (last accessed) window on :Windo. Thanks to Daniel Hahler
  for the patch.
- ENH: Keep alternate buffer (#) on :Argdo and :Bufdo commands. Thanks to
  Daniel Hahler for the suggestion.
- Handle modified buffers together with :set nohidden when restoring the
  original buffer after :Argdo and :Bufdo by using :hide.
- FIX: :Argdo may fail to restore the original buffer. Ensure that argidx()
  actually points to valid argument; this may not be the case when arguments
  have only been :argadd'ed, but not visited yet.
- Support the -addr=arguments attribute in Vim 7.4.530 or later for :Argdo...
  commands. With that, relative addressing can also be used non-interactively.
- Support ranges in :Bufdo..., :Windo..., :Tabdo... if supported by Vim.
- Support ranges in :ArgsList and :ArgsToQuickfix if supported by Vim.
- Switch to ingo#regexp#fromwildcard#AnchoredToPathBoundaries() to correctly
  enforce path boundaries in :ArgsList {glob}.

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.023!__

##### 1.22    24-Mar-2014
- Add :CList and :LList, analog to :ArgsList.
- FIX: :ArgsList printed "cnt" is zero-based, not 1-based.
- Add :ArgdoConfirmWrite variant of :ArgdoWrite.
- Also catch custom exceptions and errors caused by the passed user command
  (or configured post-command).

__You need to update to ingo-library
  ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.017!__

##### 1.21    22-Nov-2013
- FIX: Use the rules for the /pattern/ separator as stated in :help E146 in
  the default of g:ArgsAndMore\_InteractiveCommandPattern.
- Minor: Exclude further special buffers from syntax enabling.
- :ArgsList also handles \*\* and [...] wildcards.
- Move escapings.vim into ingo-library.

__You need to update to ingo-library
  ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.014!__

##### 1.20    19-Jul-2013
- Add dependency to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)).

__You need to separately
  install ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.007 (or higher)!__
- ENH: Add :ArgdoWrite and :BufdoWrite variants that also perform an automatic
  :update.
- ENH: Add errors from :Argdo and :Bufdo to the quickfix list to allow easier
  rework.
- Avoid script errors when using :Argdo 3s/foo/bar
- Minor: Change :Argdo[Write] -range=-1 default check to use &lt;count&gt;, which
  maintains the actual -1 default, and therefore also delivers correct results
  when on line 1.
- ENH: Enable syntax highlighting on :Argdo / :Bufdo on freshly loaded buffers
  when the command is an interactive one (:s///c, according to
  g:ArgsAndMore\_InteractiveCommandPattern), but for performance reasons not in
  the general case.
- In :{range}Argdo, emulate the behavior of the built-in :argdo to disable
  syntax highlighting during to speed up the iteration, but consider our own
  enhancement, the exception for interactive commands.
- Minor: Make matchstr() robust against 'ignorecase'.

##### 1.11    15-Jan-2013
- FIX: Factor out s:sort() and also use numerical sort in the one missed case.

##### 1.10    10-Sep-2012
- Add g:ArgsAndMore\_AfterCommand hook before buffer switching and use this by
  default to add a small delay, which allows for aborting an interactive s///c
  substitution by pressing CTRL-C twice within the delay.
- Add :Bufdo command for completeness, to get the new hook, and the enhanced
  error reporting of :Argdo.

##### 1.01    27-Aug-2012
- Do not use &lt;f-args&gt; because of its unescaping behavior.
- FIX: "E480: No match" on :ArgsNegated with ../other/path relative argument;
  need to issue a dummy :chdir to convert relative args before doing the
  :argdelete.

##### 1.00    30-Jul-2012
- First published version.

##### 0.01    26-Aug-2008
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2012-2019 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
