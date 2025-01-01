# bash completion for jira                                 -*- shell-script -*-

__jira_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__jira_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__jira_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__jira_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__jira_handle_go_custom_completion()
{
    __jira_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly jira allows handling aliases
    args=("${words[@]:1}")
    # Disable ActiveHelp which is not supported for bash completion v1
    requestComp="JIRA_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __jira_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __jira_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __jira_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __jira_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __jira_debug "${FUNCNAME[0]}: the completions are: ${out}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __jira_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __jira_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __jira_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __jira_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out}")
        if [ -n "$subdir" ]; then
            __jira_debug "Listing directories in $subdir"
            __jira_handle_subdirs_in_dir_flag "$subdir"
        else
            __jira_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out}" -- "$cur")
    fi
}

__jira_handle_reply()
{
    __jira_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __jira_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi

            if [[ -z "${flag_parsing_disabled}" ]]; then
                # If flag parsing is enabled, we have completed the flags and can return.
                # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
                # to possibly call handle_go_custom_completion.
                return 0;
            fi
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __jira_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __jira_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        if declare -F __jira_custom_func >/dev/null; then
            # try command name qualified custom func
            __jira_custom_func
        else
            # otherwise fall back to unqualified for compatibility
            declare -F __custom_func >/dev/null && __custom_func
        fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__jira_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__jira_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__jira_handle_flag()
{
    __jira_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __jira_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __jira_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __jira_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __jira_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __jira_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__jira_handle_noun()
{
    __jira_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __jira_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __jira_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__jira_handle_command()
{
    __jira_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_jira_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __jira_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__jira_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __jira_handle_reply
        return
    fi
    __jira_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __jira_handle_flag
    elif __jira_contains_word "${words[c]}" "${commands[@]}"; then
        __jira_handle_command
    elif [[ $c -eq 0 ]]; then
        __jira_handle_command
    elif __jira_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __jira_handle_command
        else
            __jira_handle_noun
        fi
    else
        __jira_handle_noun
    fi
    __jira_handle_word
}

_jira_board_list()
{
    last_command="jira_board_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_board()
{
    last_command="jira_board"

    command_aliases=()

    commands=()
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("lists")
        aliashash["lists"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_completion()
{
    last_command="jira_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_jira_epic_add()
{
    last_command="jira_epic_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_epic_create()
{
    last_command="jira_epic_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--summary=")
    two_word_flags+=("--summary")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("--summary=")
    local_nonpersistent_flags+=("-s")
    flags+=("--body=")
    two_word_flags+=("--body")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--body")
    local_nonpersistent_flags+=("--body=")
    local_nonpersistent_flags+=("-b")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--reporter=")
    two_word_flags+=("--reporter")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reporter")
    local_nonpersistent_flags+=("--reporter=")
    local_nonpersistent_flags+=("-r")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--fix-version=")
    two_word_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version=")
    flags+=("--affects-version=")
    two_word_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version=")
    flags+=("--original-estimate=")
    two_word_flags+=("--original-estimate")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--original-estimate")
    local_nonpersistent_flags+=("--original-estimate=")
    local_nonpersistent_flags+=("-e")
    flags+=("--custom=")
    two_word_flags+=("--custom")
    local_nonpersistent_flags+=("--custom")
    local_nonpersistent_flags+=("--custom=")
    flags+=("--template=")
    two_word_flags+=("--template")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    local_nonpersistent_flags+=("-T")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--no-input")
    local_nonpersistent_flags+=("--no-input")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_epic_list()
{
    last_command="jira_epic_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--resolution=")
    two_word_flags+=("--resolution")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--resolution")
    local_nonpersistent_flags+=("--resolution=")
    local_nonpersistent_flags+=("-R")
    flags+=("--status=")
    two_word_flags+=("--status")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--status")
    local_nonpersistent_flags+=("--status=")
    local_nonpersistent_flags+=("-s")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--reporter=")
    two_word_flags+=("--reporter")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reporter")
    local_nonpersistent_flags+=("--reporter=")
    local_nonpersistent_flags+=("-r")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--history")
    local_nonpersistent_flags+=("--history")
    flags+=("--watching")
    flags+=("-w")
    local_nonpersistent_flags+=("--watching")
    local_nonpersistent_flags+=("-w")
    flags+=("--created=")
    two_word_flags+=("--created")
    local_nonpersistent_flags+=("--created")
    local_nonpersistent_flags+=("--created=")
    flags+=("--updated=")
    two_word_flags+=("--updated")
    local_nonpersistent_flags+=("--updated")
    local_nonpersistent_flags+=("--updated=")
    flags+=("--created-after=")
    two_word_flags+=("--created-after")
    local_nonpersistent_flags+=("--created-after")
    local_nonpersistent_flags+=("--created-after=")
    flags+=("--updated-after=")
    two_word_flags+=("--updated-after")
    local_nonpersistent_flags+=("--updated-after")
    local_nonpersistent_flags+=("--updated-after=")
    flags+=("--created-before=")
    two_word_flags+=("--created-before")
    local_nonpersistent_flags+=("--created-before")
    local_nonpersistent_flags+=("--created-before=")
    flags+=("--updated-before=")
    two_word_flags+=("--updated-before")
    local_nonpersistent_flags+=("--updated-before")
    local_nonpersistent_flags+=("--updated-before=")
    flags+=("--jql=")
    two_word_flags+=("--jql")
    two_word_flags+=("-q")
    local_nonpersistent_flags+=("--jql")
    local_nonpersistent_flags+=("--jql=")
    local_nonpersistent_flags+=("-q")
    flags+=("--order-by=")
    two_word_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by=")
    flags+=("--reverse")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--paginate=")
    two_word_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate=")
    flags+=("--plain")
    local_nonpersistent_flags+=("--plain")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--no-truncate")
    local_nonpersistent_flags+=("--no-truncate")
    flags+=("--columns=")
    two_word_flags+=("--columns")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    flags+=("--fixed-columns=")
    two_word_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns=")
    flags+=("--table")
    local_nonpersistent_flags+=("--table")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_epic_remove()
{
    last_command="jira_epic_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_epic()
{
    last_command="jira_epic"

    command_aliases=()

    commands=()
    commands+=("add")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("assign")
        aliashash["assign"]="add"
    fi
    commands+=("create")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("lists")
        aliashash["lists"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="remove"
        command_aliases+=("unassign")
        aliashash["unassign"]="remove"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_help()
{
    last_command="jira_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_jira_init()
{
    last_command="jira_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--installation=")
    two_word_flags+=("--installation")
    local_nonpersistent_flags+=("--installation")
    local_nonpersistent_flags+=("--installation=")
    flags+=("--server=")
    two_word_flags+=("--server")
    local_nonpersistent_flags+=("--server")
    local_nonpersistent_flags+=("--server=")
    flags+=("--login=")
    two_word_flags+=("--login")
    local_nonpersistent_flags+=("--login")
    local_nonpersistent_flags+=("--login=")
    flags+=("--auth-type=")
    two_word_flags+=("--auth-type")
    local_nonpersistent_flags+=("--auth-type")
    local_nonpersistent_flags+=("--auth-type=")
    flags+=("--project=")
    two_word_flags+=("--project")
    local_nonpersistent_flags+=("--project")
    local_nonpersistent_flags+=("--project=")
    flags+=("--board=")
    two_word_flags+=("--board")
    local_nonpersistent_flags+=("--board")
    local_nonpersistent_flags+=("--board=")
    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--insecure")
    local_nonpersistent_flags+=("--insecure")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_assign()
{
    last_command="jira_issue_assign"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_clone()
{
    last_command="jira_issue_clone"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--parent=")
    two_word_flags+=("--parent")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--parent")
    local_nonpersistent_flags+=("--parent=")
    local_nonpersistent_flags+=("-P")
    flags+=("--summary=")
    two_word_flags+=("--summary")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("--summary=")
    local_nonpersistent_flags+=("-s")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--replace=")
    two_word_flags+=("--replace")
    two_word_flags+=("-H")
    local_nonpersistent_flags+=("--replace")
    local_nonpersistent_flags+=("--replace=")
    local_nonpersistent_flags+=("-H")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_comment_add()
{
    last_command="jira_issue_comment_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-input")
    local_nonpersistent_flags+=("--no-input")
    flags+=("--template=")
    two_word_flags+=("--template")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    local_nonpersistent_flags+=("-T")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_comment()
{
    last_command="jira_issue_comment"

    command_aliases=()

    commands=()
    commands+=("add")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_create()
{
    last_command="jira_issue_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--type=")
    two_word_flags+=("--type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--parent=")
    two_word_flags+=("--parent")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--parent")
    local_nonpersistent_flags+=("--parent=")
    local_nonpersistent_flags+=("-P")
    flags+=("--summary=")
    two_word_flags+=("--summary")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("--summary=")
    local_nonpersistent_flags+=("-s")
    flags+=("--body=")
    two_word_flags+=("--body")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--body")
    local_nonpersistent_flags+=("--body=")
    local_nonpersistent_flags+=("-b")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--reporter=")
    two_word_flags+=("--reporter")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reporter")
    local_nonpersistent_flags+=("--reporter=")
    local_nonpersistent_flags+=("-r")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--fix-version=")
    two_word_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version=")
    flags+=("--affects-version=")
    two_word_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version=")
    flags+=("--original-estimate=")
    two_word_flags+=("--original-estimate")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--original-estimate")
    local_nonpersistent_flags+=("--original-estimate=")
    local_nonpersistent_flags+=("-e")
    flags+=("--custom=")
    two_word_flags+=("--custom")
    local_nonpersistent_flags+=("--custom")
    local_nonpersistent_flags+=("--custom=")
    flags+=("--template=")
    two_word_flags+=("--template")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    local_nonpersistent_flags+=("-T")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--no-input")
    local_nonpersistent_flags+=("--no-input")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_delete()
{
    last_command="jira_issue_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cascade")
    local_nonpersistent_flags+=("--cascade")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_edit()
{
    last_command="jira_issue_edit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--parent=")
    two_word_flags+=("--parent")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--parent")
    local_nonpersistent_flags+=("--parent=")
    local_nonpersistent_flags+=("-P")
    flags+=("--summary=")
    two_word_flags+=("--summary")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("--summary=")
    local_nonpersistent_flags+=("-s")
    flags+=("--body=")
    two_word_flags+=("--body")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--body")
    local_nonpersistent_flags+=("--body=")
    local_nonpersistent_flags+=("-b")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--fix-version=")
    two_word_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version")
    local_nonpersistent_flags+=("--fix-version=")
    flags+=("--affects-version=")
    two_word_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version")
    local_nonpersistent_flags+=("--affects-version=")
    flags+=("--custom=")
    two_word_flags+=("--custom")
    local_nonpersistent_flags+=("--custom")
    local_nonpersistent_flags+=("--custom=")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--no-input")
    local_nonpersistent_flags+=("--no-input")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_link_remote()
{
    last_command="jira_issue_link_remote"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")
    flags+=("--web")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_link()
{
    last_command="jira_issue_link"

    command_aliases=()

    commands=()
    commands+=("remote")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rmln")
        aliashash["rmln"]="remote"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--web")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_list()
{
    last_command="jira_issue_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--type=")
    two_word_flags+=("--type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--resolution=")
    two_word_flags+=("--resolution")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--resolution")
    local_nonpersistent_flags+=("--resolution=")
    local_nonpersistent_flags+=("-R")
    flags+=("--status=")
    two_word_flags+=("--status")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--status")
    local_nonpersistent_flags+=("--status=")
    local_nonpersistent_flags+=("-s")
    flags+=("--priority=")
    two_word_flags+=("--priority")
    two_word_flags+=("-y")
    local_nonpersistent_flags+=("--priority")
    local_nonpersistent_flags+=("--priority=")
    local_nonpersistent_flags+=("-y")
    flags+=("--reporter=")
    two_word_flags+=("--reporter")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reporter")
    local_nonpersistent_flags+=("--reporter=")
    local_nonpersistent_flags+=("-r")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--label=")
    two_word_flags+=("--label")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    local_nonpersistent_flags+=("-l")
    flags+=("--parent=")
    two_word_flags+=("--parent")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--parent")
    local_nonpersistent_flags+=("--parent=")
    local_nonpersistent_flags+=("-P")
    flags+=("--history")
    local_nonpersistent_flags+=("--history")
    flags+=("--watching")
    flags+=("-w")
    local_nonpersistent_flags+=("--watching")
    local_nonpersistent_flags+=("-w")
    flags+=("--created=")
    two_word_flags+=("--created")
    local_nonpersistent_flags+=("--created")
    local_nonpersistent_flags+=("--created=")
    flags+=("--updated=")
    two_word_flags+=("--updated")
    local_nonpersistent_flags+=("--updated")
    local_nonpersistent_flags+=("--updated=")
    flags+=("--created-after=")
    two_word_flags+=("--created-after")
    local_nonpersistent_flags+=("--created-after")
    local_nonpersistent_flags+=("--created-after=")
    flags+=("--updated-after=")
    two_word_flags+=("--updated-after")
    local_nonpersistent_flags+=("--updated-after")
    local_nonpersistent_flags+=("--updated-after=")
    flags+=("--created-before=")
    two_word_flags+=("--created-before")
    local_nonpersistent_flags+=("--created-before")
    local_nonpersistent_flags+=("--created-before=")
    flags+=("--updated-before=")
    two_word_flags+=("--updated-before")
    local_nonpersistent_flags+=("--updated-before")
    local_nonpersistent_flags+=("--updated-before=")
    flags+=("--jql=")
    two_word_flags+=("--jql")
    two_word_flags+=("-q")
    local_nonpersistent_flags+=("--jql")
    local_nonpersistent_flags+=("--jql=")
    local_nonpersistent_flags+=("-q")
    flags+=("--order-by=")
    two_word_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by=")
    flags+=("--reverse")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--paginate=")
    two_word_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate=")
    flags+=("--plain")
    local_nonpersistent_flags+=("--plain")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--no-truncate")
    local_nonpersistent_flags+=("--no-truncate")
    flags+=("--columns=")
    two_word_flags+=("--columns")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    flags+=("--fixed-columns=")
    two_word_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns=")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_move()
{
    last_command="jira_issue_move"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--comment=")
    two_word_flags+=("--comment")
    local_nonpersistent_flags+=("--comment")
    local_nonpersistent_flags+=("--comment=")
    flags+=("--assignee=")
    two_word_flags+=("--assignee")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee")
    local_nonpersistent_flags+=("--assignee=")
    local_nonpersistent_flags+=("-a")
    flags+=("--resolution=")
    two_word_flags+=("--resolution")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--resolution")
    local_nonpersistent_flags+=("--resolution=")
    local_nonpersistent_flags+=("-R")
    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_unlink()
{
    last_command="jira_issue_unlink"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--web")
    local_nonpersistent_flags+=("--web")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_view()
{
    last_command="jira_issue_view"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--comments=")
    two_word_flags+=("--comments")
    local_nonpersistent_flags+=("--comments")
    local_nonpersistent_flags+=("--comments=")
    flags+=("--plain")
    local_nonpersistent_flags+=("--plain")
    flags+=("--raw")
    local_nonpersistent_flags+=("--raw")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_watch()
{
    last_command="jira_issue_watch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_worklog_add()
{
    last_command="jira_issue_worklog_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--started=")
    two_word_flags+=("--started")
    local_nonpersistent_flags+=("--started")
    local_nonpersistent_flags+=("--started=")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--comment=")
    two_word_flags+=("--comment")
    local_nonpersistent_flags+=("--comment")
    local_nonpersistent_flags+=("--comment=")
    flags+=("--new-estimate=")
    two_word_flags+=("--new-estimate")
    local_nonpersistent_flags+=("--new-estimate")
    local_nonpersistent_flags+=("--new-estimate=")
    flags+=("--no-input")
    local_nonpersistent_flags+=("--no-input")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue_worklog()
{
    last_command="jira_issue_worklog"

    command_aliases=()

    commands=()
    commands+=("add")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_issue()
{
    last_command="jira_issue"

    command_aliases=()

    commands=()
    commands+=("assign")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("asg")
        aliashash["asg"]="assign"
    fi
    commands+=("clone")
    commands+=("comment")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("comments")
        aliashash["comments"]="comment"
    fi
    commands+=("create")
    commands+=("delete")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("del")
        aliashash["del"]="delete"
        command_aliases+=("remove")
        aliashash["remove"]="delete"
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("edit")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("modify")
        aliashash["modify"]="edit"
        command_aliases+=("update")
        aliashash["update"]="edit"
    fi
    commands+=("link")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ln")
        aliashash["ln"]="link"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("lists")
        aliashash["lists"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("move")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("mv")
        aliashash["mv"]="move"
        command_aliases+=("transition")
        aliashash["transition"]="move"
    fi
    commands+=("unlink")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("uln")
        aliashash["uln"]="unlink"
    fi
    commands+=("view")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("show")
        aliashash["show"]="view"
    fi
    commands+=("watch")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("wat")
        aliashash["wat"]="watch"
    fi
    commands+=("worklog")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("wlg")
        aliashash["wlg"]="worklog"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_man()
{
    last_command="jira_man"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--generate")
    flags+=("-g")
    local_nonpersistent_flags+=("--generate")
    local_nonpersistent_flags+=("-g")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_me()
{
    last_command="jira_me"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_open()
{
    last_command="jira_open"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-browser")
    flags+=("-n")
    local_nonpersistent_flags+=("--no-browser")
    local_nonpersistent_flags+=("-n")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_project_list()
{
    last_command="jira_project_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_project()
{
    last_command="jira_project"

    command_aliases=()

    commands=()
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("lists")
        aliashash["lists"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_serverinfo()
{
    last_command="jira_serverinfo"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_sprint_add()
{
    last_command="jira_sprint_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_sprint_close()
{
    last_command="jira_sprint_close"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_sprint_list()
{
    last_command="jira_sprint_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--component=")
    two_word_flags+=("--component")
    two_word_flags+=("-C")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    local_nonpersistent_flags+=("-C")
    flags+=("--parent=")
    two_word_flags+=("--parent")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--parent")
    local_nonpersistent_flags+=("--parent=")
    local_nonpersistent_flags+=("-P")
    flags+=("--jql=")
    two_word_flags+=("--jql")
    two_word_flags+=("-q")
    local_nonpersistent_flags+=("--jql")
    local_nonpersistent_flags+=("--jql=")
    local_nonpersistent_flags+=("-q")
    flags+=("--order-by=")
    two_word_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by")
    local_nonpersistent_flags+=("--order-by=")
    flags+=("--paginate=")
    two_word_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate")
    local_nonpersistent_flags+=("--paginate=")
    flags+=("--plain")
    local_nonpersistent_flags+=("--plain")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--no-truncate")
    local_nonpersistent_flags+=("--no-truncate")
    flags+=("--state=")
    two_word_flags+=("--state")
    local_nonpersistent_flags+=("--state")
    local_nonpersistent_flags+=("--state=")
    flags+=("--show-all-issues")
    local_nonpersistent_flags+=("--show-all-issues")
    flags+=("--table")
    local_nonpersistent_flags+=("--table")
    flags+=("--columns=")
    two_word_flags+=("--columns")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    flags+=("--fixed-columns=")
    two_word_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns")
    local_nonpersistent_flags+=("--fixed-columns=")
    flags+=("--current")
    local_nonpersistent_flags+=("--current")
    flags+=("--prev")
    local_nonpersistent_flags+=("--prev")
    flags+=("--next")
    local_nonpersistent_flags+=("--next")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_sprint()
{
    last_command="jira_sprint"

    command_aliases=()

    commands=()
    commands+=("add")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("assign")
        aliashash["assign"]="add"
    fi
    commands+=("close")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("complete")
        aliashash["complete"]="close"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("lists")
        aliashash["lists"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_version()
{
    last_command="jira_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_jira_root_command()
{
    last_command="jira"

    command_aliases=()

    commands=()
    commands+=("board")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("boards")
        aliashash["boards"]="board"
    fi
    commands+=("completion")
    commands+=("epic")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("epics")
        aliashash["epics"]="epic"
    fi
    commands+=("help")
    commands+=("init")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("config")
        aliashash["config"]="init"
        command_aliases+=("configure")
        aliashash["configure"]="init"
        command_aliases+=("initialize")
        aliashash["initialize"]="init"
        command_aliases+=("setup")
        aliashash["setup"]="init"
    fi
    commands+=("issue")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("issues")
        aliashash["issues"]="issue"
    fi
    commands+=("man")
    commands+=("me")
    commands+=("open")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("browse")
        aliashash["browse"]="open"
        command_aliases+=("navigate")
        aliashash["navigate"]="open"
    fi
    commands+=("project")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("projects")
        aliashash["projects"]="project"
    fi
    commands+=("serverinfo")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("systeminfo")
        aliashash["systeminfo"]="serverinfo"
    fi
    commands+=("sprint")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("sprints")
        aliashash["sprints"]="sprint"
    fi
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--debug")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_jira()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __jira_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("jira")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __jira_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_jira jira
else
    complete -o default -o nospace -F __start_jira jira
fi

# ex: ts=4 sw=4 et filetype=sh
