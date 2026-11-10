#!/usr/bin/env bash
# Publishes a release (ADR 0016): tests and builds the app, packs it into a
# DMG, creates the GitHub Release v<version> and points the Homebrew cask in
# bytemux/homebrew-tap at it. Run by .github/workflows/release.yml, which
# computes the version from the commits since the last tag.
# Usage: VERSION=1.2.3 [CHANGELOG=...] [TAP_TOKEN=...] scripts/release.sh
#   TAP_TOKEN: token with write access to the tap (default: gh's login)
set -euo pipefail

cd "$(dirname "$0")/.."
repo="bytemux/btmx-focus"
tap="bytemux/homebrew-tap"
version="${VERSION:?set VERSION, e.g. VERSION=1.2.3}"
export VERSION # build-app.sh stamps it into the bundle
tag="v$version"
dmg="build/btmx-focus-$version.dmg"

die() {
    echo "release: $*" >&2
    exit 1
}

git fetch --quiet origin --tags
! git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null || die "$tag already exists; bump the version"

# The snapshots are pixel references recorded on a developer's Mac; a CI
# runner renders them differently (docs/testing.md). They run in `swift test`.
swift test --skip SnapshotTests
scripts/build-app.sh release

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R build/btmx-focus.app "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname btmx-focus -srcfolder "$staging" -format UDZO -quiet "$dmg"
sha256="$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)"

gh release create "$tag" "$dmg" --repo "$repo" --target "$(git rev-parse HEAD)" \
    --title "btmx-focus $version" --notes "$(
        cat <<EOF
Install with Homebrew:

\`\`\`sh
brew install bytemux/tap/btmx-focus
\`\`\`

Or download \`btmx-focus-$version.dmg\` and drag the app to Applications.
The app isn't notarized, so macOS blocks the first launch; allow it in
System Settings → Privacy & Security → Open Anyway, or run:

\`\`\`sh
xattr -dr com.apple.quarantine /Applications/btmx-focus.app
\`\`\`

Requires macOS 15 or newer on Apple silicon.

## Changes

${CHANGELOG:-}
EOF
    )"

if [ -n "${TAP_TOKEN:-}" ]; then
    git clone --quiet "https://x-access-token:$TAP_TOKEN@github.com/$tap.git" "$staging/tap"
else
    gh repo clone "$tap" "$staging/tap" -- --quiet
fi
cask="$staging/tap/Casks/btmx-focus.rb"
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$sha256\"/" "$cask"
git -C "$staging/tap" -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -am "btmx-focus $version"
git -C "$staging/tap" push --quiet

echo "Released $tag: https://github.com/$repo/releases/tag/$tag"
