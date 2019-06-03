terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/api.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"
}

provider archive {
  version = "~> 1.2"
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.11"
}

locals {
  tags = {
    App     = "api"
    Name    = "brutalismbot"
    Release = var.release
    Repo    = var.repo
  }
}

data aws_acm_certificate cert {
  domain      = "brutalismbot.com"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data aws_kms_key key {
  key_id = "alias/brutalismbot"
}

data aws_route53_zone website {
  name = "brutalismbot.com."
}

module secrets {
  source                   = "amancevice/slackbot-secrets/aws"
  version                  = "2.0.1"
  kms_key_alias            = "alias/brutalismbot"
  kms_key_tags             = local.tags
  secret_name              = "brutalismbot"
  secret_tags              = local.tags
  slack_client_id          = var.slack_client_id
  slack_client_secret      = var.slack_client_secret
  slack_oauth_error_uri    = var.slack_oauth_error_uri
  slack_oauth_redirect_uri = var.slack_oauth_redirect_uri
  slack_oauth_success_uri  = var.slack_oauth_success_uri
  slack_signing_secret     = var.slack_signing_secret
  slack_signing_version    = var.slack_signing_version
  slack_token              = var.slack_token
}

module slackbot {
  source               = "amancevice/slackbot/aws"
  version              = "14.0.0"
  api_description      = "Brutalismbot REST API"
  api_name             = "brutalismbot"
  api_stage_name       = "v1"
  api_stage_tags       = local.tags
  base_url             = "/slack"
  kms_key_id           = data.aws_kms_key.key.key_id
  lambda_function_name = "brutalismbot-api"
  lambda_layer_name    = "brutalismbot"
  lambda_tags          = local.tags
  log_group_tags       = local.tags
  role_name            = "brutalismbot"
  role_tags            = local.tags
  secret_name          = "brutalismbot"
  sns_topic_prefix     = "brutalismbot_"
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = module.slackbot.api_id
  domain_name = aws_api_gateway_domain_name.api.domain_name
  stage_name  = module.slackbot.api_stage_name
  base_path   = "slack"
}

resource aws_api_gateway_domain_name api {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = "api.brutalismbot.com"
}

resource aws_route53_record api {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.website.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}
