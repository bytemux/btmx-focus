#!/usr/bin/env bash
# Publishes a release (ADR 0016): builds the app, packs it into a DMG,
# creates the GitHub Release v<version> and points the Homebrew cask in
# bytemux/homebrew-tap at it. The version is CFBundleShortVersionString in
# Support/Info.plist; bump it in a PR first.
# Usage: scripts/release.sh            (from an up-to-date, clean main)
set -euo pipefail

cd "$(dirname "$0")/.."
repo="bytemux/btmx-focus"
tap="bytemux/homebrew-tap"
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)"
tag="v$version"
dmg="build/btmx-focus-$version.dmg"

die() {
    echo "release: $*" >&2
    exit 1
}

[ "$(git branch --show-current)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "working tree is dirty"
git fetch --quiet origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not in sync with origin/main"
! git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null || die "$tag already exists; bump the version"

swift test
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
EOF
    )"
git fetch --quiet origin --tags

gh repo clone "$tap" "$staging/tap" -- --quiet
cask="$staging/tap/Casks/btmx-focus.rb"
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$sha256\"/" "$cask"
git -C "$staging/tap" commit --quiet -am "btmx-focus $version"
git -C "$staging/tap" push --quiet

echo "Released $tag: https://github.com/$repo/releases/tag/$tag"
