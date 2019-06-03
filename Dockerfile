FROM lambci/lambda:build-nodejs8.10

ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SECRET_ACCESS_KEY
ARG PLANFILE=terraform.tfplan
ARG TF_VAR_release

COPY --from=hashicorp/terraform:0.12.0 /bin/terraform /bin/
COPY . .

RUN terraform init
RUN terraform plan -out ${PLANFILE}
