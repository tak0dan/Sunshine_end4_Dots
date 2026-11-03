#!/usr/bin/env bash
# Maintainer tool: rebuild patch/dots-hyprland.patch from the live config.
#
# Usage: tools/build-patch.sh [END4_CLONE]
#   END4_CLONE  any clone of end-4/dots-hyprland that has the base commit
#               (default: ~/.cache/dots-hyprland, cloned if missing)
#
# Takes every file listed in patch/files.txt (paths inside end-4's repo,
# dots/.config/...) from ~/.config, puts it on top of the base commit and
# writes the diff. Personal files are replaced by the examples in
# tools/examples/. Then checks that the patch applies to a clean base commit
# and reproduces the live files.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BASE_COMMIT=$(sed -n 's/^BASE_COMMIT=//p' "$here/install.sh")
clone=${1:-$HOME/.cache/dots-hyprland}
config=${XDG_CONFIG_HOME:-$HOME/.config}

[[ -d $clone ]] || git clone -q https://github.com/end-4/dots-hyprland.git "$clone"
git -C "$clone" cat-file -e "$BASE_COMMIT^{commit}" 2>/dev/null || git -C "$clone" fetch -q origin

work=$(mktemp -d)
cleanup() {
    git -C "$clone" worktree remove --force "$work/build" 2>/dev/null || true
    git -C "$clone" worktree remove --force "$work/check" 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT

git -C "$clone" worktree add -q --detach "$work/build" "$BASE_COMMIT"
mapfile -t files < <(grep -v '^\s*\(#\|$\)' "$here/patch/files.txt")
for f in "${files[@]}"; do
    src=$here/tools/examples/${f#dots/.config/}
    [[ -f $src ]] || src=$config/${f#dots/.config/}
    [[ -f $src ]] || { echo "missing: $src" >&2; exit 1; }
    mkdir -p "$(dirname "$work/build/$f")"
    cp -p "$src" "$work/build/$f"
done
git -C "$work/build" add -A
git -C "$work/build" diff --cached --binary > "$work/new.patch"

# check: a clean base commit + the patch == the sources above
git -C "$clone" worktree add -q --detach "$work/check" "$BASE_COMMIT"
git -C "$work/check" apply --whitespace=nowarn "$work/new.patch"
for f in "${files[@]}"; do
    cmp -s "$work/check/$f" "$work/build/$f" || { echo "mismatch: $f" >&2; exit 1; }
done

cp "$work/new.patch" "$here/patch/dots-hyprland.patch"
git -C "$work/build" diff --cached --stat | tail -1
echo "patch/dots-hyprland.patch rebuilt and verified (${#files[@]} files)"
