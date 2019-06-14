name    := api
runtime := nodejs10.x
build   := $(shell git describe --tags --always)
digest   = $(shell cat .docker/$(build))

.PHONY: all apply clean shell

all: .docker/$(build)

.docker:
	mkdir -p $@

.docker/%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$* \
	--build-arg TF_VAR_slack_client_id \
	--build-arg TF_VAR_slack_client_secret \
	--build-arg TF_VAR_slack_oauth_error_uri \
	--build-arg TF_VAR_slack_oauth_redirect_uri \
	--build-arg TF_VAR_slack_oauth_success_uri \
	--build-arg TF_VAR_slack_signing_secret \
	--build-arg TF_VAR_slack_signing_version \
	--build-arg TF_VAR_slack_token \
	--iidfile $@ \
	--tag brutalismbot/$(name):$* .

apply: .docker/$(build)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest)

clean:
	-docker image rm -f $(shell sed G .docker/*)
	-rm -rf .docker

shell: .docker/$(build) .env
	docker run --rm -it --env-file .env $(digest) /bin/bash
