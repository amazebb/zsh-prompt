#!/usr/bin/env zsh
# Regression tests for zsh-prompt. Run: zsh -f test.zsh
here=${0:A:h}
tmp=$(mktemp -d) || exit 1
trap 'cd /; rm -rf $tmp' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_{AUTHOR,COMMITTER}_NAME=t GIT_{AUTHOR,COMMITTER}_EMAIL=t@t
source $here/zsh-prompt >/dev/null
chpwd_functions=()  # no terminal-title output

integer fails=0
ok() {  # name, got, want
    [[ $2 == "$3" ]] && print "ok   $1" || { print "FAIL $1: got '$2', want '$3'"; (( ++fails )) }
}
ran() { [[ -e $1 ]] && print ran || print clean }  # did a command create file $1?
repo() { git init -q -b main $1 && cd $1 && git commit -q --allow-empty -m i }

# _esc: with prompt_subst on, a path or branch must not run commands
setopt prompt_subst
mkdir -p $tmp/inj/'$(touch PWNED)' && cd $tmp/inj/'$(touch PWNED)'
_ps1; print -r -- ${(e)PS1} >/dev/null
ok "path injection" $(ran PWNED) clean
repo $tmp/br
git checkout -q -b '$(>PWNED2</dev/null)'
_git_pre; _ps1; print -r -- ${(e)PS1} >/dev/null
ok "branch injection" $(ran PWNED2) clean
unsetopt prompt_subst
_git_pre; _ps1
ok "no backslashes when prompt_subst is off" "${PS1//[^\\]}" ""

# a '+' in the branch name is not a working tree change
repo $tmp/plus
git checkout -q -b feat+x
_git_pre
ok "clean repo with + in branch" $_ZZ_STATE[gc] go
touch new
_git_pre
ok "untracked file is a change" $_ZZ_STATE[gc] gx

# the repo's own core.fsmonitor must not run
repo $tmp/fsm
git config core.fsmonitor "touch $PWD/ran; echo"
git status >/dev/null 2>&1
if [[ -e ran ]]; then
    rm ran
    _git_pre
    ok "fsmonitor not run" $(ran ran) clean
else
    print "skip fsmonitor not run: this git ignores core.fsmonitor"
fi

# an unborn branch shows its name; a detached HEAD stays HEAD
git init -q -b main $tmp/unborn && cd $tmp/unborn
_git_pre
ok "unborn branch" $_ZD[prompt] main
repo $tmp/det
git checkout -q --detach
_git_pre
ok "detached HEAD" $_ZD[prompt] HEAD

exit $(( fails > 0 ))
