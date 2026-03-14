# GitButler development recipes

# Run the desktop app in development mode (hot-reload)
dev:
    pnpm dev:desktop

# Build the macOS .app bundle (with devtools)
build-app:
    pnpm tauri build --features devtools

# Build the macOS .app bundle (production, no devtools)
build-app-release:
    pnpm tauri build

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

# Open the built .app bundle
open-app:
    open target/release/bundle/macos/GitButler.app

# ============================================================================
# Fork management
# ============================================================================

# Sync custom branch onto latest upstream master
sync:
    git fetch upstream
    git rebase upstream/master

# Show which files our custom patches touch (conflict risk surface)
custom-files:
    git log upstream/master..HEAD --name-only --pretty=format: | sort -u | grep -v '^$'

# Verify everything builds after a sync
verify: check
    cargo build -p gitbutler-tauri
