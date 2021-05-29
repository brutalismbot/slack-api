require "json"
require "net/http"

require "aws-sdk-eventbridge"
require "aws-sdk-dynamodb"

require_relative "dsl"
require_relative "logger"

EVENT_BUS_NAME = ENV["EVENT_BUS_NAME"]

EVENTS   = Aws::EventBridge::Client.new
DYNAMODB = Aws::DynamoDB::Client.new

handler :forward do |event|
  each_sns_message event do |message, attrs|
    params = { entries: [ {
      event_bus_name: EVENT_BUS_NAME,
      source:         "slack",
      detail_type:    attrs.dig("type", "Value"),
      detail:         message
    } ] }
    logger.info("PUT EVENTS #{ params.to_json }")
    EVENTS.put_events(**params)
  end
end

handler :events_app_uninstalled do |event|
  params = event.transform_keys(&:snake_case)
  params[:projection_expression] = "GUID,SORT"
  logger.info("QUERY #{ params.to_json }")
  DYNAMODB.query(**params).items.map do |key|
    logger.info("- #{ key.to_json }")
    { delete: { key: key, **params.slice(:table_name) } }
  end.tap do |keys|
    pages = keys.each_slice(25)
    pages.each_with_index do |page, i|
      params = { transact_items: page }
      logger.info("TRANSACT DELETE [#{ i + 1 }/#{ pages.count }]")
      DYNAMODB.transact_write_items(**params)
    end
  end
end
