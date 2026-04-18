#!/usr/bin/env bash
# Sync the labels defined in labels.yml to one or more Nootski repositories.
#
# Usage:
#   ./scripts/sync-labels.sh                     # apply to ALL Nootski repos
#   ./scripts/sync-labels.sh owner/repo ...      # apply to specific repos
#   ./scripts/sync-labels.sh --dry-run           # show what would happen
#   ./scripts/sync-labels.sh --delete-stale      # also delete labels not in labels.yml
#
# Requires: gh, yq, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LABELS_FILE="$REPO_ROOT/labels.yml"

DRY_RUN=false
DELETE_STALE=false
REPOS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --delete-stale) DELETE_STALE=true ;;
    -*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *) REPOS+=("$arg") ;;
  esac
done

for bin in gh yq jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: '$bin' is required but not installed." >&2
    echo "  Install with: brew install $bin" >&2
    exit 1
  fi
done

if [[ ! -f "$LABELS_FILE" ]]; then
  echo "Error: labels file not found at $LABELS_FILE" >&2
  exit 1
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No repos specified — fetching ALL repos for user Nootski..."
  while IFS= read -r line; do
    REPOS+=("$line")
  done < <(gh repo list Nootski --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')
  echo "Found ${#REPOS[@]} repos."
fi

# Parse labels.yml into a JSON array we can iterate easily.
LABELS_JSON="$(yq -o=json '.' "$LABELS_FILE")"
LABEL_COUNT="$(echo "$LABELS_JSON" | jq 'length')"

echo "────────────────────────────────────────────────"
echo "Label sync"
echo "  Labels defined: $LABEL_COUNT"
echo "  Target repos:   ${#REPOS[@]}"
echo "  Dry run:        $DRY_RUN"
echo "  Delete stale:   $DELETE_STALE"
echo "────────────────────────────────────────────────"

apply_to_repo() {
  local repo="$1"
  echo
  echo "▶ $repo"

  local existing
  if ! existing="$(gh label list --repo "$repo" --limit 200 --json name,color,description 2>/dev/null)"; then
    echo "  ✗ Cannot access repo (skipping)"
    return
  fi

  for i in $(seq 0 $((LABEL_COUNT - 1))); do
    local name color description
    name="$(echo "$LABELS_JSON" | jq -r ".[$i].name")"
    color="$(echo "$LABELS_JSON" | jq -r ".[$i].color")"
    description="$(echo "$LABELS_JSON" | jq -r ".[$i].description // \"\"")"

    if echo "$existing" | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null; then
      if $DRY_RUN; then
        echo "  = update: $name"
      else
        gh label edit "$name" --repo "$repo" --color "$color" --description "$description" >/dev/null
        echo "  = updated: $name"
      fi
    else
      if $DRY_RUN; then
        echo "  + create: $name"
      else
        gh label create "$name" --repo "$repo" --color "$color" --description "$description" >/dev/null
        echo "  + created: $name"
      fi
    fi
  done

  if $DELETE_STALE; then
    local desired
    desired="$(echo "$LABELS_JSON" | jq -r '.[].name')"
    echo "$existing" | jq -r '.[].name' | while read -r existing_name; do
      if ! echo "$desired" | grep -Fxq "$existing_name"; then
        if $DRY_RUN; then
          echo "  - delete: $existing_name"
        else
          gh label delete "$existing_name" --repo "$repo" --yes >/dev/null
          echo "  - deleted: $existing_name"
        fi
      fi
    done
  fi
}

for repo in "${REPOS[@]}"; do
  apply_to_repo "$repo"
done

echo
echo "Done."
