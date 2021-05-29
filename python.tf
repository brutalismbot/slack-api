# PYTHON API

resource "aws_apigatewayv2_api" "http_api_v2" {
  description   = "Brutalismbot slack API v2"
  name          = "brutalismbot/slack/v2"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default_v2" {
  api_id      = aws_apigatewayv2_api.http_api_v2.id
  auto_deploy = true
  description = "Brutalismbot HTTP API"
  name        = "$default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_logs_v2.arn

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

resource "aws_cloudwatch_log_group" "http_api_logs_v2" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.http_api_v2.name}"
  retention_in_days = 14
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_arn" "event_bus" {
  arn = "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/brutalismbot"
}

resource "aws_apigatewayv2_api_mapping" "slack_v2" {
  api_mapping_key = "slack/v2"
  api_id          = aws_apigatewayv2_api.http_api_v2.id
  domain_name     = "api.brutalismbot.com"
  stage           = aws_apigatewayv2_stage.default_v2.id
}

module "slackbot_v2" {
  source  = "amancevice/slackbot/aws"
  version = "~> 22.1"

  kms_key_alias               = "alias/brutalismbot/v2"
  lambda_post_function_name   = "brutalismbot-v2-slack-api-post"
  lambda_proxy_function_name  = "brutalismbot-v2-slack-api-proxy"
  log_group_retention_in_days = 14
  role_name                   = "brutalismbot-v2-slack-lambda"
  secret_name                 = "brutalismbot/slack/v2"

  event_bus_arn          = data.aws_arn.event_bus.arn
  http_api_id            = aws_apigatewayv2_api.http_api_v2.id
  http_api_execution_arn = aws_apigatewayv2_api.http_api_v2.execution_arn
}

module "slash_brutalismbot" {
  source  = "amancevice/slackbot-slash-command/aws"
  version = "~> 19.0"

  event_bus_name              = "brutalismbot"
  event_rule_name             = "slack-slash-brutalism"
  lambda_description          = "Slack handler for /brutalism"
  lambda_function_name        = "brutalismbot-v2-slack-slash-brutalismbot"
  lambda_kms_key_arn          = module.slackbot_v2.kms_key.arn
  lambda_role_arn             = module.slackbot_v2.role.arn
  log_group_retention_in_days = 14
  slack_response_type         = "modal"
  slack_slash_command         = "brutalism"

  slack_response = jsonencode({
    response_type = "modal"
    text          = "Brutalismbot Help"

    view = {
      type        = "modal"
      callback_id = "slash_brutalismbot_help"

      title = {
        type  = "plain_text"
        text  = "Kickbot Block Kit Tester"
        emoji = true
      },

      submit = {
        type : "plain_text"
        text : "Send"
        emoji : true
      }

      close = {
        type  = "plain_text"
        text  = "Cancel"
        emoji = true
      },

      blocks = [
        {
          type = "input"

          element = {
            type = "conversations_select"

            placeholder = {
              type  = "plain_text"
              emoji = true
              text  = "Select a conversation"
            }
          }

          label = {
            type  = "plain_text"
            text  = "Post Destination"
            emoji = true
          }
        },
        {
          type = "input"

          element = {
            type = "plain_text_input",

            placeholder = {
              type = "plain_text"
              text = "slack.api.method"
            }
          }

          label = {
            type  = "plain_text"
            text  = "Slack API method name"
            emoji = true
          }
        },

        {
          type = "input",

          element = {
            type      = "plain_text_input",
            multiline = true,
            placeholder = {
              type = "plain_text"
              text = "{ Paste your Block Kit JSON here… }"
            }
          }

          label = {
            type  = "plain_text"
            text  = "Message"
            emoji = true
          }
        }
      ]
    }
  })
}

# DATA

data "archive_file" "package" {
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/package.zip"
  type        = "zip"
}

data "aws_iam_role" "events" {
  name = "brutalismbot-events"
}

data "aws_iam_role" "states" {
  name = "brutalismbot-states"
}

data "aws_iam_role" "lambda" {
  name = "brutalismbot-lambda"
}

# SNS => EVENTBRIDGE FWD

data "aws_sns_topic" "brutalismbot_slack" {
  name = "brutalismbot-slack"
}

resource "aws_sns_topic_subscription" "forward" {
  endpoint  = aws_lambda_function.forward.arn
  protocol  = "lambda"
  topic_arn = data.aws_sns_topic.brutalismbot_slack.arn
}

resource "aws_lambda_permission" "forward" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forward.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_sns_topic.brutalismbot_slack.arn
}

resource "aws_cloudwatch_log_group" "forward" {
  name              = "/aws/lambda/${aws_lambda_function.forward.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "forward" {
  description      = "Slack SNS message to EventBridge"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-v2-slack-sns-to-eventbridge"
  handler          = "index.forward"
  role             = data.aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      EVENT_BUS_NAME = "brutalismbot"
    }
  }
}

# OAUTH

resource "aws_cloudwatch_event_rule" "oauth" {
  description    = "Slack app installed"
  event_bus_name = "brutalismbot"
  name           = "slack-oauth"
  role_arn       = data.aws_iam_role.events.arn

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["oauth"]
  })
}

resource "aws_cloudwatch_event_target" "oauth" {
  arn            = aws_sfn_state_machine.oauth.arn
  event_bus_name = "brutalismbot"
  input_path     = "$.detail"
  role_arn       = data.aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.oauth.name
}

resource "aws_sfn_state_machine" "oauth" {
  name     = "brutalismbot-slack-oauth"
  role_arn = data.aws_iam_role.states.arn

  definition = templatefile("${path.module}/state-machines/oauth.asl.json", {
    table_name = "Brutalismbot"
  })
}

# EVENTS :: APP UNINSTALLED

resource "aws_cloudwatch_event_rule" "events_app_uninstalled" {
  description    = "Slack app uninstalled"
  event_bus_name = "brutalismbot"
  name           = "slack-events-app-uninstall"
  role_arn       = data.aws_iam_role.events.arn

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["event"]
    detail = {
      event = {
        type = ["app_uninstalled"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "events_app_uninstalled" {
  arn            = aws_sfn_state_machine.events_app_uninstalled.arn
  event_bus_name = "brutalismbot"
  input_path     = "$.detail"
  role_arn       = data.aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.events_app_uninstalled.name
}

resource "aws_sfn_state_machine" "events_app_uninstalled" {
  name     = "brutalismbot-slack-events-app-uninstall"
  role_arn = data.aws_iam_role.states.arn

  definition = templatefile("${path.module}/state-machines/events-app-uninstall.asl.json", {
    table_name = "Brutalismbot"
    uninstall  = aws_lambda_function.events_app_uninstalled.arn
  })
}

resource "aws_cloudwatch_log_group" "events_app_uninstalled" {
  name              = "/aws/lambda/${aws_lambda_function.events_app_uninstalled.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "events_app_uninstalled" {
  description      = "Slack uninstall"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-v2-slack-uninstall"
  handler          = "index.events_app_uninstalled"
  role             = data.aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      EVENT_BUS_NAME = "brutalismbot"
    }
  }
}

# EVENTS :: APP HOME OPENED

data "aws_lambda_function" "post" {
  function_name = "brutalismbot-v2-slack-api-post"
}

resource "aws_cloudwatch_event_rule" "events_app_home_opened" {
  description    = "Slack app home opened"
  event_bus_name = "brutalismbot"
  name           = "slack-events-app-home-opened"
  role_arn       = data.aws_iam_role.events.arn

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["event"]
    detail      = { event = { type = ["app_home_opened"] } }
  })
}

resource "aws_cloudwatch_event_target" "events_app_home_opened" {
  arn            = aws_sfn_state_machine.events_app_home_opened.arn
  event_bus_name = "brutalismbot"
  input_path     = "$.detail"
  role_arn       = data.aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.events_app_home_opened.name
}

resource "aws_sfn_state_machine" "events_app_home_opened" {
  name     = "brutalismbot-slack-events-app-home-opened"
  role_arn = data.aws_iam_role.states.arn

  definition = templatefile("${path.module}/state-machines/events-app-home-opened.asl.json", {
    table_name = "Brutalismbot"
    post_arn   = data.aws_lambda_function.post.arn
  })
}

# CALLBACKS :: SETTINGS_SAVED

resource "aws_cloudwatch_event_rule" "callbacks_settings_saved" {
  description    = "Slack app home opened"
  event_bus_name = "brutalismbot"
  name           = "slack-callbacks-settings-saved"
  role_arn       = data.aws_iam_role.events.arn

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["callback"]
    detail      = { view = { callback_id = ["settings"] } }
  })
}

resource "aws_cloudwatch_event_target" "callbacks_settings_saved" {
  arn            = aws_sfn_state_machine.callbacks_settings_saved.arn
  event_bus_name = "brutalismbot"
  input_path     = "$.detail"
  role_arn       = data.aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.callbacks_settings_saved.name
}

resource "aws_sfn_state_machine" "callbacks_settings_saved" {
  name     = "brutalismbot-slack-callbacks-settings-saved"
  role_arn = data.aws_iam_role.states.arn

  definition = templatefile("${path.module}/state-machines/callbacks-settings-saved.asl.json", {
    table_name             = "Brutalismbot"
    events_app_home_opened = aws_sfn_state_machine.events_app_home_opened.arn
  })
}
