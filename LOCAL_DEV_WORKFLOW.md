# Local Dev Workflow

This repo uses a split workflow so local testing support does not leak into pull requests.

## Branch roles

- `main`
  Should always match `upstream/main`.
- `env/local-dev`
  Shared dev-support branch for local testing. Push this to your fork if you want the same helpers on multiple workstations.
  This is the branch where fork-only helpers such as `tasks/shiny-checklist.query.txt` belong.
- `feature/...`
  The real change you want to propose upstream. These branches should start from `upstream/main`.
- `test/...`
  Disposable local validation branches. These start from `env/local-dev` and then cherry-pick the feature commits on top.
  They intentionally inherit whatever is on `env/local-dev`, because they are only for local review.

## Why this exists

Some local testing needs extra support that should not go into an upstream PR:

- local image hosting
- local-only URL overrides
- helper scripts for reviewing branches

If that support lives directly on a PR branch, it is easy to accidentally include it in the PR. Keeping it on `env/local-dev` avoids that.

## Local config

Machine-specific values belong in `.env.local`, not in tracked files.

Start from:

```sh
cp .env.local.example .env.local
```

Current example:

```dotenv
VITE_PM_IMAGE_BASE_URL=http://127.0.0.1:1111/new-imgs
VITE_PM_SOURCE_URL=https://opensheet.elk.sh/1l1CXHdge8_2F2ifjMY71f23DJ_98Ei2QNZ9rPdBd8jQ/pm
VITE_PM_SOURCE_TYPE=json
```

`.env.local` is ignored by Git, so you can keep different values on each workstation.

These values are used as local-only defaults:

- `VITE_PM_IMAGE_BASE_URL`
  Local image host override for dev/review runs.
- `VITE_PM_SOURCE_URL`
  Default custom data source for local review.
- `VITE_PM_SOURCE_TYPE`
  `json` or `csv` for the custom data source.

## What must be true for local review to work

- `env/local-dev` must stay current.
  It contains the shared local-review support. In particular, the local baseline includes the fix that derives visible groups in JS instead of relying on `.pm-group:has(...)`, because local builds can drop those selectors and leave you with a blank-looking page or no visible squircles.
- `.env.local` should exist before you run the review helper if you depend on the PM sheet or a local image host.
- If you want the local-dev support, review `test/...`, not the raw `feature/...` or PR branch.
  The raw feature branch is the upstream proposal. The `test/...` branch is the local-review version.

## Normal workflow

### 1. Sync `main`

```sh
git fetch upstream origin
git switch main
git reset --hard upstream/main
git push --force-with-lease origin main
```

### 2. Maintain `env/local-dev`

Create it once:

```sh
git switch -c env/local-dev upstream/main
```

Update it later:

```sh
git switch env/local-dev
git rebase upstream/main
git push --force-with-lease origin env/local-dev
```

Only put shared local-testing support here:

- helper scripts
- local review commands
- env-driven dev overrides
- docs for the local workflow

Do not put actual feature work here.

### 3. Start a feature branch

```sh
git switch -c feature/my-change upstream/main
```

Make the real code changes there and commit them normally.

### 4. Build a local test branch

This copies the feature commits onto `env/local-dev`.

```sh
make prepare-test BRANCH=feature/my-change
```

That creates a branch like `test/my-change`.

If the feature branch changes later, rebuild the test branch:

```sh
RESET=1 make prepare-test BRANCH=feature/my-change
```

If `env/local-dev` changes later, rebuild the test branch too.
Do not keep testing an old `test/...` branch after changing the dev baseline.

### 5. Run the review environment

```sh
make review-pr BRANCH=test/my-change
```

If you also need the local image server:

```sh
IMAGE_DIR=./tasks/tmp make review-pr BRANCH=test/my-change
```

The review helper:

- creates a temp worktree for the branch you want to inspect
- reuses the repo `node_modules`
- reuses your root `.env.local` by symlinking it into the temp worktree
- builds the branch before serving it
- can point the app at a local image host
- opens the correct local path for this repo: `/pokemongo-shiny/`
- writes a Safari launcher script in `tasks/tmp` that opens Safari to the exact local `127.0.0.1` page
- when run interactively, can ask whether the Safari query should be refreshed from:
  - a pasted TinyURL or full URL, or
  - cell `B2` of the checklist sheet export
- keeps the local review server running until you stop it

On the first load for a branch, use the printed URL with `?reset=1`.
That clears stale browser config in localStorage before applying your `.env.local` defaults again.

If you want Safari specifically instead of the default browser, use the printed `Safari launcher` path from the review helper.
When `tasks/shiny-checklist.query.txt` exists, the Safari launcher uses that saved query string instead of the clean-start `?reset=1` URL.
If you answer `u` to the prompt, paste the TinyURL and the helper will resolve it, extract the query string, save it back to `tasks/shiny-checklist.query.txt`, and use it for Safari.
If you answer `b` or `b2`, the helper downloads the checklist sheet export, reads the hyperlink target from cell `B2`, resolves that URL, and saves the extracted query string for Safari.

### 6. Open the PR from the feature branch

Open PRs from `feature/...`, never from `env/local-dev` or `test/...`.

## Troubleshooting

### Blank page or "no squircles"

This is almost always a local review setup issue, not a reason to panic about the feature branch.

Check these in order:

1. Rebuild the local test branch from the current dev baseline and current feature branch:

```sh
RESET=1 make prepare-test BRANCH=feature/my-change
```

2. Start a fresh review server, preferably on a fresh port so you are not looking at an older stale run:

```sh
APP_MODE=preview APP_PORT=4177 make review-pr BRANCH=test/my-change
```

3. Open the exact review URL with `?reset=1` on the first load:

```text
http://127.0.0.1:4177/pokemongo-shiny/?reset=1
```

4. Make sure you are testing the `test/...` branch if you need `env/local-dev` support.

Symptoms this usually fixes:

- app shell loads but no groups are visible
- data appears missing even though the PM sheet is valid
- local page works on one branch but a stale local test run looks blank on another

### Wrong data source

If the page loads but is using the wrong spreadsheet or old local settings:

- make sure `.env.local` exists
- make sure it sets `VITE_PM_SOURCE_URL` and `VITE_PM_SOURCE_TYPE`
- load the page once with `?reset=1`

### Wrong images

If the page loads but images are wrong:

- set `VITE_PM_IMAGE_BASE_URL` in `.env.local`, or
- run review with `IMAGE_DIR=...`

Example:

```sh
IMAGE_DIR=./tasks/tmp make review-pr BRANCH=test/my-change
```

### VS Code clutter in `tasks/tmp`

`tasks/tmp` is intentionally ignored by Git and is only for throwaway logs, screenshots, and review artifacts.
On `env/local-dev`, `.vscode/settings.json` enables `explorer.excludeGitIgnore`, so those ignored files should stay hidden in Explorer after a reload.

## Files in this workflow

- `.env.local.example`
  Starter local env config.
- `tasks/shiny-checklist.query.txt`
  Optional fork-only helper file. Keep this on `env/local-dev`, not on upstream PR branches.
- `tasks/prepare-test-branch.sh`
  Creates a `test/...` branch from `env/local-dev` and cherry-picks feature commits.
- `tasks/review-pr.sh`
  Runs a local review server for a branch in a temp worktree.
- `make prepare-test`
  Shortcut for building a test branch.
- `make review-pr`
  Shortcut for running the review environment.

## Quick reference

```sh
# create feature branch
git switch -c feature/my-change upstream/main

# after committing feature work, create local test branch
make prepare-test BRANCH=feature/my-change

# run local review
APP_MODE=preview APP_PORT=4177 IMAGE_DIR=./tasks/tmp make review-pr BRANCH=test/my-change

# open PR from feature/my-change
```
