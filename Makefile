runtime  := nodejs10.x
name     := api
build    := $(shell git describe --tags --always)
planfile := .terraform/$(build).zip

image   := brutalismbot/$(name)
iidfile := .docker/$(build)
digest   = $(shell cat $(iidfile))

$(planfile): $(iidfile) | .terraform
	docker run --rm $(digest) cat /var/task/terraform.zip > $@

$(iidfile): | .docker
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
	--tag $(image):$(build) .

.%:
	mkdir -p $@

.PHONY: shell apply clean

shell: $(iidfile) .env
	docker run --rm -it --env-file .env $(digest) /bin/bash

apply: $(iidfile)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest)

clean:
	docker image rm -f $(image) $(shell sed G .docker/*)
	rm -rf .docker .terraform
