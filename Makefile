SHELL :=/bin/bash -e -o pipefail
PWD   :=$(shell pwd)

.DEFAULT_GOAL := all
.PHONY: all
all: ## build pipeline
all: format check test

.PHONY: ci
ci: ## CI build pipeline
ci: all

.PHONY: precommit
precommit: ## validate the branch before commit
precommit: all

.PHONY: help
help:
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: format
format: ## Format the code
	@dart format -l 80 --fix lib/ test/
	@dart fix --apply .

.PHONY: get
get: ## Get the dependencies
	@flutter pub get

.PHONY: outdated
outdated: get ## Check for outdated dependencies
	@flutter pub outdated --show-all --dev-dependencies --dependency-overrides --transitive --no-prereleases

.PHONY: test
test: get ## Run the tests
	@flutter test --concurrency=40 test/unit_test.dart test/widget_test.dart

.PHONY: publish-check
publish-check: ## Check the package before publishing
	@flutter pub publish --dry-run

.PHONY: deploy-check
deploy-check: publish-check

.PHONY: publish
publish: ## Publish the package
	@yes | flutter pub publish

.PHONY: deploy
deploy: publish

.PHONY: coverage
coverage: get ## Generate the coverage report
	@flutter test --coverage --concurrency=40 test/unit_test.dart test/widget_test.dart
#	@lcov --remove coverage/lcov.info 'lib/**/*.g.dart' -o coverage/lcov.info
	@lcov --list coverage/lcov.info
	@genhtml -o coverage coverage/lcov.info

.PHONY: analyze
analyze: get ## Analyze the code
	@dart format --set-exit-if-changed -l 80 -o none lib/ test/
	@flutter analyze --fatal-infos --fatal-warnings lib/ test/

.PHONY: check
check: analyze publish-check ## Check the code
	@dart pub global activate pana
	@pana --json --no-warning --line-length 80 > log.pana.json

.PHONY: pana
pana: check

#.PHONY: generate
#generate: get ## Generate the code
#	@dart pub global activate protoc_plugin
#	@protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
#	@dart run build_runner build --delete-conflicting-outputs
#	@dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/protobuf/ test/

#.PHONY: gen
#gen: generate

#.PHONY: codegen
#codegen: generate

.PHONY: version
version: ## Show the Flutter version
	@flutter --version
	@which flutter

.PHONY: diff
diff: ## git diff
	$(call print-target)
	@git diff --exit-code
	@RES=$$(git status --porcelain) ; if [ -n "$$RES" ]; then echo $$RES && exit 1 ; fi
