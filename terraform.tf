terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "brutalismbot"
    key    = "terraform/api.tfstate"
    region = "us-east-1"
  }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.38"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags { tags = local.tags }
}

locals {
  tags = {
    App  = "brutalismbot"
    Name = "slack"
    Repo = "https://github.com/brutalismbot/slack-api"
  }
}

# HTTP API :: CORE

resource "aws_apigatewayv2_api" "http_api" {
  description   = "Brutalismbot slack API"
  name          = "brutalismbot/slack"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  auto_deploy = true
  description = "Brutalismbot HTTP API"
  name        = "$default"

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

resource "aws_cloudwatch_log_group" "http_api_logs" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14
}

# HTTP API :: MAPPING /slack

resource "aws_apigatewayv2_api_mapping" "slack" {
  api_mapping_key = "slack"
  api_id          = aws_apigatewayv2_api.http_api.id
  domain_name     = "api.brutalismbot.com"
  stage           = aws_apigatewayv2_stage.default.id
}

/*
resource "aws_route53_health_check" "healthcheck" {
  failure_threshold = "3"
  fqdn              = "api.brutalismbot.com"
  measure_latency   = true
  port              = 443
  request_interval  = "30"
  resource_path     = "/slack/health"
  type              = "HTTPS"
}
*/

# SLACKBOT

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_arn" "event_bus" {
  arn = "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/brutalismbot"
}

module "slackbot" {
  source  = "amancevice/slackbot/aws"
  version = "~> 23.0"

  kms_key_alias               = "alias/brutalismbot"
  lambda_post_function_name   = "brutalismbot-slack-api-post"
  lambda_proxy_function_name  = "brutalismbot-slack-api-proxy"
  log_group_retention_in_days = 14
  role_name                   = "brutalismbot-lambda-slack"
  secret_name                 = "brutalismbot/slack"

  event_bus_arn          = data.aws_arn.event_bus.arn
  http_api_id            = aws_apigatewayv2_api.http_api.id
  http_api_execution_arn = aws_apigatewayv2_api.http_api.execution_arn
}

# OUTPUTS

output "healthcheck" {
  value = "https://api.brutalismbot.com/slack/health"
}
