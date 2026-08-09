---
title: Zsh Options Reference
tags:
  - manpage
  - zsh
  - cli
  - config
---

A concise, example-driven explanation of every zsh option, in the same groups and order as the `zshoptions(1)` man page (zsh 5.9). Each entry lists what the option does, a short example, and a scenario where it's useful.

**How to read the markers:** `<D>` = on by default in all emulations; `<C>` `<K>` `<S>` `<Z>` = on by default only in csh, ksh, sh, or zsh emulation respectively. A `(-x)` after a name is the single-letter form. Set with `setopt NAME`, clear with `unsetopt NAME` (or `setopt NO_NAME`). Option names are case-insensitive and ignore underscores, so `allexport`, `ALL_EXPORT`, and `A__lleXP_ort` are all the same.

---

## Changing Directories

### AUTO_CD (`-J`)

- **What it does:** If a command can't be executed normally and its name is a directory, `cd` into that directory instead. Only applies when `SHIN_STDIN` is set (commands read from standard input).
- **Example:**
```zsh
setopt AUTO_CD
/tmp        # no such command; zsh runs `cd /tmp` instead
..          # moves up one directory
```
- **When it's useful:** Fast interactive navigation where you type a directory name alone to jump into it.

### AUTO_PUSHD (`-N`)

- **What it does:** Makes `cd` push the previous directory onto the directory stack.
- **Example:**
```zsh
setopt AUTO_PUSHD
cd /var
cd /etc
dirs -v     # stack now has /var and previous dirs, navigable with pushd/popd
```
- **When it's useful:** Keeping a browsable history of visited directories so you can pop back with `pushd -N`.

### CDABLE_VARS (`-T`)

- **What it does:** If a `cd` argument (or implied `cd` via `AUTO_CD`) isn't a directory and doesn't start with a slash, zsh tries expanding it as if preceded by `~` (filename expansion).
- **Example:**
```zsh
setopt CDABLE_VARS
proj=/home/me/projects
cd proj     # expands to ~proj => /home/me/projects
```
- **When it's useful:** Jumping to frequently used directories stored in named variables without typing full paths.

### CD_SILENT

- **What it does:** Never prints the working directory after a `cd`, whether explicit or implied. Normally `cd` prints the directory when the argument was `-`, a stack entry, or a name found under `CDPATH`. Overrides the printing effects of `POSIX_CD`.
- **Example:**
```zsh
setopt CD_SILENT
cd -        # switches to previous dir but prints nothing
```
- **When it's useful:** Keeping the terminal clean when using `CDPATH` or `cd -` in scripts and prompts.

### CHASE_DOTS

- **What it does:** When a path contains `..` that would otherwise cancel the previous segment, instead resolve the path to the physical directory. Overridden by `CHASE_LINKS`.
- **Example:**
```zsh
setopt CHASE_DOTS
# /foo/bar is a symlink to /alt/rod
cd /foo/bar/..   # goes to /alt (physical parent), not /foo
```
- **When it's useful:** When you want `..` to follow the real filesystem structure rather than the logical symlinked path.

### CHASE_LINKS (`-w`)

- **What it does:** Resolves symbolic links to their true values when changing directory. Also implies `CHASE_DOTS`, so a `..` segment refers to the physical parent even after a symlinked segment.
- **Example:**
```zsh
setopt CHASE_LINKS
# /foo/bar is a symlink to /alt/rod
cd /foo/bar
pwd         # prints /alt/rod, the resolved physical path
```
- **When it's useful:** When you need `pwd` and relative navigation to reflect the real path behind symlinks.

### POSIX_CD `<K>` `<S>`

- **What it does:** Makes `cd`, `chdir`, and `pushd` more POSIX-compatible: the shell tests the local directory (`.`) only after all `cdpath` entries, and `cd`/`chdir` no longer treat `{+|-}n` arguments as stack entries. It also changes when the new directory is printed — no longer limited to interactive shells, and any use of a `CDPATH` component (including `.`) triggers printing.
- **Example:**
```zsh
setopt POSIX_CD
# with cdpath=(/work), cd sub prefers /work/sub over ./sub
cd sub      # /work/sub chosen after cdpath tested; dir is printed
```
- **When it's useful:** Running scripts that expect standard POSIX `cd` and `CDPATH` semantics.

### PUSHD_IGNORE_DUPS

- **What it does:** Prevents pushing multiple copies of the same directory onto the directory stack.
- **Example:**
```zsh
setopt PUSHD_IGNORE_DUPS
pushd /a
pushd /b
pushd /a    # existing /a is not duplicated on the stack
```
- **When it's useful:** Keeping the directory stack tidy and free of redundant entries.

### PUSHD_MINUS

- **What it does:** Exchanges the meanings of `+` and `-` when used with a number to specify a directory in the stack.
- **Example:**
```zsh
setopt PUSHD_MINUS
pushd -0    # with the option, `-` now counts from the other end of the stack
```
- **When it's useful:** When you prefer to reference stack entries counting from the opposite end than the default.

### PUSHD_SILENT (`-E`)

- **What it does:** Does not print the directory stack after `pushd` or `popd`.
- **Example:**
```zsh
setopt PUSHD_SILENT
pushd /tmp   # changes directory but prints no stack listing
```
- **When it's useful:** Reducing noise when scripting or automating directory-stack operations.

### PUSHD_TO_HOME (`-D`)

- **What it does:** Makes `pushd` with no arguments behave like `pushd $HOME`.
- **Example:**
```zsh
setopt PUSHD_TO_HOME
pushd        # pushes current dir and changes to $HOME
```
- **When it's useful:** When you want bare `pushd` to jump home instead of swapping the top two stack entries.

---

## Completion

### ALWAYS_LAST_PROMPT `<D>`

- **What it does:** Controls whether completion-listing functions return to the last prompt based on the presence of a numeric argument. If unset, they return with a numeric argument; if set, they return when given no numeric argument.
- **Example:**
```zsh
setopt ALWAYS_LAST_PROMPT
# Press TAB to list completions, then the cursor returns to your last prompt line
# instead of leaving you scrolled down past the listing
ls /usr/<TAB>
```
- **When it's useful:** When you want the shell to keep editing at your prompt after showing a completion list instead of pushing your command down the screen.

### ALWAYS_TO_END

- **What it does:** When a completion is performed with the cursor inside a word and a full completion is inserted, moves the cursor to the end of the word. Applies both when a single match is inserted and when menu completion is performed.
- **Example:**
```zsh
setopt ALWAYS_TO_END
# Type "fooBAR" with cursor after "foo", TAB completes to "foobaz"
# cursor jumps to end -> "foobaz|" rather than staying mid-word
foo<TAB>
```
- **When it's useful:** When editing in the middle of a word and you want the cursor to land at the word's end after completing, so you can keep typing.

### AUTO_LIST (`-9`) `<D>`

- **What it does:** Automatically lists the choices when a completion is ambiguous.
- **Example:**
```zsh
setopt AUTO_LIST
ls /e<TAB>   # ambiguous: immediately prints the list of matches (etc/, export/, ...)
```
- **When it's useful:** When you want to see all matching options right away on an ambiguous TAB without pressing TAB a second time.

### AUTO_MENU `<D>`

- **What it does:** Automatically switches to menu completion after the second consecutive completion request, such as pressing TAB repeatedly. Overridden by MENU_COMPLETE.
- **Example:**
```zsh
setopt AUTO_MENU
ls fi<TAB>   # first TAB lists matches
# <TAB>      # second TAB starts cycling through matches (menu completion)
```
- **When it's useful:** When you want repeated TAB presses to cycle through candidates rather than just re-listing them.

### AUTO_NAME_DIRS

- **What it does:** Any parameter set to the absolute name of a directory immediately becomes a name for that directory, usable by `%~` and related prompt sequences and available for `~`-completion. Otherwise the parameter must first be used in the `~param` form.
- **Example:**
```zsh
setopt AUTO_NAME_DIRS
proj=/Users/me/projects/app
cd $proj
print -P '%~'   # prompt shows "~proj" instead of the full path
cd ~pro<TAB>    # completes ~proj
```
- **When it's useful:** When you keep directory paths in variables and want prompts and `~`-completion to reference them by name automatically.

### AUTO_PARAM_KEYS `<D>`

- **What it does:** When a parameter name is completed and a following character (normally a space) is auto-inserted, and the next typed character is one that must directly follow the name (like `}` or `:`), the auto-added character is deleted so the typed character abuts the name. Brace expansion is handled similarly, removing an added `,` when `}` is typed.
- **Example:**
```zsh
setopt AUTO_PARAM_KEYS
echo $PA<TAB>   # completes "$PATH " with a trailing space
# type ":"      -> the space is removed, giving "$PATH:" directly
```
- **When it's useful:** When completing parameter names you then want to follow immediately with `}`, `:`, etc., without manually deleting the inserted space.

### AUTO_PARAM_SLASH `<D>`

- **What it does:** When a completed parameter's content is the name of a directory, adds a trailing slash instead of a space.
- **Example:**
```zsh
setopt AUTO_PARAM_SLASH
dir=/tmp
cd $di<TAB>   # completes to "$dir/" (slash, not space) since it's a directory
```
- **When it's useful:** When completing directory-valued variables and you want to continue the path immediately, e.g. `$dir/subdir`.

### AUTO_REMOVE_SLASH `<D>`

- **What it does:** When the last character from a completion is a slash and the next character typed is a word delimiter, another slash, or a command-ending character (like `;` or `&`), the slash is removed.
- **Example:**
```zsh
setopt AUTO_REMOVE_SLASH
ls somedir<TAB>   # completes "somedir/"
# type ";"        -> trailing slash removed, giving "somedir;"
```
- **When it's useful:** When a completed directory slash would be unwanted before a delimiter or command terminator, so you don't have to backspace it.

### BASH_AUTO_LIST

- **What it does:** On an ambiguous completion, automatically lists choices when the completion function is called twice in succession, taking precedence over AUTO_LIST and respecting LIST_AMBIGUOUS. With AUTO_MENU set, menu behaviour then starts on the third press. Does not work with MENU_COMPLETE, since repeated calls immediately cycle the list.
- **Example:**
```zsh
setopt BASH_AUTO_LIST
ls fi<TAB>   # first TAB: nothing listed
# <TAB>      # second TAB: lists the ambiguous matches (bash-style)
```
- **When it's useful:** When you prefer bash-like behaviour where the completion list only appears on the second TAB press.

### COMPLETE_ALIASES

- **What it does:** Prevents command-line aliases from being internally substituted before completion is attempted, making the alias a distinct command for completion purposes.
- **Example:**
```zsh
setopt COMPLETE_ALIASES
alias gco='git checkout'
gco <TAB>   # completes based on "gco" itself, not expanded "git checkout"
```
- **When it's useful:** When you define custom completions for an alias and don't want it expanded to its underlying command first.

### COMPLETE_IN_WORD

- **What it does:** If unset, the cursor is moved to the end of the word when completion starts. If set, the cursor stays in place and completion is done from both ends of the word.
- **Example:**
```zsh
setopt COMPLETE_IN_WORD
# Type "fobar" with cursor after "fo", TAB completes using both sides
foo<TAB>bar   # matches candidates that fit the prefix and suffix around the cursor
```
- **When it's useful:** When editing in the middle of a word and you want completion to respect the text on both sides of the cursor.

### GLOB_COMPLETE

- **What it does:** When the current word contains a glob pattern, generates matches like completion and cycles through them (as with MENU_COMPLETE) instead of inserting all expansion results, treating the word as if a `*` were appended (or inserted at the cursor with COMPLETE_IN_WORD). It uses pattern matching rather than globbing, so it works for any completion, but while a pattern is present matching control (e.g. case-insensitive or anchored matching) cannot be used.
- **Example:**
```zsh
setopt GLOB_COMPLETE
ls f*o<TAB>   # cycles through matches for the pattern instead of inserting all at once
```
- **When it's useful:** When you want to use glob patterns in a word but step through the resulting matches one at a time rather than expanding them all.

### HASH_LIST_ALL `<D>`

- **What it does:** Ensures the entire command path is hashed before any command completion or spelling correction is attempted. This makes the first completion slower but avoids false reports of spelling errors.
- **Example:**
```zsh
setopt HASH_LIST_ALL
gi<TAB>   # first completion hashes all of $PATH, so all commands are found reliably
```
- **When it's useful:** When you want accurate command completion and spelling correction without false "not found" reports, at the cost of a slower first completion.

### LIST_AMBIGUOUS `<D>`

- **What it does:** Works alongside AUTO_LIST or BASH_AUTO_LIST: if there is an unambiguous prefix to insert, that is done without displaying a list, so auto-listing only happens when nothing would be inserted. With BASH_AUTO_LIST, this delays the list to the function's third call.
- **Example:**
```zsh
setopt AUTO_LIST LIST_AMBIGUOUS
ls foo<TAB>   # inserts the common prefix silently; only lists once nothing more can be added
```
- **When it's useful:** When you want completion to fill in as much of a common prefix as possible before bothering to show a list.

### LIST_BEEP `<D>`

- **What it does:** Beeps on an ambiguous completion; more precisely it forces the completion widgets to return status 1 on ambiguity, which beeps if the BEEP option is also set (behaviour may differ from user-defined widgets).
- **Example:**
```zsh
setopt LIST_BEEP
ls f<TAB>   # ambiguous completion triggers an audible beep (if BEEP is set)
```
- **When it's useful:** When you want an audible cue that a completion was ambiguous; unset it to silence the beep on TAB.

### LIST_PACKED

- **What it does:** Tries to make the completion list smaller (fewer lines) by printing matches in columns of differing widths.
- **Example:**
```zsh
setopt LIST_PACKED
ls /usr/bin/<TAB>   # matches shown in tightly packed variable-width columns
```
- **When it's useful:** When completion lists are long and you want them to occupy fewer lines on screen.

### LIST_ROWS_FIRST

- **What it does:** Lays out matches in completion lists sorted horizontally, so the second match is to the right of the first rather than beneath it.
- **Example:**
```zsh
setopt LIST_ROWS_FIRST
ls /etc/<TAB>   # matches read left-to-right across rows instead of down columns
```
- **When it's useful:** When you prefer reading completion candidates across rows rather than down columns.

### LIST_TYPES (`-X`) `<D>`

- **What it does:** When listing files as possible completions, shows the type of each file with a trailing identifying mark.
- **Example:**
```zsh
setopt LIST_TYPES
ls /<TAB>   # directories shown with a trailing "/", executables with "*", etc.
```
- **When it's useful:** When you want to distinguish directories, executables, and other file types directly in the completion listing.

### MENU_COMPLETE (`-Y`)

- **What it does:** On an ambiguous completion, immediately inserts the first match instead of listing or beeping, then replaces it with the next match on each further request, cycling back to the first after the last. `reverse-menu-complete` loops the other direction. Overrides AUTO_MENU.
- **Example:**
```zsh
setopt MENU_COMPLETE
ls fi<TAB>   # inserts first match immediately
# <TAB>      # replaces it with the second match, and so on, cycling around
```
- **When it's useful:** When you want each TAB to directly insert a candidate and cycle through them rather than showing a list first.

### REC_EXACT (`-S`)

- **What it does:** If the string on the command line exactly matches one of the possible completions, it is accepted even when another completion (that string plus more) also matches.
- **Example:**
```zsh
setopt REC_EXACT
# with candidates "foo" and "foobar"
foo<TAB>   # "foo" is accepted exactly rather than being extended to "foobar"
```
- **When it's useful:** When an exact match should be taken as-is instead of being ambiguously extended to a longer candidate.

---

## Expansion and Globbing

### BAD_PATTERN (`+2`) `<C>` `<Z>`

- **What it does:** Prints an error message when a filename-generation pattern is badly formed. If unset, the malformed pattern is left unchanged.
- **Example:**
```zsh
setopt BAD_PATTERN
ls [abc      # error: bad pattern (unterminated bracket)
# with the option unset, `[abc` is passed through literally
```
- **When it's useful:** Catching typos in glob patterns at the shell rather than silently passing a broken pattern to a command.

### BARE_GLOB_QUAL `<Z>`

- **What it does:** In a glob pattern, treats a trailing set of parentheses as a qualifier list, provided it contains no `|`, `(`, or (if special) `~` characters.
- **Example:**
```zsh
setopt BARE_GLOB_QUAL
ls *(.)      # (.) is a qualifier: matches plain files only
ls *(/)      # (/) matches directories only
```
- **When it's useful:** Selecting files by type or attribute (directories, symlinks, executables) directly in a glob.

### BRACE_CCL

- **What it does:** Expands brace expressions that would not otherwise undergo brace expansion into a lexically ordered list of all the enclosed characters.
- **Example:**
```zsh
setopt BRACE_CCL
echo {abc}   # -> a b c  (each character, lexically ordered)
```
- **When it's useful:** Generating a sequence of individual characters from a set without listing them comma-separated.

### CASE_GLOB `<D>`

- **What it does:** Makes globbing (filename generation) case sensitive. If unset, the presence of any globbing-special character triggers case-insensitive matching.
- **Example:**
```zsh
setopt CASE_GLOB
ls cvs*      # matches cvs... but not CVS
unsetopt CASE_GLOB
ls cvs*      # now also matches CVS
```
- **When it's useful:** Turn it off to match filenames regardless of case, e.g. finding `README` when you type `readme*`.

### CASE_MATCH `<D>`

- **What it does:** Makes regular expressions using the zsh/regex module (including `=~` matches) case sensitive.
- **Example:**
```zsh
setopt CASE_MATCH
[[ Hello =~ hello ]] && echo yes || echo no   # no
unsetopt CASE_MATCH
[[ Hello =~ hello ]] && echo yes || echo no   # yes
```
- **When it's useful:** Disable it for case-insensitive `=~` matching when validating user input of unknown case.

### CASE_PATHS

- **What it does:** When set, path components that contain no special filename-generation characters are always matched case sensitively, restricting NO_CASE_GLOB to only the components that contain globbing characters. It has no effect on case-insensitive filesystems.
- **Example:**
```zsh
unsetopt CASE_GLOB
setopt CASE_PATHS
ls Foo/bar*   # Foo matched case-sensitively; only bar* is case-insensitive
```
- **When it's useful:** Combining case-insensitive globbing with case-sensitive fixed path prefixes so literal directory names aren't accidentally cross-matched.

### CSH_NULL_GLOB `<C>`

- **What it does:** If a filename-generation pattern has no matches, deletes it from the argument list without error, reporting an error only if every pattern in the command fails to match. Overrides NOMATCH.
- **Example:**
```zsh
setopt CSH_NULL_GLOB
ls *.txt *.md    # if *.txt has no match it's dropped; error only if both fail
```
- **When it's useful:** Running a command over several optional glob patterns where you want it to proceed as long as at least one matches.

### EQUALS `<Z>`

- **What it does:** Performs `=` filename expansion (expanding `=cmd` to the full path of the command).
- **Example:**
```zsh
setopt EQUALS
echo =ls     # -> /bin/ls  (full path to the ls command)
```
- **When it's useful:** Quickly getting the resolved path of a command inline without calling `which`.

### EXTENDED_GLOB

- **What it does:** Treats the `#`, `~`, and `^` characters as part of patterns for filename generation and similar contexts. An initial unquoted `~` still triggers named directory expansion.
- **Example:**
```zsh
setopt EXTENDED_GLOB
ls ^*.o      # all files NOT ending in .o
ls *.c~foo.c # all .c files except foo.c
```
- **When it's useful:** Powerful negation and exclusion patterns, like listing everything except certain files.

### FORCE_FLOAT

- **What it does:** Treats arithmetic constants as floating point even without a decimal point, converts integer variables to floating point in arithmetic expressions, and converts integers in any base.
- **Example:**
```zsh
setopt FORCE_FLOAT
echo $(( 1 / 2 ))   # -> 0.5  instead of 0
```
- **When it's useful:** Doing division and math where you always want fractional results without writing explicit decimals.

### GLOB (`+F`, ksh: `+f`) `<D>`

- **What it does:** Performs filename generation (globbing).
- **Example:**
```zsh
setopt GLOB
ls *.txt     # expands to matching files
unsetopt GLOB
ls *.txt     # * passed literally, no expansion
```
- **When it's useful:** Turning globbing off temporarily when you need to pass literal `*` or `?` characters to a command.

### GLOB_ASSIGN `<C>`

- **What it does:** Performs globbing on the right-hand side of scalar assignments like `name=pattern`; if multiple words result, the parameter becomes an array. Provided for backwards compatibility only.
- **Example:**
```zsh
setopt GLOB_ASSIGN
foo=*        # foo globs the current directory; may become scalar or array
# recommended clearer form: foo=(*)
```
- **When it's useful:** Legacy scripts that rely on scalar-assignment globbing; new code should prefer `foo=(*)`.

### GLOB_DOTS (`-4`)

- **What it does:** Removes the requirement that a leading `.` in a filename be matched explicitly.
- **Example:**
```zsh
setopt GLOB_DOTS
ls *         # now also lists .bashrc, .config, etc.
```
- **When it's useful:** Listing or operating on dotfiles alongside regular files without a separate `.*` pattern.

### GLOB_STAR_SHORT

- **What it does:** When set and default zsh globbing is in effect, allows `**/*` to be abbreviated to `**` and `***/*` to `***`. A `/` immediately after `**`/`***` forces the unabbreviated form.
- **Example:**
```zsh
setopt GLOB_STAR_SHORT
ls **.c      # find any .c file in any subdirectory
ls ***.c     # same, but also follow symbolic links
```
- **When it's useful:** More concise recursive globbing when searching a whole tree for files by extension.

### GLOB_SUBST `<C>` `<K>` `<S>`

- **What it does:** Treats characters resulting from parameter expansion as eligible for filename expansion and generation, and characters from command substitution as eligible for filename generation. Braces (and commas within) do not become eligible.
- **Example:**
```zsh
setopt GLOB_SUBST
pat='*.txt'
echo $pat    # $pat now globs to matching .txt files
```
- **When it's useful:** Emulating other shells where variables holding patterns are re-globbed after expansion.

### HIST_SUBST_PATTERN

- **What it does:** Makes the `:s` and `:&` history modifiers use pattern matching instead of string matching, wherever history modifiers are valid (including glob qualifiers and parameters).
- **Example:**
```zsh
setopt HIST_SUBST_PATTERN
foo=file123
echo ${foo:s/[0-9]##/NUM/}   # -> fileNUM  (pattern-based substitution)
```
- **When it's useful:** Doing pattern-based (rather than literal) substitutions in history and parameter modifiers.

### IGNORE_BRACES (`-I`) `<S>`

- **What it does:** Disables brace expansion. For historical reasons it also includes the effect of the IGNORE_CLOSE_BRACES option.
- **Example:**
```zsh
setopt IGNORE_BRACES
echo {a,b,c}   # -> {a,b,c}  literally, no expansion
```
- **When it's useful:** Writing sh-compatible scripts where `{a,b}` should be treated literally.

### IGNORE_CLOSE_BRACES

- **What it does:** When neither this nor IGNORE_BRACES is set, a sole `}` is syntactically significant anywhere on the line (so no semicolon/newline is needed before a closing function brace). When either option is set, a closing brace is significant only in command position; unlike IGNORE_BRACES this does not disable brace expansion.
- **Example:**
```zsh
setopt IGNORE_CLOSE_BRACES
args() { echo $#; }   # closing `}` now needs a preceding `;`
# with the option unset, `args() { echo $# }` works
```
- **When it's useful:** Enforcing stricter, more portable function-definition syntax while keeping brace expansion.

### KSH_GLOB `<K>`

- **What it does:** In pattern matching, makes the interpretation of parentheses depend on a preceding `@`, `*`, `+`, `?`, or `!`.
- **Example:**
```zsh
setopt KSH_GLOB
ls !(*.o)    # ksh-style: everything except .o files
ls @(foo|bar).c   # foo.c or bar.c
```
- **When it's useful:** Running or porting ksh-style pattern syntax in zsh.

### MAGIC_EQUAL_SUBST

- **What it does:** Performs filename expansion on the `expression` part of any unquoted `anything=expression` argument after the command name (where `expression` has a leading `~` or `=`), passing it as a single ordinary argument. Respects KSH_TYPESET.
- **Example:**
```zsh
setopt MAGIC_EQUAL_SUBST
echo foo=~/bar:~/rod   # both ~ expand to your home directory
```
- **When it's useful:** Commands that take `key=path` arguments (like `make VAR=~/dir`) where you want `~` in the value expanded.

### MARK_DIRS (`-8`, ksh: `-X`)

- **What it does:** Appends a trailing `/` to all directory names produced by filename generation (globbing).
- **Example:**
```zsh
setopt MARK_DIRS
echo *       # directories appear as dir/ , files without a slash
```
- **When it's useful:** Visually distinguishing directories from files in glob output, or feeding trailing-slash paths to other tools.

### MULTIBYTE `<D>`

- **What it does:** Respects multibyte characters in strings, using the system library and current locale to count bytes per character; this affects pattern matching, parameter values, and delimiters. On by default if compiled with MULTIBYTE_SUPPORT. When off, one byte is always one character. It does not affect the shell's editor.
- **Example:**
```zsh
setopt MULTIBYTE
str='héllo'
echo ${#str}   # -> 5  (counts characters, not bytes)
```
- **When it's useful:** Correctly counting and matching text in UTF-8 and other multibyte locales; unset it only to examine raw byte data.

### NOMATCH (`+3`) `<C>` `<Z>`

- **What it does:** Prints an error when a filename-generation pattern has no matches, instead of leaving it unchanged in the argument list. Also applies to file expansion of an initial `~` or `=`.
- **Example:**
```zsh
setopt NOMATCH
ls *.nonexistent   # error: no matches found
unsetopt NOMATCH
ls *.nonexistent   # pattern passed through literally
```
- **When it's useful:** Catching mistyped patterns instead of silently running a command with a literal `*` argument.

### NULL_GLOB (`-G`)

- **What it does:** If a filename-generation pattern has no matches, deletes it from the argument list instead of reporting an error. Overrides NOMATCH.
- **Example:**
```zsh
setopt NULL_GLOB
ls *.nonexistent   # pattern removed; ls runs with no glob argument
```
- **When it's useful:** Loops or commands over optional file patterns where a missing match should just produce nothing rather than an error.

### NUMERIC_GLOB_SORT

- **What it does:** Sorts matched filenames containing numbers numerically rather than lexicographically.
- **Example:**
```zsh
setopt NUMERIC_GLOB_SORT
echo file*   # -> file1 file2 file10  (not file1 file10 file2)
```
- **When it's useful:** Processing numbered files (logs, frames, parts) in true numeric order.

### RC_EXPAND_PARAM (`-P`)

- **What it does:** For array expansions like `foo${xx}bar` where `xx` is `(a b c)`, substitutes `fooabar foobbar foocbar` instead of the default `fooa b cbar`. An empty array therefore removes all arguments.
- **Example:**
```zsh
setopt RC_EXPAND_PARAM
xx=(a b c)
echo foo${xx}bar   # -> fooabar foobbar foocbar
```
- **When it's useful:** Wrapping each array element with a common prefix and suffix in one expansion.

### REMATCH_PCRE

- **What it does:** Makes `=~` regular-expression matching use Perl-Compatible Regular Expressions from the PCRE library (requires the zsh/pcre module). If unset, `=~` uses the system libraries' extended regexp syntax.
- **Example:**
```zsh
setopt REMATCH_PCRE
[[ foo123 =~ '\d+' ]] && echo match   # PCRE \d works -> match
```
- **When it's useful:** Using richer PCRE features (like `\d`, lookahead) in `=~` matches.

### SH_GLOB `<K>` `<S>`

- **What it does:** Disables the special globbing meaning of `(`, `|`, `)`, and `<` for parameter/command substitution results and some other pattern contexts. If SH_GLOB is set but KSH_GLOB is not, subshell expressions in parentheses are allowed in some cases without a preceding space (e.g. `!(true)` acts like `! (true)`). Set by default when zsh is invoked as sh or ksh.
- **Example:**
```zsh
setopt SH_GLOB
echo !(true)   # treated as `! (true)` rather than a ksh negation glob
```
- **When it's useful:** Running sh/ksh scripts that rely on POSIX-style parenthesis handling.

### UNSET (`+u`, ksh: `+u`) `<K>` `<S>` `<Z>`

- **What it does:** Treats unset parameters as empty when substituting and as zero in arithmetic contexts. Otherwise referencing an unset parameter is an error.
- **Example:**
```zsh
setopt UNSET
echo ">$novar<"   # -> ><  (empty, no error)
unsetopt UNSET
echo ">$novar<"   # error: parameter not set
```
- **When it's useful:** Unset it (`set -u` style) to catch references to undefined variables in scripts.

### WARN_CREATE_GLOBAL

- **What it does:** Prints a warning when a global parameter is created inside a function by an assignment or in math context. Parameters explicitly made global with `typeset -g` do not warn.
- **Example:**
```zsh
setopt WARN_CREATE_GLOBAL
f() { x=1 }    # warning: x created as global inside f
f() { local x=1 }   # no warning
```
- **When it's useful:** Catching accidentally global variables that should have been declared `local` in functions.

### WARN_NESTED_VAR

- **What it does:** Prints a warning when a parameter from an enclosing function scope (or a global) is set in a function by assignment or in math context. Assignments to special parameters don't warn; `typeset -g` suppresses it (each time). Scope it to one function with `functions -W`.
- **Example:**
```zsh
setopt WARN_NESTED_VAR
toplevel() { local foo="in fn"; nested }
nested() { foo="in nested" }   # warning: overrides foo from toplevel
toplevel
```
- **When it's useful:** Detecting when a nested function unexpectedly clobbers a caller's local variable.

---

## History

### APPEND_HISTORY `<D>`

- **What it does:** Makes zsh sessions append their history to the history file instead of replacing it, so multiple parallel sessions all add their new entries. The file is still periodically re-written to trim it once it grows 20% beyond `$SAVEHIST`.
- **Example:**
```zsh
setopt APPEND_HISTORY
# Two shells open at once; each appends its commands on exit
# instead of overwriting the file, so no session's history is lost.
```
- **When it's useful:** When you run several terminal windows simultaneously and want to keep the history from all of them.

### BANG_HIST (`+K`) `<C>` `<Z>`

- **What it does:** Performs csh-style textual history expansion, treating the `!` character specially.
- **Example:**
```zsh
setopt BANG_HIST
ls /tmp
!!        # re-runs the previous command: ls /tmp
echo !$   # expands to the last argument of the previous line
```
- **When it's useful:** When you want quick shorthand like `!!` or `!$` to reuse previous commands and arguments.

### EXTENDED_HISTORY `<C>`

- **What it does:** Saves each command's beginning timestamp (seconds since the epoch) and its duration to the history file. The stored format is `: <beginning time>:<elapsed seconds>;<command>`.
- **Example:**
```zsh
setopt EXTENDED_HISTORY
sleep 2
# history file records e.g.: `: 1691500000:2;sleep 2`
```
- **When it's useful:** When you want to know when past commands ran and how long they took.

### HIST_ALLOW_CLOBBER

- **What it does:** Adds `|` to output redirections stored in the history, allowing history references to clobber files even when `CLOBBER` is unset.
- **Example:**
```zsh
setopt HIST_ALLOW_CLOBBER
echo hi > file.txt   # stored in history as `echo hi >| file.txt`
!!                   # re-running overwrites file.txt despite NO_CLOBBER
```
- **When it's useful:** When `NO_CLOBBER` is set but you still want recalled commands to be able to overwrite files.

### HIST_BEEP `<D>`

- **What it does:** Beeps in ZLE when a widget tries to access a history entry that isn't there.
- **Example:**
```zsh
setopt HIST_BEEP
# Press Up past the oldest history entry -> the terminal beeps.
```
- **When it's useful:** When you want an audible cue that you've hit the top or bottom of your history.

### HIST_EXPIRE_DUPS_FIRST

- **What it does:** When the internal history must be trimmed to fit a new command, this causes the oldest duplicated event to be discarded before any unique event is lost. Set `HISTSIZE` larger than `SAVEHIST` to leave room for the duplicates, otherwise it behaves like `HIST_IGNORE_ALL_DUPS` once history fills with unique events.
- **Example:**
```zsh
setopt HIST_EXPIRE_DUPS_FIRST
# HISTSIZE=2000, SAVEHIST=1000
# when trimming, repeated `ls` entries are dropped before unique commands.
```
- **When it's useful:** When you want to preserve unique commands longer by shedding duplicates first as history fills up.

### HIST_FCNTL_LOCK

- **What it does:** Uses the system's `fcntl` call to lock the history file when writing, instead of zsh's default ad-hoc locking. On recent systems this can improve performance and avoid history corruption on NFS.
- **Example:**
```zsh
setopt HIST_FCNTL_LOCK
# history file on an NFS-mounted home is locked via fcntl,
# avoiding corruption from concurrent writes.
```
- **When it's useful:** When your history file lives on NFS and you want to avoid corruption from concurrent shells.

### HIST_FIND_NO_DUPS

- **What it does:** When searching for history entries in the line editor, it won't display duplicates of a line already found, even if the duplicates aren't contiguous.
- **Example:**
```zsh
setopt HIST_FIND_NO_DUPS
# Ctrl-R searching skips repeated matches of the same command,
# so each successive result is different.
```
- **When it's useful:** When you use incremental history search and don't want to cycle through the same command repeatedly.

### HIST_IGNORE_ALL_DUPS

- **What it does:** When a new command line duplicates an older one, the older copy is removed from the list, even if it isn't the immediately previous event.
- **Example:**
```zsh
setopt HIST_IGNORE_ALL_DUPS
ls
cd /tmp
ls        # earlier `ls` is removed; only this one remains in history
```
- **When it's useful:** When you want at most one copy of any command stored in history.

### HIST_IGNORE_DUPS (`-h`)

- **What it does:** Does not add a command line to history if it duplicates the previous event.
- **Example:**
```zsh
setopt HIST_IGNORE_DUPS
ls
ls        # this consecutive duplicate is not stored
```
- **When it's useful:** When you repeatedly run the same command back-to-back and don't want consecutive duplicates cluttering history.

### HIST_IGNORE_SPACE (`-g`)

- **What it does:** Removes command lines from history when the first character is a space, or when an expanded normal alias has a leading space (global and suffix aliases don't count). The command lingers in internal history until the next command is entered, so you can briefly reuse or edit it; type a space and press return to make it vanish immediately.
- **Example:**
```zsh
setopt HIST_IGNORE_SPACE
 secret-command --password foo   # leading space -> not saved to history
```
- **When it's useful:** When you want to run a sensitive command without it being recorded in your history.

### HIST_LEX_WORDS

- **What it does:** Splits history lines read from files in a manner similar to normal shell command-line parsing rather than on all whitespace, so quoted-whitespace arguments and word references are handled accurately. This can be slow for large history files.
- **Example:**
```zsh
setopt HIST_LEX_WORDS
# a stored line: echo "hello world"
!:1       # correctly references `"hello world"` as one word
```
- **When it's useful:** When you rely on word references into history and your commands contain quoted whitespace arguments.

### HIST_NO_FUNCTIONS

- **What it does:** Removes function definitions from the history list. The function lingers in internal history until the next command is entered, letting you briefly reuse or edit the definition.
- **Example:**
```zsh
setopt HIST_NO_FUNCTIONS
myfunc() { echo hi; }   # definition not kept in saved history
```
- **When it's useful:** When you define functions interactively but don't want their bodies cluttering your saved history.

### HIST_NO_STORE

- **What it does:** Removes the `history` (`fc -l`) command from the history list when invoked. It lingers in internal history until the next command is entered, so you can briefly reuse or edit the line.
- **Example:**
```zsh
setopt HIST_NO_STORE
history           # the `history` command itself isn't saved
```
- **When it's useful:** When you frequently list history and don't want those listing commands themselves recorded.

### HIST_REDUCE_BLANKS

- **What it does:** Removes superfluous blanks from each command line before it's added to the history list.
- **Example:**
```zsh
setopt HIST_REDUCE_BLANKS
echo    hello     world   # stored as `echo hello world`
```
- **When it's useful:** When you want tidy, normalized history entries regardless of extra spacing you typed.

### HIST_SAVE_BY_COPY `<D>`

- **What it does:** When enabled (the default), zsh re-writes the history file by writing a copy named `$HISTFILE.new` and renaming it over the old file; if unset, it truncates and writes in place instead. When writing a copy, zsh preserves the old file's permissions and group but refuses to write if it would change the file's owner. Disabling it risks losing history if zsh is interrupted during the save.
- **Example:**
```zsh
setopt HIST_SAVE_BY_COPY
# on re-write, zsh creates $HISTFILE.new then renames it,
# so an interrupted save can't corrupt the original file.
```
- **When it's useful:** When you want safe, atomic history-file rewrites that survive an interrupted save.

### HIST_SAVE_NO_DUPS

- **What it does:** When writing out the history file, omits older commands that duplicate newer ones.
- **Example:**
```zsh
setopt HIST_SAVE_NO_DUPS
# internal history has duplicates, but the saved file
# keeps only the newest copy of each repeated command.
```
- **When it's useful:** When you want a clean, deduplicated history file on disk even if the in-memory list has duplicates.

### HIST_VERIFY

- **What it does:** When the user enters a line with history expansion, it doesn't execute directly; instead it performs the expansion and reloads the line into the editing buffer.
- **Example:**
```zsh
setopt HIST_VERIFY
!!        # expands to the previous command in the buffer, awaiting Enter
```
- **When it's useful:** When you want to review and confirm what a `!` history expansion produces before running it.

### INC_APPEND_HISTORY

- **What it does:** Works like `APPEND_HISTORY` except new history lines are added to `$HISTFILE` incrementally as soon as they are entered, rather than waiting for the shell to exit. The file is still periodically re-written to trim it once it grows 20% beyond `$SAVEHIST`.
- **Example:**
```zsh
setopt INC_APPEND_HISTORY
ls        # written to $HISTFILE immediately, not at shell exit
```
- **When it's useful:** When you want commands saved right away so a crashed or force-closed shell doesn't lose recent history.

### INC_APPEND_HISTORY_TIME

- **What it does:** A variant of `INC_APPEND_HISTORY` that, where possible, writes the entry out after the command finishes so its duration is recorded correctly in `EXTENDED_HISTORY` format; the entry isn't available immediately to other shells. It's only useful with `INC_APPEND_HISTORY` and `SHARE_HISTORY` off, as the three options are mutually exclusive.
- **Example:**
```zsh
setopt INC_APPEND_HISTORY_TIME
sleep 3   # written after it finishes, recording the 3s duration
```
- **When it's useful:** When you want incremental appending but also accurate command-duration timestamps in the history file.

### SHARE_HISTORY `<K>`

- **What it does:** Imports new commands from the history file and appends your typed commands to it (like `INC_APPEND_HISTORY`, which should be off when this is on), outputting lines with `EXTENDED_HISTORY`-style timestamps. History movement commands visit imported lines by default, toggleable via the `set-local-history` zle binding; for finer control, turn this off, enable `INC_APPEND_HISTORY`/`INC_APPEND_HISTORY_TIME`, and import manually with `fc -RI`.
- **Example:**
```zsh
setopt SHARE_HISTORY
# In shell A: run `deploy prod`
# In shell B: press Up -> `deploy prod` appears, imported live
```
- **When it's useful:** When you want all your open shells to share one live, continuously synchronized history.

---

## Initialisation

### ALL_EXPORT (`-a`, ksh: `-a`)

- **What it does:** Automatically exports all parameters that are defined after this option is set.
- **Example:**
```zsh
setopt ALL_EXPORT
FOO=bar          # FOO is automatically exported to the environment
env | grep FOO   # shows FOO=bar without an explicit `export`
```
- **When it's useful:** When running a script whose variables all need to be visible to child processes without writing `export` for each one.

### GLOBAL_EXPORT `<Z>`

- **What it does:** When set, passing `-x` to `declare`, `float`, `integer`, `readonly`, and `typeset` (but not `local`) also implies `-g`, so exported parameters are not made local to the enclosing function unless already local or `+g` is given. When unset, exported parameters are made local like any other. Set by default for backward compatibility, but relying on it is not recommended.
- **Example:**
```zsh
setopt GLOBAL_EXPORT
f() { typeset -x VAR=hi }   # VAR is exported globally, survives after f returns
f; echo $VAR                # prints: hi
# Note: `export VAR=hi` always sets both -x and -g (most portable)
```
- **When it's useful:** When a function should export an environment variable that persists beyond the function's scope for later commands.

### GLOBAL_RCS (`+d`) `<D>`

- **What it does:** When unset, the global startup files `/etc/zprofile`, `/etc/zshrc`, `/etc/zlogin`, and `/etc/zlogout` are not run. It can be disabled and re-enabled at any time, including from within local startup files like `.zshrc`.
- **Example:**
```zsh
unsetopt GLOBAL_RCS   # placed in .zshenv: skip system-wide /etc/zsh* startup files
# subsequent global rc files are not sourced for this shell
```
- **When it's useful:** When you want a shell to ignore system-wide configuration and rely only on your personal dotfiles.

### RCS (`+f`) `<D>`

- **What it does:** After `/etc/zshenv` is sourced at startup, controls whether the remaining startup files (`.zshenv`, `/etc/zprofile`, `.zprofile`, `/etc/zshrc`, `.zshrc`, `/etc/zlogin`, `.zlogin`, `.zlogout`) are sourced. If unset, `/etc/zshenv` is still sourced but none of the others are; it can be set at any time to prevent the remaining, not-yet-executed startup files from being sourced.
- **Example:**
```zsh
unsetopt RCS   # in /etc/zshenv: skip all further startup files for this shell
# .zshenv, .zprofile, .zshrc, etc. are not sourced
```
- **When it's useful:** When launching a minimal, non-customized shell (e.g., for a script or test) that should skip all user and system rc files.

---

## Input/Output

### ALIASES `<D>`

- **What it does:** Expands aliases.
- **Example:**
```zsh
setopt ALIASES
alias ll='ls -l'
ll   # expands to `ls -l`
```
- **When it's useful:** Keep this on so shorthand aliases like `ll` or `gs` work interactively.

### CLOBBER (`+C`, ksh: `+C`) `<D>`

- **What it does:** Allows `>` redirection to truncate existing files; otherwise `>!` or `>|` is required. When unset (and APPEND_CREATE also unset), `>>!` or `>>|` is needed to create a file via append.
- **Example:**
```zsh
setopt CLOBBER
echo hi > file.txt    # overwrites file.txt freely
unsetopt CLOBBER
echo bye > file.txt   # error: file exists; must use >| to truncate
```
- **When it's useful:** Unset it to protect yourself from accidentally overwriting existing files with `>`.

### CLOBBER_EMPTY

- **What it does:** Only used when CLOBBER is unset (and is itself set by default); when set, allows zero-length regular files to be overwritten. Another process may write to the file between the check and the write, so it is unsafe for files written asynchronously.
- **Example:**
```zsh
unsetopt CLOBBER
setopt CLOBBER_EMPTY
: > empty.txt          # create a zero-length file
echo data > empty.txt  # allowed because the file is empty
```
- **When it's useful:** Lets you overwrite empty placeholder files even with CLOBBER off, without needing `>|`.

### CORRECT (`-0`)

- **What it does:** Tries to correct the spelling of command names. With HASH_LIST_ALL unset or unreadable path directories, it may falsely flag commands the first time they are used. The `CORRECT_IGNORE` variable can hold a pattern of words never offered as corrections.
- **Example:**
```zsh
setopt CORRECT
sl -l   # prompts: correct 'sl' to 'ls'? [nyae]
```
- **When it's useful:** Catches typos in command names before running the wrong thing.

### CORRECT_ALL (`-O`)

- **What it does:** Tries to correct the spelling of all arguments on a line, not just the command. The `CORRECT_IGNORE_FILE` variable can hold a pattern of file names never offered as corrections.
- **Example:**
```zsh
setopt CORRECT_ALL
cat /etc/hsots   # prompts to correct 'hsots' to 'hosts'
```
- **When it's useful:** Helpful when you frequently mistype file or path arguments, not just command names.

### DVORAK

- **What it does:** Uses the Dvorak keyboard layout (instead of qwerty) as the basis for examining spelling mistakes for the CORRECT and CORRECT_ALL options and the `spell-word` editor command.
- **Example:**
```zsh
setopt DVORAK CORRECT
# correction suggestions now assume Dvorak key adjacency
```
- **When it's useful:** For Dvorak typists who want spelling correction tuned to their actual key positions.

### FLOW_CONTROL `<D>`

- **What it does:** When unset, disables output flow control via start/stop characters (usually `^S`/`^Q`) in the shell's editor.
- **Example:**
```zsh
unsetopt FLOW_CONTROL
# ^S no longer freezes the terminal; freed up for keybindings
```
- **When it's useful:** Unset it to free `^S`/`^Q` for editor keybindings and avoid accidentally freezing your terminal.

### IGNORE_EOF (`-7`)

- **What it does:** Prevents exiting on end-of-file, requiring `exit` or `logout` instead; ten consecutive EOFs will still exit to avoid hanging on a lost tty. Also lets ZLE widgets be bound to EOF (normally Control-D) without the usual warning message (normal widgets only, not completion widgets).
- **Example:**
```zsh
setopt IGNORE_EOF
# pressing Ctrl-D at the prompt no longer closes the shell
```
- **When it's useful:** Prevents accidentally closing your shell by pressing Ctrl-D.

### INTERACTIVE_COMMENTS (`-k`) `<K>` `<S>`

- **What it does:** Allows comments (with `#`) even in interactive shells.
- **Example:**
```zsh
setopt INTERACTIVE_COMMENTS
echo hi   # this trailing comment is now ignored at the prompt
```
- **When it's useful:** Lets you paste or type commands with inline comments directly at the interactive prompt.

### HASH_CMDS `<D>`

- **What it does:** Notes each command's location the first time it runs so later invocations skip the path search; if unset, no path hashing is done at all. When CORRECT is set, commands not in the functions/aliases hash tables are still hashed to avoid false spelling errors.
- **Example:**
```zsh
setopt HASH_CMDS
ls   # location cached; subsequent `ls` calls skip the PATH search
```
- **When it's useful:** Speeds up repeated command invocations by avoiding redundant path lookups.

### HASH_DIRS `<D>`

- **What it does:** Whenever a command name is hashed, also hashes the directory containing it and all directories earlier in the path. Has no effect unless HASH_CMDS or CORRECT is set.
- **Example:**
```zsh
setopt HASH_DIRS
git   # hashes git's dir and all earlier PATH dirs at once
```
- **When it's useful:** Warms up the directory hash table to further speed up subsequent command lookups.

### HASH_EXECUTABLES_ONLY

- **What it does:** When hashing commands due to HASH_CMDS, checks that the file to be hashed is actually executable. Unset by default because with large or remote paths the extra tests can be slow.
- **Example:**
```zsh
setopt HASH_EXECUTABLES_ONLY
# non-executable files in PATH are not hashed as commands
```
- **When it's useful:** Use it when your PATH contains non-executable files you don't want treated as commands, and the extra checks aren't too costly.

### MAIL_WARNING (`-U`)

- **What it does:** Prints a warning message if a mail file has been accessed since the shell last checked it.
- **Example:**
```zsh
setopt MAIL_WARNING
# warns "the mail file has been read" if something touched your mailbox
```
- **When it's useful:** Alerts you when another process may have read or modified your mailbox.

### PATH_DIRS (`-Q`)

- **What it does:** Performs a path search even on command names containing slashes, so e.g. `X11/xinit` resolves via a PATH entry like `/usr/local/bin`. Commands starting with `/`, `./` or `../` are exempt; this also applies to the `.` and `source` builtins. Subdirectories of the current directory are always searched first, regardless of this option.
- **Example:**
```zsh
setopt PATH_DIRS
X11/xinit   # runs /usr/local/bin/X11/xinit if that dir is in PATH
```
- **When it's useful:** Lets you invoke commands stored in subdirectories of your PATH entries by relative name.

### PATH_SCRIPT `<K>` `<S>`

- **What it does:** When unset, a script passed as the first non-option argument must name the file to open; when set, a script without a directory path is looked for first in the current directory, then in the command path.
- **Example:**
```zsh
setopt PATH_SCRIPT
zsh myscript   # finds myscript in cwd, then in PATH
```
- **When it's useful:** Lets `zsh scriptname` locate scripts on your PATH like a regular command.

### PRINT_EIGHT_BIT

- **What it does:** Prints eight-bit characters literally in completion lists and similar output. Not needed if your system correctly reports the printability of eight-bit characters.
- **Example:**
```zsh
setopt PRINT_EIGHT_BIT
ls <TAB>   # accented filenames shown literally in completion list
```
- **When it's useful:** Fixes garbled display of non-ASCII (e.g. accented) filenames in completion lists on systems that mishandle eight-bit characters.

### PRINT_EXIT_VALUE (`-1`)

- **What it does:** Prints the exit value of programs that finish with a non-zero exit status. Only available at the command line in interactive shells.
- **Example:**
```zsh
setopt PRINT_EXIT_VALUE
false   # prints something like "zsh: exit 1"
```
- **When it's useful:** Makes failing commands visible interactively without manually checking `$?`.

### RC_QUOTES

- **What it does:** Allows the sequence `''` to signify a single quote inside singly quoted strings. Does not apply within `$'...'` strings, where a backslashed single quote is used instead.
- **Example:**
```zsh
setopt RC_QUOTES
echo 'it''s here'   # prints: it's here
```
- **When it's useful:** Lets you embed a literal single quote inside a single-quoted string without breaking out of the quotes.

### RM_STAR_SILENT (`-H`) `<K>` `<S>`

- **What it does:** Suppresses the confirmation query before executing `rm *` or `rm path/*`.
- **Example:**
```zsh
setopt RM_STAR_SILENT
rm *   # deletes without asking "sure you want to delete all files?"
```
- **When it's useful:** Use in scripts or when you want `rm *` to run without an interactive prompt.

### RM_STAR_WAIT

- **What it does:** When querying before `rm *` or `rm path/*`, first waits ten seconds and ignores anything typed during that time, so you can't reflexively answer `yes`. The wait/query can be avoided by expanding the `*` in ZLE (with tab).
- **Example:**
```zsh
setopt RM_STAR_WAIT
rm *   # waits 10s before accepting your y/n answer
```
- **When it's useful:** Guards against knee-jerk confirmation of a mass deletion you didn't really intend.

### SHORT_LOOPS `<C>` `<Z>`

- **What it does:** Allows the short forms of the `for`, `repeat`, `select`, `if`, and `function` constructs.
- **Example:**
```zsh
setopt SHORT_LOOPS
for i in 1 2 3; echo $i   # short form, no do/done needed
```
- **When it's useful:** Enables terse one-line control structures for quick interactive use.

### SHORT_REPEAT

- **What it does:** Allows the short form of `repeat` (as SHORT_LOOPS does) but without enabling short forms for the other constructs.
- **Example:**
```zsh
setopt SHORT_REPEAT
repeat 3 echo hi   # short repeat allowed; other short loops stay off
```
- **When it's useful:** Lets you use short `repeat` while keeping the other short-loop forms disabled for safety.

### SUN_KEYBOARD_HACK (`-L`)

- **What it does:** If a line ends with a backquote and there is an odd number of backquotes on the line, ignores the trailing backquote. The `KEYBOARD_HACK` variable lets you choose a different character to remove.
- **Example:**
```zsh
setopt SUN_KEYBOARD_HACK
echo hi`   # trailing stray backquote is ignored
```
- **When it's useful:** Helpful on keyboards where the backquote key sits awkwardly close to Return and gets hit by accident.

---

## Job Control

### AUTO_CONTINUE

- **What it does:** When set, stopped jobs that are removed from the job table with the `disown` builtin are automatically sent a `CONT` signal so they resume running.
- **Example:**
```zsh
setopt AUTO_CONTINUE
sleep 300 &        # start a background job
kill -STOP %1      # stop the job
disown %1          # removed from job table AND auto-continued (keeps running)
```
- **When it's useful:** When you want to detach a stopped job from the shell without having to manually resume it first.

### AUTO_RESUME (`-W`)

- **What it does:** Treats single-word simple commands without redirection as candidates for resuming an existing job of the same name.
- **Example:**
```zsh
setopt AUTO_RESUME
vim notes.txt      # suspend it with Ctrl-Z
vim                # bare command resumes the existing suspended vim job
```
- **When it's useful:** When you frequently suspend an editor or pager and want to type its bare name to jump back into it instead of `fg %vim`.

### BG_NICE (`-6`) `<C>` `<Z>`

- **What it does:** Runs all background jobs at a lower (nicer) scheduling priority. This option is set by default.
- **Example:**
```zsh
setopt BG_NICE
make -j8 &          # this background build runs at a lower priority
# foreground interactive work stays responsive
```
- **When it's useful:** When you launch heavy background jobs and want your interactive foreground work to keep priority.

### CHECK_JOBS `<Z>`

- **What it does:** Reports the status of background and suspended jobs before exiting a shell with job control; a second exit attempt then succeeds. The check is skipped if the previous command line ran a `jobs` command.
- **Example:**
```zsh
setopt CHECK_JOBS
sleep 300 &
exit               # warns about running jobs and refuses the first time
exit               # second attempt exits
```
- **When it's useful:** When you want a safety warning so you do not accidentally exit a shell and lose or kill background jobs.

### CHECK_RUNNING_JOBS `<Z>`

- **What it does:** Makes `CHECK_JOBS` check for both running and suspended jobs; when disabled, zsh checks only suspended jobs, matching bash's default. Has no effect unless `CHECK_JOBS` is set.
- **Example:**
```zsh
setopt CHECK_JOBS CHECK_RUNNING_JOBS
sleep 300 &
exit               # first exit warns even though the job is running (not suspended)
```
- **When it's useful:** When you want the exit warning to cover long-running background jobs, not just suspended ones.

### HUP `<Z>`

- **What it does:** Sends the `HUP` signal to running jobs when the shell exits.
- **Example:**
```zsh
setopt HUP
sleep 300 &
exit               # the background sleep receives HUP and is terminated
```
- **When it's useful:** When you want background jobs to be cleaned up automatically when you close the shell, rather than being left orphaned.

### LONG_LIST_JOBS (`-R`)

- **What it does:** Prints job notifications in the long format by default (including the process ID).
- **Example:**
```zsh
setopt LONG_LIST_JOBS
sleep 300 &
jobs               # [1]  + 54321 running    sleep 300  (long format with PID)
```
- **When it's useful:** When you need to see the PID of each job at a glance without passing `-l` to `jobs`.

### MONITOR (`-m`, ksh: `-m`)

- **What it does:** Allows job control. Set by default in interactive shells.
- **Example:**
```zsh
setopt MONITOR
sleep 300 &
kill -STOP %1      # job control commands like %1, fg, bg, and STOP work
```
- **When it's useful:** When you need interactive job control (fg/bg/suspend) inside a script or non-interactive shell where it is off by default.

### NOTIFY (`-5`, ksh: `-b`) `<Z>`

- **What it does:** Reports the status of background jobs immediately, rather than waiting until just before the next prompt is printed.
- **Example:**
```zsh
setopt NOTIFY
sleep 2 &
# "[1] + done sleep 2" is printed the moment it finishes, mid-work
```
- **When it's useful:** When you want to know as soon as a background job completes instead of only when you next hit Enter.

### POSIX_JOBS `<K>` `<S>`

- **What it does:** Makes job control more POSIX-compliant: `MONITOR` and job control stay active inside subshells (though the subshell cannot access the parent's jobs), and `bg`/`fg` print only the job text rather than full `jobs`-style information.
- **Example:**
```zsh
setopt POSIX_JOBS
( sleep 300 &      # job control stays active in this subshell
  fg )             # prints just the command text, not full jobs info
```
- **When it's useful:** When you need zsh's job-control behavior to match the POSIX standard, for example when running portable scripts that expect job control inside subshells.

---

## Prompting

### PROMPT_BANG `<K>`

- **What it does:** When set, `!` is treated specially in prompt expansion (see EXPANSION OF PROMPT SEQUENCES in zshmisc(1)).
- **Example:**
```zsh
setopt PROMPT_BANG
PROMPT='%h[!] $ '   # the `!' expands to the current history event number
# e.g. prompt shows: 42[42] $
```
- **When it's useful:** When you want the current history event number embedded in your prompt via `!`.

### PROMPT_CR (`+V`) `<D>`

- **What it does:** Prints a carriage return just before printing a prompt in the line editor. On by default, since multi-line editing needs the editor to know where the line starts.
- **Example:**
```zsh
setopt PROMPT_CR
# after a program leaves the cursor mid-line, the prompt starts cleanly at column 0
printf 'no newline here'; PROMPT='%~ $ '   # prompt is drawn from the start of the line
```
- **When it's useful:** When previous output leaves the cursor mid-line and you want the prompt to begin at the left margin.

### PROMPT_SP `<D>`

- **What it does:** Attempts to preserve a partial line (one not ending in a newline) that PROMPT_CR would otherwise overwrite, by emitting cursor-control characters and spaces so the terminal wraps to the next line. On by default; has no effect unless PROMPT_CR is also set.
- **Example:**
```zsh
setopt PROMPT_SP
printf 'partial output'          # no trailing newline
# the partial line is preserved and shown with an inverse+bold `%' (or `#' for root) at its end
export PROMPT_EOL_MARK='%B%S<EOL>%s%b'   # customize the end-of-line marker
```
- **When it's useful:** When a command prints output without a trailing newline and you don't want that text swallowed by the next prompt.

### PROMPT_PERCENT `<C>` `<Z>`

- **What it does:** When set, `%` is treated specially in prompt expansion (see EXPANSION OF PROMPT SEQUENCES in zshmisc(1)).
- **Example:**
```zsh
setopt PROMPT_PERCENT
PROMPT='%n@%m %~ $ '   # %n=user, %m=host, %~=cwd all get expanded
# e.g. prompt shows: josh@laptop ~/notes $
```
- **When it's useful:** When you want to use `%` escape sequences (user, host, directory, etc.) in your prompt.

### PROMPT_SUBST `<K>` `<S>`

- **What it does:** When set, parameter expansion, command substitution, and arithmetic expansion are performed in prompts. These substitutions do not affect the command status.
- **Example:**
```zsh
setopt PROMPT_SUBST
PROMPT='$(git rev-parse --abbrev-ref HEAD) $ '   # runs git each time the prompt is drawn
# e.g. prompt shows: main $
```
- **When it's useful:** When you want dynamic prompt content like the current git branch computed via command substitution on every prompt.

### TRANSIENT_RPROMPT

- **What it does:** Removes any right prompt from the display when a command line is accepted.
- **Example:**
```zsh
setopt TRANSIENT_RPROMPT
RPROMPT='%*'          # right prompt shows the time while editing
# after pressing Enter, the right prompt vanishes from that line, leaving clean output to copy
```
- **When it's useful:** When you use an RPROMPT but want it gone from accepted lines so cut/paste of terminal history stays clean.

---

## Scripts and Functions

### ALIAS_FUNC_DEF `<S>`

- **What it does:** When set, allows functions to be defined with the `name ()` syntax even if `name` was expanded as an alias; by default zsh treats this as an error to avoid alias/function conflicts.
- **Example:**
```zsh
setopt ALIAS_FUNC_DEF
alias foo=bar
foo() { print hi; }   # defines a function named 'bar', not 'foo'
```
- **When it's useful:** When porting startup files that intentionally define functions whose names collide with existing aliases.

### C_BASES

- **What it does:** Outputs hexadecimal numbers in standard C format (e.g. `0xFF`) instead of zsh's `16#FF`; with `OCTAL_ZEROES` also set, octal is shown as `077` instead of `8#77`. It affects only display of hex/octal, not the chosen output base.
- **Example:**
```zsh
setopt C_BASES
print $(( [#16] 255 ))   # prints 0xFF instead of 16#FF
```
- **When it's useful:** When generating hex output that must be pasted into C source or other C-like languages.

### C_PRECEDENCES

- **What it does:** Alters the precedence of arithmetic operators to more closely match C and other programming languages.
- **Example:**
```zsh
setopt C_PRECEDENCES
print $(( 1 << 2 + 1 ))   # uses C-like operator precedence
```
- **When it's useful:** When translating arithmetic expressions from C so they evaluate with the same precedence rules.

### DEBUG_BEFORE_CMD `<D>`

- **What it does:** Runs the DEBUG trap before each command instead of after it; enabled mimics ksh 93 behaviour, disabled mimics ksh 88.
- **Example:**
```zsh
setopt DEBUG_BEFORE_CMD
trap 'print "about to run: $ZSH_DEBUG_CMD"' DEBUG
true   # DEBUG trap fires before the command executes
```
- **When it's useful:** When you want to inspect or log a command before it runs, e.g. in a step-through debugger.

### ERR_EXIT (`-e`, ksh: `-e`)

- **What it does:** If a command returns a non-zero exit status, runs the ZERR trap (if set) and exits the shell; disabled during initialization scripts and inside DEBUG traps. Non-zero status of commands not at the end of an `&&`/`||` list is ignored.
- **Example:**
```zsh
setopt ERR_EXIT
false           # non-zero status -> shell exits here
print unreached  # never runs
false && true   # ignored: not the end of the list, no exit
```
- **When it's useful:** When you want a script to abort immediately on the first failing command rather than continuing.

### ERR_RETURN

- **What it does:** If a command returns a non-zero exit status, immediately returns from the enclosing function (an implicit `return` rather than `exit`); at the outermost level of a non-interactive script it triggers an exit. Like ERR_EXIT, code followed by `&&`/`||` does not trigger a return.
- **Example:**
```zsh
setopt ERR_RETURN
fn() { false; print unreached; }  # false -> fn returns immediately
fn
summit || true   # no return forced: combined status is zero
```
- **When it's useful:** When you want a function to bail out on the first error without aborting the whole shell.

### EVAL_LINENO `<Z>`

- **What it does:** When set, tracks line numbers of expressions run via the `eval` builtin separately from the enclosing environment, affecting `$LINENO` and prompt escape `%i`, and makes `%N` output `(eval)`. When unset, the surrounding script/function line number is kept during evaluation.
- **Example:**
```zsh
setopt EVAL_LINENO
PS4='+%N:%i> '
setopt xtrace
eval 'print hi'   # trace shows (eval) and eval-local line numbers
```
- **When it's useful:** When debugging code inside `eval` and you want line numbers and source names to reflect the evaluated text.

### EXEC (`+n`, ksh: `+n`) `<D>`

- **What it does:** Actually executes commands; when unset, commands are read and syntax-checked but not executed. It cannot be turned off in an interactive shell except via `-n` at startup.
- **Example:**
```zsh
unsetopt EXEC   # equivalent to zsh -n: syntax-check only
rm -rf /        # parsed and checked, but not run
setopt EXEC
```
- **When it's useful:** When you want to syntax-check a script without running any of its commands.

### FUNCTION_ARGZERO `<C>` `<Z>`

- **What it does:** When executing a function or sourcing a script, temporarily sets `$0` to the name of the function/script. Only the option's state on entry matters; toggling it mid-function does not change the current `$0`.
- **Example:**
```zsh
setopt FUNCTION_ARGZERO
fn() { print $0; }
fn   # prints 'fn' instead of the shell name
```
- **When it's useful:** When a function or sourced script needs to report its own name, e.g. in usage or error messages.

### LOCAL_LOOPS

- **What it does:** When unset, `break` and `continue` can propagate out of function scope and affect loops in calling functions. When set in a calling function, an uncaught `break`/`continue` from a called function produces a warning and is cancelled.
- **Example:**
```zsh
setopt LOCAL_LOOPS
for i in 1 2 3; do
  inner() { break; }   # break can't escape inner; warns, cancelled
  inner
done
```
- **When it's useful:** When you want to prevent a called function from accidentally breaking out of a caller's loop.

### LOCAL_OPTIONS `<K>`

- **What it does:** If set at the point a function returns, most options in force on entry are restored (except PRIVILEGED and RESTRICTED); otherwise only LOCAL_OPTIONS, LOCAL_LOOPS, XTRACE and PRINT_EXIT_VALUE are restored. `emulate -L zsh` activates it.
- **Example:**
```zsh
fn() {
  setopt LOCAL_OPTIONS
  setopt extended_glob   # restored to prior state on return
}
fn   # extended_glob setting unchanged after fn returns
```
- **When it's useful:** When a function needs to change options locally without permanently altering the caller's shell configuration.

### LOCAL_PATTERNS

- **What it does:** If set at the point a function returns, restores the state of pattern disables (as set by `disable -p`) to what it was when the function was entered. Like LOCAL_OPTIONS, `emulate -L ...` activates it.
- **Example:**
```zsh
fn() {
  setopt LOCAL_PATTERNS
  disable -p '*'   # pattern-disable restored on return
}
fn
```
- **When it's useful:** When a function disables globbing patterns temporarily and must not leak that change to the caller.

### LOCAL_TRAPS `<K>`

- **What it does:** If set when a signal trap is set inside a function, the previous trap for that signal is restored when the function exits. It must be set before altering the trap; unlike LOCAL_OPTIONS, its value on exit is irrelevant.
- **Example:**
```zsh
trap - INT
fn() { setopt localtraps; trap '' INT; sleep 3; }
fn   # normal SIGINT handling restored after fn exits
```
- **When it's useful:** When a function needs to temporarily change signal handling and restore the original trap on exit.

### MULTI_FUNC_DEF `<Z>`

- **What it does:** Allows defining multiple functions at once with `fn1 fn2...()`; when unset this causes a parse error. Definition of multiple functions via the `function` keyword is always allowed.
- **Example:**
```zsh
setopt MULTI_FUNC_DEF
fn1 fn2 () { print hi; }   # defines both fn1 and fn2
```
- **When it's useful:** When you deliberately want several functions to share one body defined in a single statement.

### MULTIOS `<Z>`

- **What it does:** Performs implicit tees or cats when multiple redirections are attempted.
- **Example:**
```zsh
setopt MULTIOS
echo hi > a.txt > b.txt   # implicit tee: writes to both files
cat < a.txt < b.txt       # implicit cat: reads both
```
- **When it's useful:** When you want to send one command's output to several files, or feed several files into one command, without an explicit `tee`/`cat`.

### OCTAL_ZEROES `<S>`

- **What it does:** Interprets any integer constant beginning with `0` as octal (per IEEE Std 1003.2-1992); disabled by default because it breaks parsing of things like date/time strings with leading zeroes. Base-indicator digit sequences like the `08` in `08#77` are always decimal.
- **Example:**
```zsh
setopt OCTAL_ZEROES
print $(( 010 ))   # prints 8, interpreting 010 as octal
```
- **When it's useful:** When working with C-style code that expects a leading zero to denote an octal literal.

### PIPE_FAIL

- **What it does:** By default `$?` reflects the exit status of the rightmost element of a pipeline; when set, it instead reflects the status of the rightmost element that was non-zero, or zero if all elements succeeded.
- **Example:**
```zsh
setopt PIPE_FAIL
false | true
print $?   # prints non-zero (from 'false') instead of 0
```
- **When it's useful:** When you need a pipeline to be considered failed if any command in it fails, not just the last one.

### SOURCE_TRACE

- **What it does:** When set, zsh prints an informational message announcing the name of each file it loads, formatted like XTRACE output with a `<sourcetrace>` message. Files may be loaded at startup/shutdown or via `source`/`.`.
- **Example:**
```zsh
setopt SOURCE_TRACE
source ~/.myrc   # prints a <sourcetrace> message naming the file
```
- **When it's useful:** When debugging startup performance or figuring out which files your shell actually loads.

### TYPESET_SILENT

- **What it does:** When unset, running a `typeset`-family command with no options and existing parameters that have no assigned value displays those parameters' values; when set, they are shown only with the `-m` option. The `-p` option works regardless of this setting.
- **Example:**
```zsh
setopt TYPESET_SILENT
foo=1
typeset foo   # prints nothing; without the option it would show foo's value
```
- **When it's useful:** When you want `typeset` declarations in scripts to stay quiet rather than echoing existing parameter values.

### TYPESET_TO_UNSET `<K>` `<S>`

- **What it does:** When declaring a new parameter with a `typeset`-family command, the parameter stays unset until a value is explicitly assigned, either in the `typeset` command itself or later.
- **Example:**
```zsh
setopt TYPESET_TO_UNSET
typeset foo
print ${+foo}   # prints 0: foo exists as declared but is unset
```
- **When it's useful:** When you need to distinguish a declared-but-never-assigned parameter from one holding an empty value.

### VERBOSE (`-v`, ksh: `-v`)

- **What it does:** Prints shell input lines as they are read.
- **Example:**
```zsh
setopt VERBOSE
print hello   # the input line 'print hello' is echoed as it is read
```
- **When it's useful:** When you want to see exactly what the shell is reading, e.g. while debugging a script's raw input.

### XTRACE (`-x`, ksh: `-x`)

- **What it does:** Prints commands and their arguments as they are executed, each preceded by the value of `$PS4`.
- **Example:**
```zsh
setopt XTRACE
x=1
print $x   # trace line like '+script:2> print 1' shown before output
```
- **When it's useful:** When debugging a script and you want to trace exactly which commands run and with what expanded arguments.

---

## Shell Emulation

### APPEND_CREATE `<K>` `<S>`

- **What it does:** Only applies when NO_CLOBBER (-C) is in effect. When unset, the shell errors if an append redirection (`>>`) targets a file that does not already exist; when set, no error is reported (POSIX behaviour).
- **Example:**
```zsh
setopt NO_CLOBBER APPEND_CREATE
echo hi >> newfile.txt   # succeeds and creates newfile.txt (no error)
unsetopt APPEND_CREATE
echo hi >> another.txt    # errors: file does not exist under NO_CLOBBER
```
- **When it's useful:** When writing POSIX-portable scripts that append to log files which may not yet exist while keeping NO_CLOBBER on.

### BASH_REMATCH

- **What it does:** When set, `=~` matches populate the `BASH_REMATCH` array instead of the default `MATCH`/`match` variables, with element 0 holding the whole match and later elements the substrings. It makes most sense combined with KSH_ARRAYS.
- **Example:**
```zsh
setopt BASH_REMATCH KSH_ARRAYS
[[ "abc123" =~ ([a-z]+)([0-9]+) ]]
echo $BASH_REMATCH   # abc123 (entire match at index 0)
echo ${BASH_REMATCH[1]}  # abc (first substring)
```
- **When it's useful:** When porting bash regex-matching scripts that rely on the `BASH_REMATCH` array.

### BSD_ECHO `<S>`

- **What it does:** Makes the `echo` builtin compatible with BSD `echo(1)`, disabling backslash escape sequences unless the `-e` option is given.
- **Example:**
```zsh
setopt BSD_ECHO
echo "a\tb"      # prints literally: a\tb
echo -e "a\tb"   # prints: a<TAB>b
```
- **When it's useful:** When you need `echo` to behave like the BSD command and not interpret escapes by default.

### CONTINUE_ON_ERROR

- **What it does:** When a fatal error occurs in a running script, the shell resumes execution at the next top-level statement (outside all functions and constructs) rather than aborting, mimicking interactive shell behaviour (the pre-5.0.1 default).
- **Example:**
```zsh
setopt CONTINUE_ON_ERROR
# a fatal error mid-script no longer aborts the whole script;
# execution continues at the next top-level statement
```
- **When it's useful:** When running a batch script where a single fatal error should not halt the remaining top-level commands.

### CSH_JUNKIE_HISTORY `<C>`

- **What it does:** A history reference without an event specifier always refers to the previous command, rather than to the same event as the previous history reference on the current command line.
- **Example:**
```zsh
setopt CSH_JUNKIE_HISTORY
!:1    # refers to the first word of the previous command (not an earlier reference)
```
- **When it's useful:** When you want csh-style history where bare references always point at the last command.

### CSH_JUNKIE_LOOPS `<C>`

- **What it does:** Allows loop bodies to take the form `list; end` instead of the standard `do list; done`.
- **Example:**
```zsh
setopt CSH_JUNKIE_LOOPS
for i in 1 2 3; echo $i; end   # works like: for i ...; do echo $i; done
```
- **When it's useful:** When running csh-style loop syntax without rewriting it to `do`/`done`.

### CSH_JUNKIE_QUOTES `<C>`

- **What it does:** Changes single- and double-quote rules to match csh: embedded newlines must be backslash-escaped (unescaped ones error), and inside double quotes `$`, backtick, and `"` cannot be escaped (and `\` no longer needs escaping); command substitutions expand only once and cannot nest.
- **Example:**
```zsh
setopt CSH_JUNKIE_QUOTES
echo "line1\
line2"          # newline must be preceded by a backslash, else error
```
- **When it's useful:** When emulating csh quoting semantics for legacy scripts.

### CSH_NULLCMD `<C>`

- **What it does:** Do not use the values of `NULLCMD` and `READNULLCMD` when running redirections with no command, which makes such redirections fail.
- **Example:**
```zsh
setopt CSH_NULLCMD
> file.txt   # fails: no command given (NULLCMD not consulted)
```
- **When it's useful:** When you want commandless redirections to be treated as errors, csh-style.

### KSH_ARRAYS `<K>` `<S>`

- **What it does:** Emulates ksh array handling: elements are numbered from zero, an unsubscripted array parameter refers to the first element instead of the whole array, and braces are required to delimit a subscript or apply modifiers.
- **Example:**
```zsh
setopt KSH_ARRAYS
arr=(a b c)
echo ${arr[0]}   # a (zero-based indexing)
echo $arr        # a (unsubscripted = first element)
```
- **When it's useful:** When porting ksh scripts that assume zero-based arrays and brace-delimited subscripts.

### KSH_AUTOLOAD `<K>` `<S>`

- **What it does:** Emulates ksh function autoloading: an autoloaded file is merely executed and must itself define the function (by default zsh instead defines the function to the file's contents). The common case of a file containing only a simple definition is always handled ksh-compatibly.
- **Example:**
```zsh
setopt KSH_AUTOLOAD
autoload myfunc
# myfunc file is executed and is expected to define myfunc itself
```
- **When it's useful:** When using ksh-style autoload files that contain setup code plus a function definition.

### KSH_OPTION_PRINT `<K>`

- **What it does:** Alters how option settings are printed: instead of separate set/unset lists, all options are shown, marked `on` if in the non-default state and `off` otherwise.
- **Example:**
```zsh
setopt KSH_OPTION_PRINT
setopt   # lists every option with on/off instead of two separate lists
```
- **When it's useful:** When you want a complete ksh-style listing of every option's state at once.

### KSH_TYPESET

- **What it does:** Now obsolete (the reserved-word interface to `typeset` and friends is preferred); applied only when the reserved-word interface is not in use. Without it, zsh does normal word splitting after command and parameter expansion in assignment arguments to the `typeset` family; with it, word splitting does not take place in those cases.
- **Example:**
```zsh
setopt KSH_TYPESET
args="a b c"
typeset var=$args   # word splitting is suppressed for the assignment argument
```
- **When it's useful:** When legacy scripts rely on `typeset` assignments not being word-split (in the absence of the reserved-word interface).

### KSH_ZERO_SUBSCRIPT

- **What it does:** Treats a subscript of value zero in array or string expressions as a reference to the first element (the one usually at subscript 1); ignored if KSH_ARRAYS is also set. Without it (and without KSH_ARRAYS), reads of subscript zero return an empty element and writes to element zero are an error.
- **Example:**
```zsh
setopt KSH_ZERO_SUBSCRIPT
array=(x y z)
echo ${array[0]}      # x (zero refers to first element)
array[0]=(new)        # without this option this would be an error
```
- **When it's useful:** When maintaining older scripts that use subscript zero to mean the first element; not recommended for new code.

### POSIX_ALIASES `<K>` `<S>`

- **What it does:** When set, reserved words are not candidates for alias expansion: you may still declare one as an alias, but it will never be expanded. Since alias expansion happens while text is read, it takes effect only at the end of the function or code unit being parsed.
- **Example:**
```zsh
setopt POSIX_ALIASES
alias if='echo nope'
if true; then echo hi; fi   # 'if' is a reserved word, alias not expanded
```
- **When it's useful:** When you need POSIX-compatible parsing where reserved words are never shadowed by aliases.

### POSIX_ARGZERO

- **What it does:** Temporarily disables FUNCTION_ARGZERO, restoring `$0` to the name used to invoke the shell (or as set by `-c`). Emulations use NO_FUNCTION_ARGZERO instead, so enabling POSIX_ARGZERO explicitly avoids unexpected `$0` scoping when emulation mode changes inside a function.
- **Example:**
```zsh
emulate sh -o POSIX_ARGZERO
echo $0   # the name used to invoke the shell, not the current function name
```
- **When it's useful:** When you need `$0` to reliably report the shell invocation name inside emulated `sh` code.

### POSIX_BUILTINS `<K>` `<S>`

- **What it does:** When set, the `command` builtin can execute shell builtins; assignments before functions and special builtins persist after completion unless the special builtin is prefixed with `command`. Various error conditions cause a non-interactive shell to exit (interactive to return to top level), functions/builtins are not run after an `exec` prefix, `getopts`/`OPTIND` behave POSIX-compatibly, and the warning/exit code from `[[ -o non_existent_option ]]` is suppressed.
- **Example:**
```zsh
setopt POSIX_BUILTINS
command return 0   # command builtin can execute shell builtins
VAR=1 : ; echo $VAR   # assignment before special builtin ':' persists
```
- **When it's useful:** When you need POSIX-compliant builtin, assignment-persistence, and `getopts` semantics.

### POSIX_IDENTIFIERS `<K>` `<S>`

- **What it does:** When set, only ASCII `a-z`, `A-Z`, `0-9` and `_` may appear in identifiers; it also limits braceless parameter substitution so `$#` is the parameter `$#` (not `$#name` length), and assignment to an unset variable in arithmetic context creates a scalar rather than a numeric type. When unset with multibyte support, additional local-charset alphanumerics are allowed.
- **Example:**
```zsh
setopt POSIX_IDENTIFIERS
unset t; (( t = 3 ))
echo ${(t)t}   # scalar (rather than integer type)
```
- **When it's useful:** When enforcing portable, ASCII-only parameter names in scripts meant to run under other shells.

### POSIX_STRINGS `<K>` `<S>`

- **What it does:** Affects quoted-string processing, currently only null characters. When unset, null characters embedded in `$'...'` strings are treated as ordinary characters; when set, the `$'...'` expression is truncated at the null character (parts of the same string beyond the quotes are not truncated).
- **Example:**
```zsh
setopt POSIX_STRINGS
printf '%s\n' a$'b\0c'd   # prints: abd (truncated at the null)
# with the option off it would be: a, b, null, c, d
```
- **When it's useful:** When you want null bytes in `$'...'` to terminate the string as they do in POSIX shells.

### POSIX_TRAPS `<K>` `<S>`

- **What it does:** When set, the usual zsh execution of EXIT traps on return from shell functions is suppressed; EXIT trap manipulation always alters the global exit trap (LOCAL_TRAPS is ignored for EXIT), a bare `return` in a trap passes back the surrounding context's value, and an ignored trap stays ignored in a subshell.
- **Example:**
```zsh
setopt POSIX_TRAPS
f() { trap 'echo bye' EXIT; }
f    # EXIT trap is NOT run on function return; it sets the global exit trap
```
- **When it's useful:** When you need POSIX EXIT-trap semantics where traps fire on shell exit, not function return.

### SH_FILE_EXPANSION `<K>` `<S>`

- **What it does:** Performs filename expansion (e.g. `~` expansion) before parameter expansion, command substitution, arithmetic expansion and brace expansion. When unset it happens after brace expansion, so `~$USERNAME` and `~{pfalstad,rc}` work.
- **Example:**
```zsh
setopt SH_FILE_EXPANSION
echo ~$USERNAME   # ~ expanded before $USERNAME, so this may not resolve the user's home
```
- **When it's useful:** When emulating sh-style ordering where tilde expansion precedes parameter expansion.

### SH_NULLCMD `<K>` `<S>`

- **What it does:** Do not use the values of `NULLCMD` and `READNULLCMD` when doing redirections; use `:` instead.
- **Example:**
```zsh
setopt SH_NULLCMD
> file.txt   # behaves as ': > file.txt' (truncates/creates the file)
```
- **When it's useful:** When you want commandless redirections to default to `:` like POSIX sh, rather than zsh's NULLCMD.

### SH_OPTION_LETTERS `<K>` `<S>`

- **What it does:** When set, the shell tries to interpret single-letter options (used with `set` and `setopt`) as ksh does; this also affects the value of the `-` special parameter.
- **Example:**
```zsh
setopt SH_OPTION_LETTERS
set -o   # single-letter option flags are interpreted ksh-style
```
- **When it's useful:** When porting ksh scripts that pass single-letter option flags to `set`/`setopt`.

### SH_WORD_SPLIT (`-y`) `<K>` `<S>`

- **What it does:** Causes field splitting to be performed on unquoted parameter expansions. (Note: this is unrelated to zsh "word splitting".)
- **Example:**
```zsh
setopt SH_WORD_SPLIT
var="a b c"
for x in $var; do echo $x; done   # iterates a, b, c (split into fields)
```
- **When it's useful:** When porting sh/bash scripts that rely on unquoted `$var` splitting into separate words.

### TRAPS_ASYNC

- **What it does:** While waiting for a program to exit, handle signals and run traps immediately rather than after the child process has exited. This affects only the case where the shell is waiting for a child process.
- **Example:**
```zsh
setopt TRAPS_ASYNC
trap 'echo caught' USR1
sleep 100   # a USR1 arriving now runs the trap immediately, not after sleep exits
```
- **When it's useful:** When you need signal traps to fire promptly while a long-running foreground command is still executing.

---

## Shell State

### INTERACTIVE (`-i`)

- **What it does:** Marks the shell as interactive. It is set at startup when standard input is a tty and commands come from standard input, but can only be changed via invocation flags — not once zsh is running.
- **Example:**
```zsh
zsh -i    # start an interactive shell
setopt interactive    # no effect once running; state is fixed at invocation
```
- **When it's useful:** Forcing interactive behavior (prompts, job control) at startup even when input isn't a tty.

### LOGIN (`-l`)

- **What it does:** Marks the shell as a login shell. If not explicitly set, the shell becomes a login shell when the first character of its argv[0] is a `-`.
- **Example:**
```zsh
zsh -l    # run login startup files (.zprofile, .zlogin)
```
- **When it's useful:** Ensuring login startup files run, e.g. simulating a fresh login session for testing environment setup.

### PRIVILEGED (`-p`)

- **What it does:** Turns on privileged mode, disabling sourcing of user startup files; it is enabled automatically when the effective UID/GID differs from the real UID/GID, and turning it off resets effective IDs to the real ones. It cannot be changed with `setopt -m` and always changes globally inside functions.
- **Example:**
```zsh
#!/bin/zsh -p
unsetopt privileged || exit    # drop privileges; bail out if that fails
```
- **When it's useful:** Running a setuid/setgid script safely so untrusted user startup files (like `ENV` or `~/.profile`) are ignored.

### RESTRICTED (`-r`)

- **What it does:** Enables restricted mode. It cannot be turned off with `unsetopt`, and setting it inside a function always changes it globally regardless of LOCAL_OPTIONS.
- **Example:**
```zsh
zsh -r    # start a restricted shell (cd, redirection, PATH changes, etc. limited)
```
- **When it's useful:** Locking down a shell for a constrained or untrusted user who should not roam the filesystem.

### SHIN_STDIN (`-s`)

- **What it does:** Indicates commands are being read from standard input, which happens when no `-c` command and no command file are given. Setting it explicitly on the command line makes any would-be script-file argument a normal positional parameter instead. It can only be changed via invocation flags.
- **Example:**
```zsh
echo 'print hello' | zsh -s foo    # reads cmds from stdin; foo becomes $1
```
- **When it's useful:** Piping commands into zsh while still passing positional parameters, instead of having the first argument treated as a script file.

### SINGLE_COMMAND (`-t`)

- **What it does:** When reading from standard input, the shell exits after executing a single command. This also makes the shell non-interactive unless INTERACTIVE is explicitly set on the command line, and can only be changed via invocation flags.
- **Example:**
```zsh
echo 'print done' | zsh -t    # runs one command, then exits
```
- **When it's useful:** Running exactly one command from a stream and guaranteeing the shell exits immediately afterward.

---

## Zle

### BEEP (`-B`) `<D>`

- **What it does:** Beeps when an error occurs in the Zsh Line Editor (ZLE).
- **Example:**
```zsh
setopt BEEP
# pressing an invalid key sequence in ZLE now produces an audible beep
unsetopt BEEP  # silence ZLE error beeps
```
- **When it's useful:** When you want an audible cue that a keystroke or edit command failed in the line editor.

### COMBINING_CHARS

- **What it does:** Assumes the terminal correctly renders zero-width combining characters as modifications to the preceding base character within the same width, rather than displaying them separately with special mark-up. When set, `[[:WORD:]]` also matches zero-width punctuation so it counts as part of a word.
- **Example:**
```zsh
setopt COMBINING_CHARS
# an accented char formed by base + combining mark shows at correct width
[[ $'́' = [[:WORD:]] ]] && echo yes  # zero-width mark treated as word char
```
- **When it's useful:** On a modern terminal that handles combining characters properly, so accented and composed text lines up correctly during editing.

### EMACS

- **What it does:** If ZLE is loaded, turning this on is equivalent to `bindkey -e` and also unsets the VI option; turning it off has no effect. Provided for compatibility, with `bindkey` being the recommended interface.
- **Example:**
```zsh
setopt EMACS
# equivalent to `bindkey -e`; enables emacs-style line editing, unsets VI
```
- **When it's useful:** When a script or profile needs a quick compatibility switch to emacs-style key bindings.

### OVERSTRIKE

- **What it does:** Starts the line editor in overstrike (overwrite) mode instead of insert mode.
- **Example:**
```zsh
setopt OVERSTRIKE
# typing now overwrites characters under the cursor instead of inserting
```
- **When it's useful:** When you prefer typed characters to replace existing text on the line rather than push it aside.

### SINGLE_LINE_ZLE (`-M`) `<K>`

- **What it does:** Uses single-line command-line editing instead of multi-line editing. On by default in ksh emulation, but it only gives superficial ksh compatibility and reduces the effectiveness of the zsh line editor.
- **Example:**
```zsh
setopt SINGLE_LINE_ZLE
# long commands are edited on one scrolling line rather than wrapping to multiple lines
unsetopt SINGLE_LINE_ZLE  # restore full multi-line zsh editing
```
- **When it's useful:** When emulating ksh but you actually want to disable it interactively to regain the full zsh editor experience.

### VI

- **What it does:** If ZLE is loaded, turning this on is equivalent to `bindkey -v` and also unsets the EMACS option; turning it off has no effect. Provided for compatibility, with `bindkey` being the recommended interface.
- **Example:**
```zsh
setopt VI
# equivalent to `bindkey -v`; enables vi-style line editing, unsets EMACS
```
- **When it's useful:** When you want a quick compatibility switch to vi-style modal key bindings.

### ZLE (`-Z`)

- **What it does:** Enables use of the zsh line editor. Set by default in interactive shells connected to a terminal.
- **Example:**
```zsh
setopt ZLE
# the zsh line editor is active, enabling interactive editing and key bindings
```
- **When it's useful:** When you need to ensure interactive line editing is available in a shell that might otherwise run without it.

---

# Appendix

## A. Specifying Options

Options are primarily referred to by name. **Names are case-insensitive and underscores are ignored** — `allexport`, `ALL_EXPORT`, and `A__lleXP_ort` are all equivalent.

The sense of an option name may be inverted by prefixing `no`, so `setopt NO_BEEP` is equivalent to `unsetopt BEEP`. This inversion can only be done once: `nonobeep` is *not* a synonym for `beep`, and `tify` is *not* a synonym for `nonotify`.

Some options also have one or more **single-letter names**. There are two sets: the default set, and a set used to emulate sh/ksh (active when `SH_OPTION_LETTERS` is set). Single-letter options can be used on the command line or with `set`, `setopt`, and `unsetopt`, as normal Unix options preceded by `-`.

The sense of a single-letter option may be inverted with `+` instead of `-`. Some single-letter names refer to an option being *off*, in which case the inverted name turns it *on*. For example `+n` is the short name of `exec`, and `-n` is the short name of its inversion `noexec`.

In strings of single-letter options given at startup, trailing whitespace is ignored (so `-f    ` is treated as `-f`), but `-f i` is an error — this accommodates `#!` script-launch mechanisms that don't strip trailing whitespace.

Options can be set within a function scope; see `LOCAL_OPTIONS` above.

## B. Option Aliases

Some options have alternative names. These aliases are never used for output but can be used just like normal option names when specifying options.

| Alias | Canonical option | Compatibility |
| --- | --- | --- |
| `BRACE_EXPAND` | `NO_IGNORE_BRACES` | ksh and bash |
| `DOT_GLOB` | `GLOB_DOTS` | bash |
| `HASH_ALL` | `HASH_CMDS` | bash |
| `HIST_APPEND` | `APPEND_HISTORY` | bash |
| `HIST_EXPAND` | `BANG_HIST` | bash |
| `LOG` | `NO_HIST_NO_FUNCTIONS` | ksh |
| `MAIL_WARN` | `MAIL_WARNING` | bash |
| `ONE_CMD` | `SINGLE_COMMAND` | bash |
| `PHYSICAL` | `CHASE_LINKS` | ksh and bash |
| `PROMPT_VARS` | `PROMPT_SUBST` | bash |
| `STDIN` | `SHIN_STDIN` | ksh |
| `TRACK_ALL` | `HASH_CMDS` | ksh |

## C. Single Letter Options

### Default set

| Flag | Option | Flag | Option | Flag | Option |
| --- | --- | --- | --- | --- | --- |
| `-0` | `CORRECT` | `-I` | `IGNORE_BRACES` | `-a` | `ALL_EXPORT` |
| `-1` | `PRINT_EXIT_VALUE` | `-J` | `AUTO_CD` | `-e` | `ERR_EXIT` |
| `-2` | `NO_BAD_PATTERN` | `-K` | `NO_BANG_HIST` | `-f` | `NO_RCS` |
| `-3` | `NO_NOMATCH` | `-L` | `SUN_KEYBOARD_HACK` | `-g` | `HIST_IGNORE_SPACE` |
| `-4` | `GLOB_DOTS` | `-M` | `SINGLE_LINE_ZLE` | `-h` | `HIST_IGNORE_DUPS` |
| `-5` | `NOTIFY` | `-N` | `AUTO_PUSHD` | `-i` | `INTERACTIVE` |
| `-6` | `BG_NICE` | `-O` | `CORRECT_ALL` | `-k` | `INTERACTIVE_COMMENTS` |
| `-7` | `IGNORE_EOF` | `-P` | `RC_EXPAND_PARAM` | `-l` | `LOGIN` |
| `-8` | `MARK_DIRS` | `-Q` | `PATH_DIRS` | `-m` | `MONITOR` |
| `-9` | `AUTO_LIST` | `-R` | `LONG_LIST_JOBS` | `-n` | `NO_EXEC` |
| `-B` | `NO_BEEP` | `-S` | `REC_EXACT` | `-p` | `PRIVILEGED` |
| `-C` | `NO_CLOBBER` | `-T` | `CDABLE_VARS` | `-r` | `RESTRICTED` |
| `-D` | `PUSHD_TO_HOME` | `-U` | `MAIL_WARNING` | `-s` | `SHIN_STDIN` |
| `-E` | `PUSHD_SILENT` | `-V` | `NO_PROMPT_CR` | `-t` | `SINGLE_COMMAND` |
| `-F` | `NO_GLOB` | `-W` | `AUTO_RESUME` | `-u` | `NO_UNSET` |
| `-G` | `NULL_GLOB` | `-X` | `LIST_TYPES` | `-v` | `VERBOSE` |
| `-H` | `RM_STAR_SILENT` | `-Y` | `MENU_COMPLETE` | `-w` | `CHASE_LINKS` |
|  |  | `-Z` | `ZLE` | `-x` | `XTRACE` |
|  |  |  |  | `-y` | `SH_WORD_SPLIT` |

### sh/ksh emulation set

Active when `SH_OPTION_LETTERS` is set.

| Flag | Option | Flag | Option |
| --- | --- | --- | --- |
| `-C` | `NO_CLOBBER` | `-l` | `LOGIN` |
| `-T` | `TRAPS_ASYNC` | `-m` | `MONITOR` |
| `-X` | `MARK_DIRS` | `-n` | `NO_EXEC` |
| `-a` | `ALL_EXPORT` | `-p` | `PRIVILEGED` |
| `-b` | `NOTIFY` | `-r` | `RESTRICTED` |
| `-e` | `ERR_EXIT` | `-s` | `SHIN_STDIN` |
| `-f` | `NO_GLOB` | `-t` | `SINGLE_COMMAND` |
| `-i` | `INTERACTIVE` | `-u` | `NO_UNSET` |
|  |  | `-v` | `VERBOSE` |
|  |  | `-x` | `XTRACE` |

### Also note

These single-letter flags are used for purposes other than setting shell options:

| Flag | Meaning |
| --- | --- |
| `-A` | Used by `set` for setting arrays |
| `-b` | Used on the command line to specify end of option processing |
| `-c` | Used on the command line to specify a single command |
| `-m` | Used by `setopt` for pattern-matching option setting |
| `-o` | Used in all places to allow use of long option names |
| `-s` | Used by `set` to sort positional parameters |

## D. Related Manual Pages

- **zshoptions(1)** — the source for this document (zsh 5.9, dated May 14 2022).
- **zshbuiltins(1)** — details of the `cd`, `setopt`, `unsetopt`, `set`, `typeset`, `disable`, and other builtins referenced above.
- **zshmisc(1)** — "EXPANSION OF PROMPT SEQUENCES" (referenced by `PROMPT_BANG` and `PROMPT_PERCENT`), redirection, and job-control semantics.
- **zshexpn(1)** — filename expansion, filename generation (globbing), glob qualifiers, and history expansion referenced throughout Expansion and Globbing and History.
- **zshparam(1)** — parameters such as `CORRECT_IGNORE`, `CORRECT_IGNORE_FILE`, `KEYBOARD_HACK`, `PROMPT_EOL_MARK`, `HISTFILE`, `HISTSIZE`, and `SAVEHIST`.
- **zshzle(1)** — the Zsh Line Editor, `bindkey`, and widget behaviour referenced by the Zle and Completion groups.
- **zshcompsys(1)** / **zshcompwid(1)** — the completion system underlying the Completion group.
