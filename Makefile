# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

ifneq (,$(wildcard .git))
git = git
else
# we are in docker, without the .git directory
git = sh -c 'false'
endif

PWD ?= $(shell pwd)
SUDO_UID ?= $(shell id -u)
SUDO_GID ?= $(shell id -g)

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

export DOCKER_REGISTRY ?= local
export SHARELATEX_DOCKER_REPOS ?= $(DOCKER_REGISTRY)/sharelatex

export IMAGE_NODE ?= $(DOCKER_REGISTRY)/node:12.16.3
export IMAGE_PROJECT ?= $(SHARELATEX_DOCKER_REPOS)/$(PROJECT_NAME)
export IMAGE_BRANCH ?= $(IMAGE_PROJECT):$(BRANCH_NAME)
export IMAGE ?= $(IMAGE_BRANCH)-$(BUILD_NUMBER)

export IMAGE_BRANCH_DEV ?= $(IMAGE_PROJECT):dev
export IMAGE_CACHE_COLD ?= $(IMAGE_BRANCH_DEV)
export IMAGE_CACHE_HOT ?= $(IMAGE_BRANCH)

SUFFIX ?=
export IMAGE_CI ?= ci/$(PROJECT_NAME):$(BRANCH_NAME)-$(BUILD_NUMBER)$(SUFFIX)

clean_ci: clean
clean_ci: clean_build

clean_build: clean_docker_images
clean_docker_images:
	docker rmi \
		$(IMAGE_CI)-base \
		$(IMAGE_CI)-dev-deps \
		$(IMAGE_CI)-dev \
		$(IMAGE_CI)-prod \
		$(IMAGE_CI)-dev-deps-cache \
		$(IMAGE_CI)-prod-cache \
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
test_unit: test_unit_app
test_unit_app:
	$(UNIT_TEST_DOCKER_COMPOSE) run --rm test_unit

clean_ci: clean_test_unit
clean_test_unit: clean_test_unit_app
clean_test_unit_app:
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

build_dev_deps: clean_build_artifacts
	docker build \
		--cache-from $(IMAGE_CI)-dev-deps-cache \
		--tag $(IMAGE_CI)-base \
		--target base \
		.

	docker build \
		--cache-from $(IMAGE_CI)-base \
		--cache-from $(IMAGE_CI)-dev-deps-cache \
		--tag $(IMAGE_CI)-dev-deps \
		--target dev-deps \
		.

build_dev: clean_build_artifacts
	docker build \
		--cache-from $(IMAGE_CI)-dev-deps \
		--tag $(IMAGE_CI)-dev \
		--target dev \
		.

build_prod: clean_build_artifacts
	docker build \
		--cache-from $(IMAGE_CI)-dev \
		--tag $(IMAGE_CI)-base \
		--target base \
		.

	docker run \
		--rm \
		--entrypoint tar \
		$(IMAGE_CI)-dev \
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
		--build-arg BASE=$(IMAGE_CI)-base \
		--cache-from $(IMAGE_CI)-base \
		--cache-from $(IMAGE_CI)-prod-cache \
		--tag $(IMAGE_CI)-prod \
		--file=Dockerfile.production \
		.

clean_build: clean_build_artifacts
clean_build_artifacts:
	rm -f build_artifacts.tar.gz

clean_ci: clean_output
clean_output:
ifneq (,$(wildcard output/* output/.*))
	docker run --rm \
		--volume $(PWD)/output:/home/node \
		--user node \
		--network none \
		$(IMAGE_NODE) \
		sh -c 'find /home/node -mindepth 1 | xargs rm -rfv'
	rm -rfv output
endif

pull_node:
	docker pull $(IMAGE_NODE)
	docker tag $(IMAGE_NODE) node:12.16.3

pull_cache_cold:
	docker pull $(IMAGE_CACHE_COLD)$(R_TARGET)
	docker tag $(IMAGE_CACHE_COLD)$(R_TARGET) $(IMAGE_CI)$(TARGET)-cache

pull_cache_hot:
	docker pull $(IMAGE_CACHE_HOT)$(R_TARGET)
	docker tag $(IMAGE_CACHE_HOT)$(R_TARGET) $(IMAGE_CI)$(TARGET)-cache

pull_cache:
	make pull_cache_hot || make pull_cache_cold || echo 'cache miss'

clean_pull_cache:
	docker rmi --force \
		$(IMAGE_CACHE_COLD)$(R_TARGET) \
		$(IMAGE_CACHE_HOT)$(R_TARGET) \

push_cache_hot:
	docker tag $(IMAGE_CI)$(TARGET) $(IMAGE_CACHE_HOT)$(R_TARGET)
	docker push $(IMAGE_CACHE_HOT)$(R_TARGET)

push_target:
	docker tag $(IMAGE_CI)$(TARGET) $(IMAGE)$(R_TARGET)
	docker push $(IMAGE)$(R_TARGET)

clean_push:
	docker rmi --force \
		$(IMAGE)$(R_TARGET) \
		$(IMAGE_CACHE_HOT)$(R_TARGET) \

prepare_ci_stage: build_dev_with_cache
build_dev_with_cache: pull_node
build_dev_with_cache:
	docker pull $(IMAGE)-dev-deps
	docker tag $(IMAGE)-dev-deps $(IMAGE_CI)-dev-deps
	$(MAKE) --no-print-directory build_dev

prepare_ci_stage: create_output
create_output:
	mkdir --parents --mode=777 output

clean_ci_stage: clean_output
clean_ci_stage: clean_stage_images
clean_stage_images:
	docker rmi --force \
		$(IMAGE)-dev-deps \
		$(IMAGE_CI)-dev-deps \
		$(IMAGE_CI)-dev \

compress_public: public.tar.xz
.PHONY: public.tar.xz
public.tar.xz:
	docker run \
		--rm \
		--volume $(PWD)/compress.sh:/compress.sh \
		--workdir /app/public \
		--entrypoint sh \
		$(IMAGE_CI)-webpack \
		-c '/compress.sh && tar --create .' \
	| xz -9e \
	> public.tar.xz

.PHONY: clean test test_unit test_acceptance test_clean build
