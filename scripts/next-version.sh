#!/usr/bin/env bash
# Computes the next version from the commit titles on main since the latest
# v<major>.<minor>.<patch> tag. Rules: btmx-sdlc docs/versioning.md.
#   breaking (`type!:` or a BREAKING CHANGE footer) → major
#   feat → minor
#   fix, perf, refactor, revert → patch
#   docs, chore, ci, test, style, build → no release
#   no type → no release, warning
# No tag yet → 1.0.0. Nothing releasable → empty version, exit 0.
#
# Usage: next-version.sh [<rev>]   (default HEAD; run in the repo's clone,
#   with full history and tags: actions/checkout with fetch-depth: 0)
# Output: a summary on stdout (and in $GITHUB_STEP_SUMMARY);
#   `version` and `changelog` in $GITHUB_OUTPUT when it is set.
# Keep the type lists in sync with .github/workflows/pr-title.yml.
set -euo pipefail

rev="${1:-HEAD}"

breaking='^[a-z]+(\([^)]*\))?!:'
minor_types='^feat(\([^)]*\))?:'
patch_types='^(fix|perf|refactor|revert)(\([^)]*\))?:'
no_release='^(docs|chore|ci|test|style|build)(\([^)]*\))?:'

base="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --merged "$rev" --sort=-v:refname | head -n 1)"
range="$rev"
[ -z "$base" ] || range="$base..$rev"
shas="$(git rev-list --first-parent "$range")"

level=""
changelog=""
for sha in $shas; do
    msg="$(git log -1 --format=%B "$sha")"
    title="$(head -n 1 <<<"$msg")"
    # A merge commit (not squash) keeps the PR title on its first non-empty body line.
    if [[ "$title" == "Merge pull request"* ]]; then
        title="$(sed -n '2,$p' <<<"$msg" | grep -v '^[[:space:]]*$' | head -n 1 || true)"
    fi
    if [[ "$title" =~ $breaking ]] || grep -Eq '^BREAKING[ -]CHANGE:' <<<"$msg"; then
        level=major
    elif [[ "$title" =~ $minor_types ]]; then
        [ "$level" = major ] || level=minor
    elif [[ "$title" =~ $patch_types ]]; then
        [ -n "$level" ] || level=patch
    elif [[ "$title" =~ $no_release ]]; then
        continue
    else
        # No type, e.g. a file committed from GitHub's web page.
        echo "::warning::Not released, no conventional type: $title"
        continue
    fi
    changelog+="- ${title}"$'\n'
done

if [ -z "$changelog" ]; then
    echo "::notice::No releasable changes since ${base:-the start}"
    exit 0
fi

if [ -z "$base" ]; then
    version=1.0.0
    level=initial
else
    IFS=. read -r major minor patch <<<"${base#v}"
    case "$level" in
        major) version="$((major + 1)).0.0" ;;
        minor) version="$major.$((minor + 1)).0" ;;
        *) version="$major.$minor.$((patch + 1))" ;;
    esac
fi

{
    echo "## Release ${version}"
    echo "Base: ${base:-none} · bump: ${level}"
    echo
    printf '%s' "$changelog"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    delimiter="EOF_$RANDOM$RANDOM"
    {
        echo "version=$version"
        echo "changelog<<$delimiter"
        printf '%s' "$changelog"
        echo "$delimiter"
    } >>"$GITHUB_OUTPUT"
fi
