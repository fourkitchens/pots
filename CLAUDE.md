# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`fourkitchens/pots` ("Push On To Site") is **not an application** — it is a distributable Composer
package (`type: library`, no runtime deps) that ships a **reusable CircleCI pipeline** for deploying
Drupal sites. Downstream Drupal projects `composer require fourkitchens/pots` and copy `config.yml`
into their own `.circleci/config.yml`; the package lands in `vendor/fourkitchens/pots/` and its
`scripts/` are invoked at build time.

Consequences that shape everything here:
- **There is no `.circleci/` directory in this repo, and the pipeline cannot run standalone.** POTS
  only executes inside a consumer's Drupal project. Real end-to-end testing means pointing a test
  project's `.circleci/config.yml` at a POTS branch and opening a PR.
- **Editing `config.yml` is a template change consumers hand-merge.** Per README "Upgrading",
  consumers diff their `.circleci/config.yml` against the vendored one and merge by hand. Communicate
  config changes as diffs; don't assume an edit auto-propagates.

## Commands

The only tooling that runs against *this* repo is the CircleCI CLI (config is `config.yml` at the
repo root, not under `.circleci/`):

```bash
circleci config validate config.yml    # lint; resolves orbs (needs network)
circleci config process config.yml     # fully compile with default params + orb resolution
# Test a job's rendering under non-default params:
printf 'run-sec-updates-check: true\n' > /tmp/params.yml
circleci config process config.yml --pipeline-parameters /tmp/params.yml
```

There is no build step, no unit-test suite, and no linter for the package itself. The scripts under
`scripts/build/*` and `scripts/test/static` (composer/npm/phpcs/phpstan/eslint) run in the **consumer's**
Drupal project, not here — don't try to run them locally against POTS.

## Architecture

**The override/fallback pattern (most important convention).** Nearly every script invocation in
`config.yml` prefers a consumer override, then falls back to the vendored copy:
```
if [ -f "./.circleci/scripts/<name>" ]; then ./.circleci/scripts/<name>
else ./vendor/fourkitchens/pots/scripts/<name>; fi
```
This is how downstream projects customize behavior — by dropping files into their `.circleci/scripts/`.
Preserve this pattern for any new script hook; scripts assume they run from the consumer **project root**.

**`host-variant` selects the workflow** (`config.yml` `parameters` + `workflows`):
- `pantheon` — the main path: `static_tests` → `build` → `deploy_to_pantheon` (dev/multidev) →
  optional Playwright E2E/VRT → **manual-approval-gated** `deploy_to_pantheon_to_test` →
  `deploy_to_pantheon_to_live` → `release`. This gitflow promotion + approval gates is POTS-specific.
- `acquia` / `general` — minimal build → deploy via `scripts/{acquia,general}/deploy`.

**`config.yml` is organized as:** pipeline `parameters` → YAML anchors (`&env` documents every
supported env var, `&defaults`, `&persisting_dirs`, node-install anchors) → `executors` → `jobs` →
`workflows` → `orbs` → `commands`. Reusable logic lives in `commands:` (e.g. `install-terminus`,
`deploy-to-pantheon-env`, `setup-project`, and the `playwright-*` commands).

**Two container images are in play; commands must be portable across both:**
- `cimg/php:<php-version>` — build / deploy / security jobs. Runs as non-root `circleci` **with** sudo.
- `mcr.microsoft.com/playwright:*-noble` — E2E/VRT jobs. Runs as **root, no sudo, and no PHP**.
  PHP is installed at runtime (Terminus is a PHP phar) and steps use a sudo-only-if-not-root idiom.
  Watch for this when touching any command shared between the two (e.g. `install-terminus`).

**Pantheon deploy internals:**
- Terminus is installed at runtime by the `install-terminus` command (POTS migrated off the deprecated
  `quay.io/pantheon-public/build-tools-ci` image; `terminus-version` is a pinned pipeline parameter).
  The **Build Tools** and **Secrets** plugins are installed only for the dev/multidev deploy
  (`install-build-tools: true`), because only that path uses `build:*` / `secrets:*` commands.
- `scripts/set-environment` is the brain: it computes the **branch→environment mapping**
  (main/master→`dev`, develop→`github-dev`, PR→`pr-<n>`, else→`ci-<build#>`), derives site URLs, and
  exports everything to `$BASH_ENV` for later steps. It authenticates via `TERMINUS_TOKEN`.
- `scripts/pantheon/deploy` pushes to dev/multidev via the Build Tools plugin
  (`build:env:create`/`build:env:push`); `deploy-to-test`/`deploy-to-live` handle gitflow promotion
  (`env:deploy`, prod DB backup before live); `drush-commands` runs post-deploy `updatedb`/`cr`/
  config import/cache clear; `drush-config-import` handles config_split partial imports.

**Playwright jobs** are sharded and built from reusable commands: `playwright-prepare` (restore,
caches, deps, browsers), `playwright-wake` (Terminus/HTTP env wake), `playwright-run` (parameterized
`test-command` + `report-dir`), `playwright-merge`. E2E vs VRT differ only by those parameters.

## Configuration surface

Behavior is driven by pipeline `parameters` (in `config.yml`) and environment variables (documented in
the `&env` anchor and README). `TERMINUS_TOKEN` (Pantheon machine token) and `GITHUB_TOKEN` are the
mandatory secrets. The README is the authoritative reference for consumer-facing parameters, env vars,
and the overridable script hooks — keep it in sync when changing parameters or script contracts.
