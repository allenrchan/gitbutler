# GitButler development recipes

# Run the desktop app in development mode (hot-reload)
dev:
    pnpm dev:desktop

app_name := "GitButler Nightly"
app_bundle := "target/tauri/release/bundle/macos/" + app_name + ".app"

# Build the macOS .app bundle (with devtools), cleaning old bundles first
build-app: _clean-bundles
    pnpm tauri build --features devtools --bundles app --config crates/gitbutler-tauri/tauri.conf.nightly-local.json || test -d "{{app_bundle}}"

# Build the macOS .app bundle (production, no devtools), cleaning old bundles first
build-app-release: _clean-bundles
    pnpm tauri build --bundles app --config crates/gitbutler-tauri/tauri.conf.nightly-local.json || test -d "{{app_bundle}}"

# Install all dependencies (node + rust)
setup:
    corepack enable
    pnpm install
    cargo build

# Install node dependencies only
install:
    pnpm install

# Run all frontend checks (TypeScript + Svelte)
check:
    pnpm check

# Run frontend tests
test:
    pnpm test

# Run rust tests
test-rust *ARGS:
    cargo test {{ ARGS }}

# Run rust tests for a specific crate
test-crate CRATE:
    cargo test -p {{ CRATE }}

# Lint everything
lint:
    pnpm lint

# Format and fix everything
fix:
    pnpm begood

# Check that everything is good (check + lint)
isgood:
    pnpm isgood

# Build the rust backend only
build-rust:
    cargo build

# Build the rust backend for a specific crate
build-crate CRATE:
    cargo build -p {{ CRATE }}

# Run the web app in development mode
dev-web:
    pnpm dev:web

# Run the UI storybook
dev-ui:
    pnpm dev:ui

# Generate TypeScript type definitions from Rust
generate-types:
    pnpm generate-ts-definitions

# Format rust code
rustfmt:
    cargo +nightly fmt -- --config-path rustfmt-nightly.toml

# Open the built .app bundle (with git-credential secrets to avoid keychain prompts)
open-app:
    GITBUTLER_GIT_CREDENTIALS=1 "{{app_bundle}}/Contents/MacOS/gitbutler-tauri" &

# Install the .app bundle to /Applications
install-app:
    @echo "Installing {{app_name}}.app to /Applications..."
    rm -rf "/Applications/{{app_name}}.app"
    cp -R "{{app_bundle}}" /Applications/
    @echo "Done. Launch from Applications or Spotlight."

# Remove old bundle artifacts before rebuilding
_clean-bundles:
    rm -rf target/tauri/release/bundle

# ============================================================================
# Cleanup
# ============================================================================

# Remove old build artifacts (bundles, debug cache, incremental). Keeps release compilation cache.
clean:
    @echo "Removing app bundles..."
    rm -rf target/tauri/release/bundle
    @echo "Removing debug build caches..."
    rm -rf target/debug
    rm -rf target/tauri/debug
    @echo "Removing incremental compilation artifacts..."
    find target -name incremental -type d -maxdepth 3 -exec rm -rf {} + 2>/dev/null; true
    @echo "Done. Freed space:"
    @du -sh target 2>/dev/null || true

# Full clean — remove entire target directory (next build will be from scratch)
clean-all:
    rm -rf target
    @echo "Removed target/. Next build will compile everything from scratch."

# ============================================================================
# Fork management
# ============================================================================

# Sync custom branch onto latest upstream, verify, and push
sync: _sync-rebase _sync-deps _sync-verify _sync-push

# Sync step 1: fetch upstream and rebase
_sync-rebase:
    git fetch upstream
    git rebase upstream/master

# Sync step 2: reinstall deps (lockfile may have changed)
_sync-deps:
    pnpm install

# Sync step 3: verify both backend and frontend build
_sync-verify:
    cargo build -p gitbutler-tauri
    pnpm check

# Sync step 4: force push to fork
_sync-push:
    git push --force-with-lease origin master

# Sync upstream, build .app, install to /Applications, and push
release: _sync-rebase _sync-deps _sync-verify build-app install-app _sync-push

# Show which files our custom patches touch (conflict risk surface)
custom-files:
    git log upstream/master..HEAD --name-only --pretty=format: | sort -u | grep -v '^$'

# Show custom commits on top of upstream
custom-log:
    git log --oneline upstream/master..HEAD
