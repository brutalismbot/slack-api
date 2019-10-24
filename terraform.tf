terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/api.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"
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
  version                  = "~> 2.0"
  kms_key_alias            = "alias/brutalismbot"
  secret_name              = "brutalismbot"
  slack_client_id          = var.slack_client_id
  slack_client_secret      = var.slack_client_secret
  slack_oauth_error_uri    = var.slack_oauth_error_uri
  slack_oauth_redirect_uri = var.slack_oauth_redirect_uri
  slack_oauth_success_uri  = var.slack_oauth_success_uri
  slack_signing_secret     = var.slack_signing_secret
  slack_signing_version    = var.slack_signing_version
  slack_token              = var.slack_token
  kms_key_tags             = local.tags
  secret_tags              = local.tags
}

module slackbot {
  source          = "amancevice/slackbot/aws"
  version         = "~> 15.0"
  api_description = "Brutalismbot REST API"
  app_name        = "brutalismbot"
  base_url        = "/slack"
  secret_name     = "brutalismbot"
  topic_name      = "brutalismbot-api"
  kms_key_id      = data.aws_kms_key.key.key_id
  api_stage_tags  = local.tags
  lambda_tags     = local.tags
  log_group_tags  = local.tags
  role_tags       = local.tags
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

variable release {
  description = "Release tag."
}

variable repo {
  description = "Project repository."
  default     = "https://github.com/brutalismbot/api"
}

variable slack_client_id {
  description = "Slack Client ID."
}

variable slack_client_secret {
  description = "Slack Client Secret."
}

variable slack_oauth_error_uri {
  description = "Slack OAuth error URI."
  default     = "slack://open"
}

variable slack_oauth_redirect_uri {
  description = "Slack OAuth redirect URI."
  default     = ""
}

variable slack_oauth_success_uri {
  description = "Slack OAuth success URI."
  default     = ""
}

variable slack_signing_secret {
  description = "Slack signing secret."
}

variable slack_signing_version {
  description = "Slack signing version."
  default     = "v0"
}

variable slack_token {
  description = "Slack bot OAuth token."
}
