
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

# HTTP API :: DOMAIN

resource aws_apigatewayv2_domain_name domain {
  domain_name = "slack.brutalismbot.com"
  tags        = local.tags

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource aws_apigatewayv2_api_mapping domain {
  api_mapping_key = ""
  api_id          = aws_apigatewayv2_api.http_api.id
  domain_name     = aws_apigatewayv2_domain_name.domain.id
  stage           = aws_apigatewayv2_stage.default.id
}

resource aws_route53_record us_east_1 {
  health_check_id = aws_route53_health_check.healthcheck.id
  name            = aws_apigatewayv2_domain_name.domain.domain_name
  set_identifier  = "us-east-1.${aws_apigatewayv2_domain_name.domain.domain_name}"
  type            = "A"
  zone_id         = data.aws_route53_zone.website.id

  alias {
    evaluate_target_health = true
    name                   = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.hosted_zone_id
  }

  latency_routing_policy {
    region = "us-east-1"
  }
}

resource aws_route53_health_check healthcheck {
  failure_threshold = "3"
  fqdn              = "slack.brutalismbot.com"
  measure_latency   = true
  port              = 443
  request_interval  = "30"
  resource_path     = "/health"
  tags              = local.tags
  type              = "HTTPS"
}


# SLACKBOT V2

module slackbot_v2 {
  source  = "amancevice/slackbot/aws"
  version = "19.3.0"

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
