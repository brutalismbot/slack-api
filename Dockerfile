ARG TERRAFORM=latest
FROM hashicorp/terraform:${TERRAFORM} AS plan
WORKDIR /var/task/
COPY . .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
ARG TF_VAR_release
ARG TF_VAR_slack_client_id
ARG TF_VAR_slack_client_secret
ARG TF_VAR_slack_oauth_error_uri
ARG TF_VAR_slack_oauth_redirect_uri
ARG TF_VAR_slack_oauth_success_uri
ARG TF_VAR_slack_signing_secret
ARG TF_VAR_slack_signing_version
ARG TF_VAR_slack_token
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
