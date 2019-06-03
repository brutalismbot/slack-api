# Project
name      := api
release   := $(shell git describe --tags --always)
build     := $(name)-$(release)
buildfile := $(build).build
planfile  := $(build).tfplan

# Docker Build
image := brutalismbot/$(name)
digest = $(shell cat $(buildfile))

$(planfile): | $(buildfile)
	docker run --rm $(digest) cat /var/task/$@ > $@

$(buildfile):
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg PLANFILE=$(planfile) \
	--build-arg TF_VAR_release=$(release) \
	--build-arg TF_VAR_slack_client_id \
	--build-arg TF_VAR_slack_client_secret \
	--build-arg TF_VAR_slack_oauth_error_uri \
	--build-arg TF_VAR_slack_oauth_redirect_uri \
	--build-arg TF_VAR_slack_oauth_success_uri \
	--build-arg TF_VAR_slack_signing_secret \
	--build-arg TF_VAR_slack_signing_version \
	--build-arg TF_VAR_slack_token \
	--iidfile $@ \
	--tag $(image):$(release) .

.PHONY: shell apply clean

shell: $(buildfile)
	docker run --rm -it --env-file .env $(digest) /bin/bash

apply: $(buildfile)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	--build-arg TF_VAR_slack_client_id \
	--build-arg TF_VAR_slack_client_secret \
	--build-arg TF_VAR_slack_oauth_error_uri \
	--build-arg TF_VAR_slack_oauth_redirect_uri \
	--build-arg TF_VAR_slack_oauth_success_uri \
	--build-arg TF_VAR_slack_signing_secret \
	--build-arg TF_VAR_slack_signing_version \
	--build-arg TF_VAR_slack_token \
	$(digest) \
	terraform apply $(planfile)

clean:
	docker image rm -f $(image) $(shell sed G *.build)
	rm -rf *.build *.tfplan
