init:
	bun install;

dev:
	bun run dev;

host-image:
	bunx http-server ./tasks/tmp -p 1111 -c 86400;

build:
	bun run build;

review-pr:
	./tasks/review-pr.sh "$(BRANCH)";

live-test:
	./tasks/live-test.sh "$(BRANCH)";

install-local-review:
	./tasks/install-local-review.sh;

prepare-test:
	./tasks/prepare-test-branch.sh "$(BRANCH)" "$(TEST_BRANCH)";

deploy: build
	bun run deploy;

fetch: fetch-name fetch-pm
	echo 'All fetched!';

fetch-pm:
	bun ./tasks/fetch-pm.js;

fetch-name:
	bun ./tasks/fetch-name.js;

download-imgs:
	cat ./tasks/tmp/imgs.txt | parallel -j4 wget -q -nc -P ./tasks/tmp/img ' ' {};

print-date:
	date +%FT%T%:::z > './src/assets/data/latest-fetch-time.txt';

pull-csv:
	curl -L "https://docs.google.com/spreadsheets/d/1l1CXHdge8_2F2ifjMY71f23DJ_98Ei2QNZ9rPdBd8jQ/export?format=csv&gid=679582482" -o ./src/assets/data/pm.csv

