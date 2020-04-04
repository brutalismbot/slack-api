REPO      := brutalismbot/slack-api
BUILD     := $(shell git describe --tags --always)
TIMESTAMP := $(shell date +%s)

.PHONY: default apply clean clobber plan

default: plan

.docker:
	mkdir -p $@

.docker/plan: Dockerfile terraform.tf
.docker/%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg TF_VAR_RELEASE=$(BUILD) \
	--build-arg TF_VAR_SLACK_CLIENT_ID \
	--build-arg TF_VAR_SLACK_CLIENT_SECRET \
	--build-arg TF_VAR_SLACK_OAUTH_ERROR_URI \
	--build-arg TF_VAR_SLACK_OAUTH_REDIRECT_URI \
	--build-arg TF_VAR_SLACK_OAUTH_SUCCESS_URI \
	--build-arg TF_VAR_SLACK_SIGNING_SECRET \
	--build-arg TF_VAR_SLACK_SIGNING_VERSION \
	--build-arg TF_VAR_SLACK_TOKEN \
	--iidfile $@ \
	--tag $(REPO):$* \
	--tag $(REPO):$*-$(TIMESTAMP) \
	--target $* \
	.

apply: .docker/plan
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$$(cat $<)

clean:
	rm -rf .docker

clobber: clean
	docker image ls $(REPO) --quiet | uniq | xargs docker image rm --force

plan: %: .docker/%
