#!/usr/bin/env bash
# Run by the SessionStart hook in .claude/settings.json: copies git/pre-push into the repository's own hooks
# directory, so every branch's pushes are checked, old ones included. Only that one hook is installed, and it only
# runs on a push: a branch can't add hooks that run on checkout. A pre-push hook that isn't this one is left alone.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}"
source=.claude/hooks/git/pre-push
[ -f "$source" ] || exit 0

# A hooks directory set in git's config may be shared by other repositories (e.g. a global ~/.githooks)
if hooks_path=$(git config --get core.hooksPath); then
  echo "Not installing $source: core.hooksPath is set ($hooks_path), so hooks may be shared with other repositories." >&2
  exit 0
fi

target=$(git rev-parse --git-path hooks)/pre-push
if [ -e "$target" ] && ! grep -q "code-reviewer agent" "$target"; then
  echo "Not installing $source: $target is another pre-push hook." >&2
  exit 0
fi

mkdir -p "$(dirname "$target")"
cp "$source" "$target"
chmod +x "$target"
