locals {
  tags = {
    App  = "slack-api"
    Name = "brutalismbot"
    Repo = "https://github.com/brutalismbot/slack-api"
  }
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.11"
}

module secrets {
  source  = "amancevice/slackbot-secrets/aws"
  version = "4.0.0"

  kms_key_alias = "alias/brutalismbot"
  secret_name   = "brutalismbot-slack"

  slack_client_id          = var.SLACK_CLIENT_ID
  slack_client_secret      = var.SLACK_CLIENT_SECRET
  slack_oauth_error_uri    = var.SLACK_OAUTH_ERROR_URI
  slack_oauth_redirect_uri = var.SLACK_OAUTH_REDIRECT_URI
  slack_oauth_success_uri  = var.SLACK_OAUTH_SUCCESS_URI
  slack_signing_secret     = var.SLACK_SIGNING_SECRET
  slack_signing_version    = var.SLACK_SIGNING_VERSION
  slack_token              = var.SLACK_TOKEN
  kms_key_tags             = local.tags
  secret_tags              = local.tags
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
