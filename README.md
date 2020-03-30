<img alt="brutalismbot" src="https://brutalismbot.com/banner.png"/>

[![plan](https://github.com/brutalismbot/slack-api/workflows/plan/badge.svg)](https://github.com/brutalismbot/slack-api/actions)

Brutalismbot REST API for interfacing with Slack.

## Archictecture

<img alt="install-uninstall" src="https://brutalismbot.com/arch-install-uninstall.png"/>

When the app is installed, The Brutalismbot REST API sends a `POST` request to Slack's [oauth.access](https://api.slack.com/methods/oauth.access) REST endpoint. The resulting OAuth payload (with incoming webhook URL) is published to an SNS topic that triggers a Lambda that persists the payload to S3 and sends the current top bost on /r/brutalism to the new workspace using the webhook URL.

When the app is uninstalled, Slack sends a `POST` request of the uninstall event to the Brutalismbot REST API. The event is published to an SNS topic that triggers a Lambda to remove the OAuth from S3.

### See Also

- [Brutalismbot App](https://github.com/brutalismbot/brutalismbot)
- [Brutalismbot Gem](https://github.com/brutalismbot/gem)
- [Brutalismbot Monitoring](https://github.com/brutalismbot/monitoring)
