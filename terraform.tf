terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/api.tfstate"
    region = "us-east-1"
  }

  required_version = "~> 0.13"
}

provider aws {
  region  = "us-east-1"
  version = "~> 3.1"
}

locals {
  tags = {
    Name = "slack.brutalismbot.com"
    Repo = "https://github.com/brutalismbot/slack-api"
  }
}

# HTTP API :: CORE

resource aws_apigatewayv2_api http_api {
  description   = "Brutalismbot slack API"
  name          = "brutalismbot/slack"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource aws_apigatewayv2_stage default {
  api_id      = aws_apigatewayv2_api.http_api.id
  auto_deploy = true
  description = "Brutalismbot HTTP API"
  name        = "$default"
  tags        = local.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_logs.arn

    format = jsonencode({
      httpMethod     = "$context.httpMethod"
      ip             = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      responseLength = "$context.responseLength"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
    })
  }

  lifecycle {
    ignore_changes = [deployment_id]
  }
}

resource aws_cloudwatch_log_group http_api_logs {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 30
  tags              = local.tags
}

# HTTP API :: MAPPING /slack

resource aws_apigatewayv2_api_mapping slack {
  api_mapping_key = "slack"
  api_id          = aws_apigatewayv2_api.http_api.id
  domain_name     = "api.brutalismbot.com"
  stage           = aws_apigatewayv2_stage.default.id
}

# SLACKBOT V2

module slackbot_v2 {
  source  = "amancevice/slackbot/aws"
  version = "19.4.0"

  base_path                   = "/"
  role_name                   = "brutalismbot-slack-lambda"
  topic_name                  = "brutalismbot-slack"
  lambda_function_name        = "brutalismbot-slack-http-api"
  log_group_retention_in_days = 30

  http_api_id            = aws_apigatewayv2_api.http_api.id
  http_api_execution_arn = aws_apigatewayv2_api.http_api.execution_arn

  lambda_kms_key_arn = data.aws_kms_alias.slackbot.target_key_arn
  secret_name        = data.aws_secretsmanager_secret.slackbot.name

  lambda_tags    = local.tags
  log_group_tags = local.tags
  role_tags      = local.tags
}

# SLACKBOT

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

# DOMAIN

data aws_acm_certificate cert {
  domain      = "brutalismbot.com"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data aws_route53_zone website {
  name = "brutalismbot.com."
}

# SECRETS

data aws_kms_alias slackbot {
  name = "alias/brutalismbot"
}

data aws_secretsmanager_secret slackbot {
  name = "brutalismbot/slack"
}
