#!/usr/bin/env bash
# Before Claude runs `git push`: the commits must have been reviewed by the code-reviewer agent
# (.claude/agents/code-reviewer.md). A clean review is recorded for the commit it covered, so a push of that commit
# goes ahead, and any new commit needs a review of its own. The record is the agent's own word that it ran the
# review; it keeps the step from being forgotten, not from being skipped on purpose.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || printf '%s' "$input")

# A push is `git push` at the start of the command or of one of its parts (after ;, &&, || or |), not the words
# quoted in some text. The `if` in settings.json picks these out too, but only on a best-effort basis.
push=$(grep -oE '(^|[;&|(])[[:space:]]*git[[:space:]]+push([[:space:]][^;&|)]*)?' <<<"$command" | head -1 || true)
[ -n "$push" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}"
# The branch the push names (`git push [-u] origin <branch>`, or <branch>:<remote branch>), else the current one.
# The hook runs before the whole command, so a branch switched to earlier in the same command isn't current yet.
words=$(sed -E 's/^[;&|([:space:]]*git[[:space:]]+push//' <<<"$push" | tr -s '[:space:]' '\n' | grep -v '^-' | grep -v '^$' || true)
branch=$(sed -n 2p <<<"$words" | cut -d: -f1)
branch=${branch:-$(git rev-parse --abbrev-ref HEAD)}
commit=$(git rev-parse --verify --quiet "$branch^{commit}" || git rev-parse HEAD)
record="$(git rev-parse --git-dir)/code-reviewed-$commit"
[ -f "$record" ] && exit 0

cat >&2 <<MESSAGE
Push stopped: $branch ($commit) hasn't been reviewed.
1. Run the code-reviewer agent on the commits this push sends: the new ones (origin/$branch..$branch) on a branch
   that's already pushed, or the branch against its base (e.g. origin/main...$branch) on a new one. Ask it to check
   correctness and security besides the usual review.
2. Fix what it finds, committing the fixes, and review those too.
3. Once a review finds nothing blocking: touch "$record"
4. Push again.
MESSAGE
exit 2
