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

data aws_kms_alias slackbot {
  name = "alias/brutalismbot"
}

data aws_route53_zone website {
  name = "brutalismbot.com."
}

data aws_secretsmanager_secret slackbot {
  name = "brutalismbot-slack"
}

module slackbot {
  source  = "amancevice/slackbot/aws"
  version = "18.2.0"

  api_description = "Brutalismbot REST API"
  app_name        = "brutalismbot-slack"
  base_url        = "/slack"
  role_name       = "brutalismbot"

  kms_key_arn = data.aws_kms_alias.slackbot.target_key_arn
  secret_name = data.aws_secretsmanager_secret.slackbot.name

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
