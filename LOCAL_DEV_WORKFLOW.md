# Local Dev Workflow

This repo uses a split workflow so local testing support does not leak into pull requests.

## Branch roles

- `main`
  Should always match `upstream/main`.
- `env/local-dev`
  Shared dev-support branch for local testing. Push this to your fork if you want the same helpers on multiple workstations.
- `feature/...`
  The real change you want to propose upstream. These branches should start from `upstream/main`.
- `test/...`
  Disposable local validation branches. These start from `env/local-dev` and then cherry-pick the feature commits on top.

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
```

`.env.local` is ignored by Git, so you can keep different values on each workstation.

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
- builds the branch before serving it
- can point the app at a local image host
- keeps the local review server running until you stop it

### 6. Open the PR from the feature branch

Open PRs from `feature/...`, never from `env/local-dev` or `test/...`.

## Files in this workflow

- `.env.local.example`
  Starter local env config.
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
IMAGE_DIR=./tasks/tmp make review-pr BRANCH=test/my-change

# open PR from feature/my-change
```
