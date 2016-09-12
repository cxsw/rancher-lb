DOCKER_USER=finboxio
DOCKER_IMAGE=rancher-lb
RANCHER_ENV=local

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_COMMIT := $(shell git rev-parse HEAD)
GIT_REPO := $(shell git remote -v | grep origin | grep "(fetch)" | awk '{ print $$2 }')
GIT_DIRTY := $(shell git status --porcelain | wc -l)
GIT_DIRTY := $(shell if [[ "$(GIT_DIRTY)" -gt "0" ]]; then echo "true"; else echo "false"; fi)

VERSION := $(shell git describe --abbrev=0)
VERSION_DIRTY := $(shell git log --pretty=format:%h $(VERSION)..HEAD | wc -l | tr -d ' ')

BUILD_COMMIT := $(shell if [[ "$(GIT_DIRTY)" == "true" ]]; then echo $(GIT_COMMIT)+dev; else echo $(GIT_COMMIT); fi)
BUILD_COMMIT := $(shell echo $(BUILD_COMMIT) | cut -c1-12)
BUILD_VERSION := $(shell if [[ "$(VERSION_DIRTY)" -gt "0" ]]; then echo "$(VERSION)-$(BUILD_COMMIT)"; else echo $(VERSION); fi)
BUILD_VERSION := $(shell if [[ "$(VERSION_DIRTY)" -gt "0" ]] || [[ "$(GIT_DIRTY)" == "true" ]]; then echo "$(BUILD_VERSION)-dev"; else echo $(BUILD_VERSION); fi)
BUILD_VERSION := $(shell if [[ "$(GIT_BRANCH)" != "master" ]]; then echo $(GIT_BRANCH)-$(BUILD_VERSION); else echo $(BUILD_VERSION); fi)

DOCKER_IMAGE := $(shell if [[ "$(DOCKER_REGISTRY)" ]]; then echo $(DOCKER_REGISTRY)/$(DOCKER_USER)/$(DOCKER_IMAGE); else echo $(DOCKER_USER)/$(DOCKER_IMAGE); fi)
DOCKER_VERSION := $(shell echo "$(DOCKER_IMAGE):$(BUILD_VERSION)")
DOCKER_LATEST := $(shell if [[ "$(VERSION_DIRTY)" -gt "0" ]] || [[ "$(GIT_DIRTY)" == "true" ]]; then echo "$(DOCKER_IMAGE):dev"; else echo $(DOCKER_IMAGE):latest; fi)

RANCHER_URL := $(shell renv $(RANCHER_ENV) | grep RANCHER_URL | cut -d= -f2)
RANCHER_ACCESS_KEY := $(shell renv $(RANCHER_ENV) | grep RANCHER_ACCESS_KEY | cut -d= -f2)
RANCHER_SECRET_KEY := $(shell renv $(RANCHER_ENV) | grep RANCHER_SECRET_KEY | cut -d= -f2)

docker.build:
	@docker build -t $(DOCKER_VERSION) -t $(DOCKER_LATEST) .

docker.push: docker.build
	@docker push $(DOCKER_VERSION)
	@docker push $(DOCKER_LATEST)

info:
	@echo "git branch:      $(GIT_BRANCH)"
	@echo "git commit:      $(GIT_COMMIT)"
	@echo "git repo:        $(GIT_REPO)"
	@echo "git dirty:       $(GIT_DIRTY)"
	@echo "version:         $(VERSION)"
	@echo "commits since:   $(VERSION_DIRTY)"
	@echo "build commit:    $(BUILD_COMMIT)"
	@echo "build version:   $(BUILD_VERSION)"
	@echo "docker images:   $(DOCKER_VERSION)"
	@echo "                 $(DOCKER_LATEST)"

version:
	@echo $(BUILD_VERSION) | tr -d '\r' | tr -d '\n' | tr -d ' '

rancher.deploy: docker.push
	@rancher-compose \
		--url $(RANCHER_URL) \
		--access-key $(RANCHER_ACCESS_KEY) \
		--secret-key $(RANCHER_SECRET_KEY) \
		-p lb \
		-f stack/docker-compose.yml \
		-r stack/rancher-compose.yml \
		up --force-upgrade -d
