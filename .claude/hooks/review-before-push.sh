#!/usr/bin/env bash
# Before Claude runs `git push`: the commits must have been reviewed by the code-reviewer agent
# (.claude/agents/code-reviewer.md). A clean review is recorded for the commit it covered, so a push of that commit
# goes ahead, and any new commit needs a review of its own. The record is the agent's own word that it ran the
# review; it keeps the step from being forgotten, not from being skipped on purpose.
set -euo pipefail

# The `if` in settings.json already picks out `git push`; this checks again, as the docs advise
grep -q 'git push' || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}"
head=$(git rev-parse HEAD)
record="$(git rev-parse --git-dir)/code-reviewed-$head"
[ -f "$record" ] && exit 0

branch=$(git rev-parse --abbrev-ref HEAD)
cat >&2 <<MESSAGE
Push stopped: $head hasn't been reviewed.
1. Run the code-reviewer agent on the commits this push sends: the new ones (origin/$branch..HEAD) on a branch
   that's already pushed, or the branch against its base (e.g. origin/main...HEAD) on a new one. Ask it to check
   correctness and security besides the usual review.
2. Fix what it finds, committing the fixes, and review those too.
3. Once a review finds nothing blocking: touch "$record"
4. Push again.
MESSAGE
exit 2
