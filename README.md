## 1. For user:

If you get in trouble with some bugs,  
try to reset your config setting by url paramerter `reset=1`:  
`https://rplus.github.io/pokemongo-shiny/?reset=1`


## 2. For dev:

1. init & install dependency
  ```
  make init;
  ```

2. just dev~
  ```
  make dev
  ```

3. review a PR branch locally
  ```
  make review-pr BRANCH=tag-hide-and-baby-complement-pr
  ```

  optional: also start a local image host
  ```
  IMAGE_DIR=./tasks/tmp make review-pr BRANCH=tag-hide-and-baby-complement-pr
  ```

  the review script:
  * builds the target branch in a temp `git worktree`
  * reuses the repo `node_modules`
  * reuses your root `.env.local` inside the temp worktree
  * starts the app in `dev` mode by default
  * can pass `VITE_PM_IMAGE_BASE_URL` automatically, so you do not need to tweak image URLs in code
  * can default the app to your spreadsheet through `VITE_PM_SOURCE_URL`
  * can start a second `http-server` for local images when `IMAGE_DIR` is set or `./tasks/tmp/new-imgs` exists
  * prints the exact `Review URL`, `Safari URL`, and `Safari launcher` path
  * writes a Safari launcher script in `tasks/tmp`; when `tasks/shiny-checklist.query.txt` exists, it opens Safari with that saved query string on the local `127.0.0.1` page
  * can prompt you to refresh that saved Safari query either by pasting a TinyURL/full URL or by pulling the hyperlink target from cell `B2` of the checklist sheet
  * leaves the review server running so you can inspect the page and take screenshots manually

  note:
  * run the local-review helpers from `env/local-dev`, not from a clean `main`-based PR branch
  * if a feature branch was accidentally started from `env/local-dev`, rebuild a clean feature branch from `main` before using `make prepare-test`
  * in interactive mode, the helper can generate the Safari URL at runtime from a pasted TinyURL/full URL or from checklist sheet cell `B2`
  * if you skip the refresh prompt, or disable it, the helper falls back to the saved query file and still prints the resulting `Safari URL`

4. keep a shared local dev branch outside your PR branches

  see [`LOCAL_DEV_WORKFLOW.md`](./LOCAL_DEV_WORKFLOW.md) for the full branch model and review workflow

  recommended branch roles:
  * `main`: always matches `upstream/main`
  * `env/local-dev`: reusable local-only dev support that you can push to your fork
  * `feature/...`: the actual PR branch, based on `upstream/main`
  * `test/...`: local validation branch, based on `env/local-dev` plus your feature commits

  create the shared env branch once:
  ```
  git switch -c env/local-dev upstream/main
  ```

  keep machine-specific values in `.env.local`:
  ```
  cp .env.local.example .env.local
  ```

  create a test branch from `env/local-dev` and cherry-pick your feature commits:
  ```
  git switch env/local-dev
  make prepare-test BRANCH=feature/my-change
  ```

  if you want to rebuild the same test branch after updating the feature branch:
  ```
  RESET=1 make prepare-test BRANCH=feature/my-change
  ```

  important:
  * open PRs from `feature/...`
  * do not open PRs from `env/local-dev`
  * do not open PRs from `test/...`
  * if local review ever shows a blank page or no visible squircles, rebuild the `test/...` branch from the current `env/local-dev` and feature branch, then reopen the printed `?reset=1` URL on a fresh port
  * keep fork-only helpers such as `tasks/shiny-checklist.query.txt` on `env/local-dev`, not on upstream PR branches


## 3. For updating shiny list data:

There are many methods for data usage.

### A. (default): use site's csv data

  if you want to update this,
  just create a PR for this project to update the [`pm.csv`](https://github.com/Rplus/pokemongo-shiny/blob/main/src/assets/data/pm.csv)

### B. custom csv data url:

  you can host csv file by yourself, and just enter your csv url into sidebar to apply pm data.

### C. use my google spreadsheet

  just enter my spreadsheet public url into side-panel:  
  <https://opensheet.elk.sh/1l1CXHdge8_2F2ifjMY71f23DJ_98Ei2QNZ9rPdBd8jQ/pm>

  if you want to update my spreadsheet  
  <https://docs.google.com/spreadsheets/d/1l1CXHdge8_2F2ifjMY71f23DJ_98Ei2QNZ9rPdBd8jQ/edit?gid=1540699392>  
  click right-top button to send me a request for getting a edit permission.  
  And then, you could help me to update the data easy, that's really great!

  ※  
  If you are not sure whether you will make a mistake,  
  you can copy the spreadsheet to your own Google spreadsheet.  
  And then change the custom data url to your spreadsheet and just give it a try.

### D. use your google spreadsheet

  you need to get the spreadsheet public url, the easiest method is:  
  `https://opensheet.elk.sh/spreadsheet_id/tab_name`  
  just change the `spreadsheet_id/tab_name` with your google spreadsheet page.  
  And then, you could update spreadsheet by yourself.

PS1:
custom data url:
  1. open custom section in side-panel
  2. input the data url in the latest input
  3. choise right file type (json or csv)
  4. reload to check

PS2:
if you get in a trouble when custom data url, just reset all setting by trigger url: <https://rplus.github.io/pokemongo-shiny/?reset=1>



## Data property

all csv columns/properties:

| property | required? | type | description |
| -------- | -------- | ----- | ----- |
| `index`  | required | number | uni index, **SHOULD NOT CHANGE** after save |
| `debut`  | required | string | released date |
| `pid`    | required | string | uni key, image file name. format: `pm25.cFALL_2018`... |
| `group`  | required | string | grouping key. write for free, but you could use the same prefix to make groups adjacent |
| `order`  | -        | number | group position, will use `index` when no order number~  |
| `tag`    | -        | string | tags for pokemon, combine tags with `=`.<br> e.q. `tag1=tag2=tag3` |
| `suffix` | -        | string | suffix name, write mega or other types.<br>e.q. `(Y)`, `#7` |
| `style`  | -        | string | custom image style,<br>e.q. `--w:140%;--l:-10%;--t:-10%;`
| `src`    | -        | string | image url, custom image source, will overwrite the image of pid <br> could be https://ooxx.png |

more details:
https://github.com/Rplus/pokemongo-shiny/discussions/2

※ If you use custom `src`, and try to create a custom `pid`, just follow basic format rules:

1. starts with `pm` + pokedex-number + `.`
2. suffix name: you could write any name for free, but there are some naming rules for tag system if you need
  * `fMEGA` => mega tag
  * `fALOLA` => alola tag
  * `fORIGIN` => origin tag
  * `fHISUIAN` => hisuian tag
  * `fGALARIAN` => galarian tag
  * you could see all rules from `get_default_tags` function in `/src/lib/pm.svelte.js` file.
