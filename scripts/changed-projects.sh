#!/usr/bin/env bash
# Print a JSON array of project parameter files to preview or deploy, for the
# deploy-projects workflow matrix: [{"project":"orders","environment":"dev","parametersFile":"projects/orders/dev.bicepparam"}]
#
# Usage:
#   scripts/changed-projects.sh pr       <base-sha> <head-sha>   # changed project files; all projects if shared code changed
#   scripts/changed-projects.sh push     <before-sha> <after-sha> # changed project files only
#   scripts/changed-projects.sh dispatch <project> <environment>  # one project file
#
# Only files named <environment>.bicepparam for an environment in ENVIRONMENTS are included,
# and folders starting with "_" (examples) are skipped.
set -euo pipefail

ENVIRONMENTS="${ENVIRONMENTS:-dev prod}"
mode="${1:?mode: pr, push or dispatch}"

# Files whose change affects every project (previewed on pull requests)
shared_pattern='^(projects/main\.bicep|modules/|\.github/workflows/(deploy-projects|_bicep-deploy)\.yml|scripts/changed-projects\.sh)'

case "$mode" in
  dispatch)
    candidates="projects/${2:?project}/${3:?environment}.bicepparam"
    [[ -f "$candidates" ]] || { echo "Parameters file not found: $candidates" >&2; exit 1; }
    ;;
  pr|push)
    base="${2:?base sha}"; head="${3:?head sha}"
    if [[ "$base" =~ ^0+$ ]] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
      echo "Base commit $base not available; nothing to do" >&2
      echo '[]'; exit 0
    fi
    if [[ "$mode" == pr ]]; then
      changed=$(git diff --name-only "$base...$head")
    else
      changed=$(git diff --name-only "$base" "$head")
    fi
    if [[ "$mode" == pr ]] && grep -Eq "$shared_pattern" <<< "$changed"; then
      candidates=$(git ls-files 'projects/*/*.bicepparam')
    else
      candidates=$(grep -E '^projects/[^/]+/[^/]+\.bicepparam$' <<< "$changed" || true)
    fi
    ;;
  *)
    echo "Unknown mode: $mode" >&2; exit 1 ;;
esac

for f in $candidates; do
  [[ -f "$f" ]] || continue                        # deleted in this change
  project=$(basename "$(dirname "$f")")
  env=$(basename "$f" .bicepparam)
  [[ "$project" == _* ]] && continue               # examples are validated, never deployed
  [[ " $ENVIRONMENTS " == *" $env "* ]] || { echo "Skipping $f: '$env' is not one of: $ENVIRONMENTS" >&2; continue; }
  jq -cn --arg p "$project" --arg e "$env" --arg f "$f" '{project: $p, environment: $e, parametersFile: $f}'
done | jq -cs '.'
