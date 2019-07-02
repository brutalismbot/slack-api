ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=hashicorp/terraform:0.12.3 /bin/terraform /bin/
COPY --from=build /var/task/ .
RUN terraform fmt -check

FROM lambci/lambda:build-${RUNTIME} AS plan
COPY --from=test /bin/terraform /bin/
COPY --from=test /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
ARG TF_VAR_slack_client_id
ARG TF_VAR_slack_client_secret
ARG TF_VAR_slack_oauth_error_uri
ARG TF_VAR_slack_oauth_redirect_uri
ARG TF_VAR_slack_oauth_success_uri
ARG TF_VAR_slack_signing_secret
ARG TF_VAR_slack_signing_version
ARG TF_VAR_slack_token
RUN terraform init
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]
