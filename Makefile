terraform := latest
build     := $(shell git describe --tags --always)

.PHONY: all apply clean plan shell

all: plan

.docker:
	mkdir -p $@

.docker/$(build): | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg TERRAFORM=$(terraform) \
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
	--tag brutalismbot/api:$(build) .

apply: .docker/$(build)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(shell cat $<)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

plan: .docker/$(build)

shell: .docker/$(build) .env
	docker run --rm -it \
	--env-file .env \
	$(shell cat $<) \
	/bin/sh
