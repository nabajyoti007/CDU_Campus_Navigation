#!/usr/bin/env bash
# Build the web app and publish it to GitHub Pages (the gh-pages branch).
#
#   bash tool/deploy_web.sh
#
# The site is served at https://nabajyoti007.github.io/CDU_Campus_Navigation/
# The gh-pages branch only holds the built website; the app's code stays on main.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_URL="$(git remote get-url origin)"

# MSYS_NO_PATHCONV: stop Git Bash on Windows turning /CDU_Campus_Navigation/ into a file path
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /CDU_Campus_Navigation/ --no-wasm-dry-run

cd build/web
touch .nojekyll              # serve Flutter's files exactly as built
rm -rf .git
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C ../.. config user.name)" \
    -c user.email="$(git -C ../.. config user.email)" \
    commit -q -m "Deploy web app from $(git -C ../.. rev-parse --short HEAD)"
git push -q --force "$REPO_URL" gh-pages
rm -rf .git
echo "Published. It can take a minute to appear at:"
echo "https://nabajyoti007.github.io/CDU_Campus_Navigation/"
