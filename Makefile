# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

ifneq (,$(wildcard .git))
git = git
else
# we are in docker, without the .git directory
git = sh -c 'false'
endif

BUILD_NUMBER ?= local
BRANCH_NAME ?= $(shell $(git) rev-parse --abbrev-ref HEAD || echo master)
COMMIT ?= $(shell $(git) rev-parse HEAD || echo HEAD)
RELEASE ?= $(shell $(git) describe --tags || echo v0.0.0 | sed 's/-g/+/;s/^v//')
PROJECT_NAME = clsi
BUILD_DIR_NAME = $(shell pwd | xargs basename | tr -cd '[a-zA-Z0-9_.\-]')
DOCKER_COMPOSE_FLAGS ?= -f docker-compose.yml
DOCKER_COMPOSE := BUILD_NUMBER=$(BUILD_NUMBER) \
	BRANCH_NAME=$(BRANCH_NAME) \
	PROJECT_NAME=$(PROJECT_NAME) \
	MOCHA_GREP=${MOCHA_GREP} \
	docker-compose ${DOCKER_COMPOSE_FLAGS}

ifneq (,$(DOCKER_REGISTRY))
IMAGE_NODE ?= $(DOCKER_REGISTRY)/node:12.16.1
else
IMAGE_NODE ?= node:12.16.1
endif

clean_ci: clean
clean_ci: clean_build

clean_build:
	docker rmi \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER) \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-prod \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps-cache \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-prod-cache \
		--force

clean:

	rm -f app.js
	rm -f app.map
	rm -rf app/js
	rm -rf test/acceptance/js
	rm -rf test/load/js
	rm -rf test/smoke/js
	rm -rf test/unit/js

test: lint
lint:
test: format
format:

UNIT_TEST_DOCKER_COMPOSE ?= \
	COMPOSE_PROJECT_NAME=unit_test_$(BUILD_DIR_NAME) $(DOCKER_COMPOSE)

test: test_unit
test_unit:
	$(UNIT_TEST_DOCKER_COMPOSE) run --rm test_unit

clean_ci: clean_test_unit
clean_test_unit:
	$(UNIT_TEST_DOCKER_COMPOSE) down --timeout 0

ACCEPTANCE_TEST_DOCKER_COMPOSE ?= \
	COMPOSE_PROJECT_NAME=acceptance_test_$(BUILD_DIR_NAME) $(DOCKER_COMPOSE)

test: test_acceptance
test_acceptance: test_acceptance_app
test_acceptance_run: test_acceptance_app_run
test_acceptance_app: clean_test_acceptance_app
test_acceptance_app: test_acceptance_app_run

export TEXLIVE_IMAGE ?= quay.io/sharelatex/texlive-full:2017.1

test_acceptance_app: pull_texlive
pull_texlive:
	docker pull $(TEXLIVE_IMAGE)

ifeq (true,$(PULL_TEXLIVE_BEFORE_RUN))
test_acceptance_app_run: pull_texlive
endif

test_acceptance_app_run:
	$(ACCEPTANCE_TEST_DOCKER_COMPOSE) run --rm test_acceptance

test_acceptance_app_run: test_acceptance_pre_run
test_acceptance_pre_run:

clean_ci: clean_test_acceptance
clean_test_acceptance: clean_test_acceptance_app
clean_test_acceptance_app:
	$(ACCEPTANCE_TEST_DOCKER_COMPOSE) down --volumes --timeout 0

clean_test_acceptance: clean_clsi_artifacts
clean_test_acceptance_app: clean_clsi_artifacts
clean_clsi_artifacts:
	docker run --rm \
		--volume $(PWD)/cache:/app/cache:z \
		--volume $(PWD)/compiles:/app/compiles:z \
		--network none \
		$(IMAGE_NODE) \
		sh -c 'rm -rf /app/cache/* app/compiles/*'

COFFEE := npx coffee

build_app: compile_full

compile_full: compile_app
compile_full: compile_tests

COFFEE_DIRS_TESTS := $(wildcard test/*/coffee)
COMPILE_TESTS := $(addprefix compile/,$(COFFEE_DIRS_TESTS))
compile_app: app.js compile/app/coffee
compile_tests: $(COMPILE_TESTS)

compile/app/coffee $(COMPILE_TESTS): compile/%coffee:
	$(COFFEE) --output $*js --compile $*coffee

COFFEE_FILES := $(shell find app/coffee $(COFFEE_DIRS_TESTS) -name '*.coffee')
JS_FILES := app.js $(subst /coffee,/js,$(subst .coffee,.js,$(COFFEE_FILES)))
compile: $(JS_FILES)

app.js: app.coffee
	$(COFFEE) --compile $<

app/js/%.js: app/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/acceptance/js/%.js: test/acceptance/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/load/js/%.js: test/load/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/smoke/js/%.js: test/smoke/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/unit/js/%.js: test/unit/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

build: clean_build_artifacts
	docker build \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps-cache \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		--target base \
		.

	docker build \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps-cache \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps \
		--target dev-deps \
		.

	docker build \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev-deps \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER) \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev \
		--target dev \
		.

build_prod: clean_build_artifacts
	docker build \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		--target base \
		.

	docker run \
		--rm \
		--entrypoint tar \
		ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-dev \
			--create \
			--gzip \
			app.js \
			app/js \
			config \
			seccomp \
			bin/synctex \
			entrypoint.sh \
			test/smoke/js \
		> build_artifacts.tar.gz

	docker build \
		--build-arg RELEASE=$(RELEASE) \
		--build-arg COMMIT=$(COMMIT) \
		--build-arg BASE=ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-base \
		--cache-from ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-prod-cache \
		--tag ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)-prod \
		--file=Dockerfile.production \
		.

clean_ci: clean_build_artifacts
clean_build_artifacts:
	rm -f build_artifacts.tar.gz

clean_ci: clean_output
clean_output:
ifneq (,$(wildcard output/*))
	docker run --rm \
		--volume $(PWD)/output:/home/node \
		--user node \
		--network none \
		$(IMAGE_NODE) \
		sh -c 'find /home/node -mindepth 1 | xargs rm -rfv'
	rm -rfv output
endif

.PHONY: clean test test_unit test_acceptance test_clean build
