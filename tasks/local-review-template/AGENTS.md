## Local Review Default

If the user asks for a local live test in this repo, the default command is:

```sh
OPEN_SAFARI=1 ./tasks/local-live-test.sh
```

Interpretation:

- assume the current branch is the feature branch to review
- switch to `env/local-dev` only for the review workflow
- rebuild the matching local `test/...` branch from `env/local-dev`
- launch Safari with the saved query-string workflow
- switch back after the review command exits

If the current branch is `main`, `env/local-dev`, or `test/...`, pass the feature branch explicitly:

```sh
OPEN_SAFARI=1 ./tasks/local-live-test.sh feature/my-change
```

Image rule:

- if there is no working local image host, pass `IMAGE_BASE_URL='https://cdn.jsdelivr.net/gh/PokeMiners/pogo_assets/Images/Pokemon%20-%20256x256/Addressable%20Assets'`

Cleanup rule:

- when the user is done reviewing, stop any local review servers that were started
