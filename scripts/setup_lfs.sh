#!/usr/bin/env bash
# Verify and configure Git LFS for Exocomplict.
#
# The tracking rules live in .gitattributes and are committed, so a machine
# with git-lfs needs no per-repo setup: this script only checks the tool is
# installed, reports what the rules cover, and -- if asked -- offers the one
# destructive step (rewriting history so *existing* blobs move to LFS too).
#
# Usage:
#   scripts/setup_lfs.sh              # check git-lfs, list what is tracked
#   scripts/setup_lfs.sh --migrate    # ALSO rewrite history (DANGEROUS, prompts)
#
# Why this exists: the repository carries 217 MB of tracked files, 75 MB of it
# build output that CI regenerates and uploads as an artifact every push
# (docs/DECISIONS.md §4). New commits get lighter the moment LFS is in
# place; history only gets lighter if someone runs --migrate, which rewrites
# every commit and therefore needs every collaborator to re-clone.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DO_MIGRATE=0
[[ "${1:-}" == "--migrate" ]] && DO_MIGRATE=1

cd "$ROOT_DIR"

printf 'Git LFS setup — Exocomplict\n\n'

# --- 1. is the tool there ---------------------------------------------------
if ! command -v git-lfs >/dev/null 2>&1 && ! git lfs version >/dev/null 2>&1; then
  printf '  [FAIL] git-lfs is not installed.\n\n'
  printf '  Install it, then re-run this script:\n'
  printf '    Debian/Ubuntu : sudo apt-get install -y git-lfs\n'
  printf '    Fedora        : sudo dnf install -y git-lfs\n'
  printf '    macOS (brew)  : brew install git-lfs\n'
  printf '    Windows       : winget install GitHub.GitLFS  (or the installer)\n\n'
  printf '  After installing:  git lfs install\n'
  printf '  Note: .gitattributes is already committed, so nothing is broken in the\n'
  printf '  meantime — files simply stay in the object database until someone with\n'
  printf '  git-lfs commits them.\n'
  exit 1
fi
printf '  [ OK ] git-lfs: %s\n' "$(git lfs version | head -1)"

# --- 2. is the filter hooked up -------------------------------------------
if ! git lfs install --local >/dev/null 2>&1; then
  printf '  [FAIL] "git lfs install" failed; the clean/smudge filters are not active.\n'
  exit 1
fi
printf '  [ OK ] filters installed for this repository\n'

# --- 3. what the rules cover ----------------------------------------------
printf '\n  Tracked patterns (.gitattributes):\n'
grep -E '^[a-zA-Z*]' .gitattributes | grep -v '^#' | sed 's/^/    /'

matched=0
bytes=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  size=$(wc -c < "$file")
  matched=$((matched + 1))
  bytes=$((bytes + size))
done < <(git ls-files | git check-attr --stdin filter | awk -F': ' '$3 == "lfs" {print $1}')
printf '\n  %d file(s) match the LFS rules, %.1f MB total.\n' "$matched" "$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1000000}')"

# --- 4. the destructive part ----------------------------------------------
if (( DO_MIGRATE == 0 )); then
  printf '\n  History was NOT rewritten (default). Existing blobs stay in .git.\n'
  printf '  New commits of the matched files go through LFS from here on.\n'
  printf '  To shrink history as well: scripts/setup_lfs.sh --migrate\n'
  exit 0
fi

printf '\n  --migrate was requested.\n'
printf '  This rewrites every commit in every branch. Every collaborator must\n'
printf '  re-clone afterwards, and any open work based on the old history must\n'
printf '  be rebased. Push will need --force-with-lease.\n\n'
read -r -p '  Type "rewrite" to continue: ' answer
if [[ "$answer" != "rewrite" ]]; then
  printf '  Aborted; nothing changed.\n'
  exit 0
fi

# web/index.pck and web/index.wasm are NOT migrated on purpose. They are what
# the browser loads, and a plain `git clone` without git-lfs checks out 133-byte
# pointers instead, which killed the preview with "expected magic word 00 61 73
# 6d". See the comment in .gitattributes.
patterns=(
  --include="*.zip"
  --include="source-assets/**/*.glb"
  --include="source-assets/**/*.blend"
  --include="docs/asset-inspections/**/*.png"
  --include="docs/asset-inspections/**/*.jpg"
  --include="docs/ui-redesign/**/*.png"
  --include="qa-evidence/**/*.png"
  --include="qa-evidence/**/*.jpg"
)

printf '\n  Rewriting (this takes a while)...\n'
if git lfs migrate import "${patterns[@]}"; then
  printf '\n  Done. Verify with: du -sh .git && git lfs ls-files\n'
  printf '  Then: git push --force-with-lease origin <branch>\n'
else
  printf '\n  [FAIL] git lfs migrate failed; the repository is unchanged (it works on a copy).\n'
  exit 1
fi
