#!/usr/bin/env bash
# Runs before each of Claude's Bash commands, and stops a `git push` until its commits have been reviewed by the
# code-reviewer agent (.claude/agents/code-reviewer.md). A clean review is recorded for the commit it covered, so a
# push of that commit goes ahead, and any new commit needs a review of its own. The record is the agent's own word
# that it ran the review; it keeps the step from being forgotten, not from being skipped on purpose. Pushes it can't
# see (`git -C dir push`, aliases, `bash -c`, the GitHub tools) aren't checked.
set -euo pipefail

input=$(cat)
field() { # a field of the hook's JSON input, by jq if it's installed, else by Python
  if command -v jq >/dev/null; then jq -r "$1 // empty" <<<"$input"
  else python3 -c 'import json, sys; v = json.load(sys.stdin)
for k in sys.argv[1].strip(".").split("."): v = (v or {}).get(k)
print(v or "")' "$1" <<<"$input"
  fi
}
command=$(field .tool_input.command)
cwd=$(field .cwd)

# A push is `git push` at the start of the command or of one of its parts (after ;, &&, || or |, or in a subshell),
# not the words quoted in some text.
part='(^|[;&|(])[[:space:]]*git[[:space:]]+'
push=$(grep -oE "${part}push([[:space:]][^;&|)]*)?" <<<"$command" | head -1 || true)
[ -n "$push" ] || exit 0
# Deleting a remote branch sends no commits
grep -qE '[[:space:]](--delete|-d)([[:space:]]|$)' <<<"$push" && exit 0

cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}"
# Shared by every worktree of the repository, and absolute, so the record can be made from any directory
records=$(cd "$(git rev-parse --git-common-dir)" && pwd)

# The hook runs before the whole command, so a commit made earlier in the same command isn't there yet to check
if grep -qE "${part}(commit|merge|rebase|cherry-pick|am|pull|reset|revert)([[:space:]]|$)" <<<"$command"; then
  echo "Push stopped: push in a command of its own, after any commit, so the commit pushed is the one checked." >&2
  exit 2
fi

# The branch the push names (`git push [-u] origin <branch>`, or <branch>:<remote branch>), else the current one
words=$(sed -E 's/^[;&|([:space:]]*git[[:space:]]+push//' <<<"$push" | tr -s '[:space:]' '\n' | grep -v '^-' | grep -v '^$' || true)
branch=$(sed -n 2p <<<"$words" | cut -d: -f1)
branch=${branch:-$(git rev-parse --abbrev-ref HEAD)}
commit=$(git rev-parse --verify --quiet "$branch^{commit}" || git rev-parse HEAD)
record="$records/code-reviewed-$commit"
[ -f "$record" ] && exit 0

cat >&2 <<MESSAGE
Push stopped: $branch ($commit) hasn't been reviewed.
1. Run the code-reviewer agent on the commits this push sends: the new ones (origin/$branch..$branch) on a branch
   that's already pushed, or the branch against its base (e.g. origin/main...$branch) on a new one. Ask it to check
   correctness and security besides the usual review.
2. Fix what it finds, committing the fixes, and review those too.
3. Once a review finds nothing blocking, in a command of its own: touch "$record"
4. Push again, in a command of its own.
MESSAGE
exit 2
