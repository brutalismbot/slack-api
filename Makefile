name    := api
runtime := nodejs10.x
stages  := build plan
build   := $(shell git describe --tags --always)
digest   = $(shell cat .docker/$(build)$(1))

.PHONY: all apply clean plan $(foreach stage,$(stages),shell@$(stage))

all: .docker/$(build)@build

.docker:
	mkdir -p $@

.docker/$(build)@plan: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(build) \
	--build-arg TF_VAR_slack_client_id \
	--build-arg TF_VAR_slack_client_secret \
	--build-arg TF_VAR_slack_oauth_error_uri \
	--build-arg TF_VAR_slack_oauth_redirect_uri \
	--build-arg TF_VAR_slack_oauth_success_uri \
	--build-arg TF_VAR_slack_signing_secret \
	--build-arg TF_VAR_slack_signing_version \
	--build-arg TF_VAR_slack_token \
	--iidfile $@ \
	--tag brutalismbot/$(name):$(build)-$* \
	--target $* .

apply: plan
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(call digest,@plan)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

plan: all .docker/$(build)@plan

shell@%: .docker/$(build)@% .env
	docker run --rm -it --env-file .env $(call digest,@$*) /bin/bash
