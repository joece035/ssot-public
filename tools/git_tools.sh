#!/usr/bin/env bash
# 12-git.sh — Git CLI helpers (SSOT)
# Source via joe.sh. Self-contained: safe to source multiple times.
# Author: Alpha for พี่โจ


# ---- zsh: unalias names that collide with oh-my-zsh git plugin ----
# omz git plugin (loaded first in zshrc) defines g/ga/gaa/gcmsg/gco/gd/glog/gp/
# gclean as aliases. zsh expands aliases at parse time, so `gd() { ... }`
# becomes `git diff() { ... }` -> "parse error near `()'" / "defining
# function based on alias". Unalias before defining our functions.
# No-op in bash or when the alias doesn't exist.
unalias git_ clone ga gaa gclean gcmsg gco gd glog gp 2>/dev/null || true

# ---- ANSI colors (no hardcode — matches 01-colors.sh style) ----
G_CYAN=$'\e[38;5;87m'
G_GRN=$'\e[38;5;82m'
G_YEL=$'\e[38;5;220m'
G_RED=$'\e[38;5;196m'
G_DIM=$'\e[38;5;245m'
G_RST=$'\e[0m'

_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

_git_need_repo() {
  local root
  root="$(_git_root)"
  if [[ -z "$root" ]]; then
    echo -e "${G_RED}✗ not a git repo${G_RST}" >&2
    return 1
  fi
  REPO_ROOT="$root"
  return 0
}

# ---- gs : git status (pretty) ----
gs() {
  if ! _git_need_repo; then return 1; fi
  echo -e "${G_CYAN}📂 $REPO_ROOT${G_RST}"
  git -C "$REPO_ROOT" status -sb
}

# ---- gd : git diff (short) ----
gd() {
  if ! _git_need_repo; then return 1; fi
  if [[ $# -gt 0 ]]; then
    git -C "$REPO_ROOT" diff "$@"
  else
    git -C "$REPO_ROOT" diff --stat
  fi
}

# ---- ga <files...> : git add ----
ga() {
  if ! _git_need_repo; then return 1; fi
  git -C "$REPO_ROOT" add "${@:-.}"
  echo -e "${G_GRN}✓ staged:${G_RST}"
  git -C "$REPO_ROOT" diff --cached --stat
}

# ---- gaa : git add --all ----
gaa() {
  if ! _git_need_repo; then return 1; fi
  git -C "$REPO_ROOT" add -A
  echo -e "${G_GRN}✓ all staged${G_RST}"
  git -C "$REPO_ROOT" diff --cached --stat
}

# ---- gcmsg "<msg>" : commit with message ----
gcmsg() {
  if ! _git_need_repo; then return 1; fi
  if [[ -z "${1:-}" ]]; then
    echo -e "${G_YEL}usage: gcmsg \"<message>\"${G_RST}" >&2
    return 1
  fi
  git -C "$REPO_ROOT" commit -m "$1"
}

# ---- gac "<msg>" : add all + commit ----
gac() {
  if ! _git_need_repo; then return 1; fi
  if [[ -z "${1:-}" ]]; then
    echo -e "${G_YEL}usage: gac \"<message>\"${G_RST}" >&2
    return 1
  fi
  git -C "$REPO_ROOT" add -A
  git -C "$REPO_ROOT" commit -m "$1"
}

# ---- gp : git push (current branch → origin) ----
gp() {
  if ! _git_need_repo; then return 1; fi
  local branch
  branch="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null)"
  if [[ -z "$branch" ]]; then
    echo -e "${G_RED}✗ detached HEAD — no branch to push${G_RST}" >&2
    return 1
  fi

  # upstream check
  local upstream
  upstream="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
  if [[ -z "$upstream" ]]; then
    echo -e "${G_YEL}⚠ no upstream — push with -u origin/${branch}${G_RST}"
    git -C "$REPO_ROOT" push -u origin "$branch" "$@"
  else
    git -C "$REPO_ROOT" push "$@" "$branch"
  fi
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo -e "${G_GRN}✓ pushed → origin/${branch}${G_RST}"
  else
    echo -e "${G_RED}✗ push failed (rc=$rc) — maybe need: gpl (pull --rebase first)${G_RST}" >&2
  fi
  return $rc
}

# ---- gpl : git pull (with rebase if local commits exist) ----
gpl() {
  if ! _git_need_repo; then return 1; fi
  local branch
  branch="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null)"
  local upstream
  upstream="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"

  if [[ -z "$upstream" ]]; then
    echo -e "${G_YEL}⚠ no upstream — set with: gp (will -u automatically)${G_RST}" >&2
    return 1
  fi

  # If we have local commits, rebase to keep history clean
  local local_ahead
  local_ahead="$(git -C "$REPO_ROOT" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  if [[ "${local_ahead:-0}" -gt 0 ]]; then
    echo -e "${G_DIM}↻ pulling with rebase (local commits: $local_ahead)${G_RST}"
    git -C "$REPO_ROOT" pull --rebase "$@"
  else
    git -C "$REPO_ROOT" pull "$@"
  fi
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo -e "${G_GRN}✓ pulled ← origin/${branch}${G_RST}"
  else
    echo -e "${G_RED}✗ pull failed (rc=$rc)${G_RST}" >&2
  fi
  return $rc
}

# ---- gsync : pull --rebase + push (one shot for "I want to be in sync") ----
gsync() {
  if ! _git_need_repo; then return 1; fi
  local branch
  branch="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null)"
  echo -e "${G_CYAN}↻ syncing ${branch}...${G_RST}"

  if ! gpl; then return 1; fi
  if ! gp; then return 1; fi
  echo -e "${G_GRN}✓ in sync with origin/${branch}${G_RST}"
}

# ---- glog : compact log ----
glog() {
  if ! _git_need_repo; then return 1; fi
  local n="${1:-10}"
  git -C "$REPO_ROOT" log --oneline --graph --decorate -n "$n"
}

# ---- gnew <branch> : create + checkout ----
gnew() {
  if ! _git_need_repo; then return 1; fi
  if [[ -z "${1:-}" ]]; then
    echo -e "${G_YEL}usage: gnew <branch-name>${G_RST}" >&2
    return 1
  fi
  git -C "$REPO_ROOT" checkout -b "$1"
}

# ---- gco <branch> : checkout ----
gco() {
  if ! _git_need_repo; then return 1; fi
  if [[ -z "${1:-}" ]]; then
    git -C "$REPO_ROOT" branch -a
    return 0
  fi
  git -C "$REPO_ROOT" checkout "$1"
}

# ---- gundo : soft reset last commit (keep changes staged) ----
gundo() {
  if ! _git_need_repo; then return 1; fi
  echo -e "${G_YEL}↶ soft reset HEAD~1 (changes stay staged)${G_RST}"
  git -C "$REPO_ROOT" reset --soft HEAD~1
}

# ---- gstash [msg] : stash with optional message ----
gstash() {
  if ! _git_need_repo; then return 1; fi
  if [[ -n "${1:-}" ]]; then
    git -C "$REPO_ROOT" stash push -m "$1"
  else
    git -C "$REPO_ROOT" stash push
  fi
  echo -e "${G_GRN}✓ stashed${G_RST}"
}

# ---- gpop : pop last stash ----
gpop() {
  if ! _git_need_repo; then return 1; fi
  git -C "$REPO_ROOT" stash pop
}

# ---- gclean : PREVIEW only (always safe to run) ----
# Lists untracked + ignored files in repo root. NEVER deletes.
gclean() {
  if ! _git_need_repo; then return 1; fi
  echo -e "${G_CYAN}preview — untracked + ignored files in repo root:${G_RST}"
  git -C "$REPO_ROOT" clean -ndx
}

# ---- gcleanx : ⚠ DESTRUCTIVE — require 2-step confirmation ----
# SAFETY: refuses if any target is a critical config dir
# (.stfolder, .vscode, .git, .obsidian, .syncthing).
# This guard exists because git clean -x will happily remove
# .stfolder/ and break Syncthing sync, or .vscode/ and kill
# editor settings. Those are NEVER build artifacts.
gcleanx() {
  if ! _git_need_repo; then return 1; fi

  echo -e "${G_RED}⚠ DESTRUCTIVE: git clean -fdx (untracked + ignored)${G_RST}"
  echo -e "${G_DIM}preview:${G_RST}"
  local preview
  preview="$(git -C "$REPO_ROOT" clean -ndx)"
  if [[ -z "$preview" ]]; then
    echo -e "${G_GRN}✓ nothing to clean${G_RST}"
    return 0
  fi
  echo "$preview"
  echo ""

  # Safety guard — refuse if critical paths appear in target list.
  # Word boundary: only match exact dir/file names like ".git" or ".gitignore"
  # must NOT be treated as ".git" (the word "ignore" must not match).
  # We use `grep -E` with explicit boundaries.
  local dangerous_pattern='(^\s*Would remove (\.stfolder|\.stversions|\.vscode|\.git|\.obsidian|\.syncthing)/|\s\.git/?$|\sjoe\.sh\.bak)'
  if echo "$preview" | grep -qE "$dangerous_pattern"; then
    echo -e "${G_RED}✗ ABORTED — critical paths in target list:${G_RST}"
    echo "$preview" | grep -E "$dangerous_pattern" | sed 's/^/    /'
    echo ""
    echo -e "${G_YEL}these are NOT build artifacts. If you really mean it,${G_RST}"
    echo -e "${G_YEL}remove them manually with: rm -rf <path>${G_RST}"
    return 2
  fi

  # 2-step confirmation
  local ans1 ans2
  echo -e "${G_YEL}Type 'yes' to continue:${G_RST} \c"
  read -r ans1
  [[ "$ans1" == "yes" ]] || { echo "aborted"; return 1; }

  echo -e "${G_RED}Last chance — type the literal word 'delete':${G_RST} \c"
  read -r ans2
  [[ "$ans2" == "delete" ]] || { echo "aborted"; return 1; }

  git -C "$REPO_ROOT" clean -fdx
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo -e "${G_GRN}✓ cleaned${G_RST}"
  else
    echo -e "${G_RED}✗ failed (rc=$rc)${G_RST}"
  fi
  return $rc
}

# Backward-compat: gclean! → gcleanx (so old muscle memory still
# hits the safe path; new name makes the danger explicit).
# NOTE: defined as a FUNCTION (not alias) — zsh expands aliases at parse
# time, so `alias gclean!` followed by `gclean!()` would fail with
# "defining function based on alias". Function name works in bash + zsh.
gclean!() { gcleanx "$@"; }

# ---- help ----
ghelp() {
  cat <<'EOF'
git helpers (Alpha SSOT)
────────────────────────
  gs            git status -sb
  gd [args]     git diff (--stat default)
  ga [files]    git add (all if no args)
  gaa           git add -A
  gcmsg "msg"   git commit -m
  gac  "msg"    add all + commit
  gpl           git pull (rebase if local commits)
  gp            git push (auto -u on first push)
  gsync         gpl + gp (full sync)
  glog [n]      compact log (default 10)
  gnew <name>   checkout -b
  gco [name]    checkout (or list branches)
  gundo         soft reset HEAD~1
  gstash [msg]  stash with optional message
  gpop          pop last stash
  gclean        preview untracked+ignored (safe — never deletes)
  gcleanx       DESTRUCTIVE — 2-step confirm + safety guard
                (refuses if .stfolder/.vscode/.git in target list)
  ghelp         this help

workflow (most common):
  gs → gac "fix: thing" → gsync
EOF
}

copy(){
  local src=${1:-$HWSL/ssot}
  local tar=${2:-$hpc/ssot}

  # validate directories exist
  if [[ ! -d "$src" || ! -d "$tar" ]]; then
    c 198 b "Error: Source directory '$src' or Target directory '$tar' does not exist.";
    return 1
  fi
  
  #Remove Target Directory
  cn 45 b "Remove Target Directory."; cn 10 b "$tar";
  rm -rf "$tar" &&

  #Copy Source Directory
  cn 45 b "Copy Source Directory."; cn 10 b "$src";
  cp -r "$src" "$tar" &&
  cn 45 b "Copied '$src' to '$tar'";
  cn 206 b ""
}
#change remote url 
alias gremote='git remote set-url origin git@github.com:joece035/ssot-public.git'


