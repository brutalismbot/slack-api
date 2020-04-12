terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/api.tfstate"
    region = "us-east-1"
  }
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.11"
}

locals {
  slack_client_id          = var.SLACK_CLIENT_ID
  slack_client_secret      = var.SLACK_CLIENT_SECRET
  slack_oauth_error_uri    = var.SLACK_OAUTH_ERROR_URI
  slack_oauth_redirect_uri = var.SLACK_OAUTH_REDIRECT_URI
  slack_oauth_success_uri  = var.SLACK_OAUTH_SUCCESS_URI
  slack_signing_secret     = var.SLACK_SIGNING_SECRET
  slack_signing_version    = var.SLACK_SIGNING_VERSION
  slack_token              = var.SLACK_TOKEN

  tags = {
    App  = "slack-api"
    Name = "brutalismbot"
    Repo = "https://github.com/brutalismbot/slack-api"
  }
}

data aws_acm_certificate cert {
  domain      = "brutalismbot.com"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data aws_route53_zone website {
  name = "brutalismbot.com."
}

module secrets {
  source  = "amancevice/slackbot-secrets/aws"
  version = "~> 3.0"

  kms_key_alias = "alias/brutalismbot"
  secret_name   = "brutalismbot-slack"

  slack_client_id          = local.slack_client_id
  slack_client_secret      = local.slack_client_secret
  slack_oauth_error_uri    = local.slack_oauth_error_uri
  slack_oauth_redirect_uri = local.slack_oauth_redirect_uri
  slack_oauth_success_uri  = local.slack_oauth_success_uri
  slack_signing_secret     = local.slack_signing_secret
  slack_signing_version    = local.slack_signing_version
  slack_token              = local.slack_token
  kms_key_tags             = local.tags
  secret_tags              = local.tags
}

module slackbot {
  source  = "amancevice/slackbot/aws"
  version = "~> 18.0"

  api_description = "Brutalismbot REST API"
  app_name        = "brutalismbot-slack"
  base_url        = "/slack"
  role_name       = "brutalismbot"

  kms_key_arn = module.secrets.kms_key.arn
  secret_name = module.secrets.secret.name

  api_stage_tags = local.tags
  lambda_tags    = local.tags
  log_group_tags = local.tags
  role_tags      = local.tags
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = module.slackbot.api.id
  base_path   = "slack"
  domain_name = aws_api_gateway_domain_name.api.domain_name
  stage_name  = module.slackbot.api_deployment.stage_name
}

resource aws_api_gateway_domain_name api {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = "api.brutalismbot.com"
  security_policy = "TLS_1_2"
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

variable SLACK_CLIENT_ID {
  description = "Slack Client ID"
}

variable SLACK_CLIENT_SECRET {
  description = "Slack Client Secret"
}

variable SLACK_OAUTH_ERROR_URI {
  description = "Slack OAuth error URI"
  default     = "slack://open"
}

variable SLACK_OAUTH_REDIRECT_URI {
  description = "Slack OAuth redirect URI"
  default     = null
}

variable SLACK_OAUTH_SUCCESS_URI {
  description = "Slack OAuth success URI"
  default     = null
}

variable SLACK_SIGNING_SECRET {
  description = "Slack signing secret"
}

variable SLACK_SIGNING_VERSION {
  description = "Slack signing version"
  default     = "v0"
}

variable SLACK_TOKEN {
  description = "Slack bot OAuth token"
}
