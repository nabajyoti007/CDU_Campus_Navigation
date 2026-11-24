#!/usr/bin/env bash
# Build the web app for Netlify and push it to the 'netlify' branch.
#
#   bash tool/deploy_netlify.sh
#
# Netlify is connected to that branch with no build command (its servers don't
# have Flutter), so every push here is published automatically.
# On Netlify the app is served from the site root, so it is built with base href "/"
# (GitHub Pages uses /CDU_Campus_Navigation/ - see tool/deploy_web.sh).
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_URL="$(git remote get-url origin)"

# MSYS_NO_PATHCONV: stop Git Bash on Windows turning "/" into a file path
MSYS_NO_PATHCONV=1 flutter build web --release --base-href / --no-wasm-dry-run

cd build/web
cat > netlify.toml <<'EOF'
# Prebuilt Flutter web app: nothing to build on Netlify.
[build]
  publish = "."
  command = ""

# Always fetch the newest app code, cache the rest.
[[headers]]
  for = "/index.html"
  [headers.values]
    Cache-Control = "no-cache"
[[headers]]
  for = "/flutter_bootstrap.js"
  [headers.values]
    Cache-Control = "no-cache"
[[headers]]
  for = "/main.dart.js"
  [headers.values]
    Cache-Control = "no-cache"
EOF

rm -rf .git
git init -q -b netlify
git add -A
git -c user.name="$(git -C ../.. config user.name)" \
    -c user.email="$(git -C ../.. config user.email)" \
    commit -q -m "Netlify build from $(git -C ../.. rev-parse --short HEAD)"
git push -q --force "$REPO_URL" netlify
rm -rf .git
echo "Pushed to the 'netlify' branch. Netlify publishes it within a minute."
