require "json"
require "logger"
require "net/http"

require "aws-sdk-eventbridge"
require "aws-sdk-dynamodb"

$logger = Logger.new $stderr, progname: "-", formatter: -> (lvl, t, name, msg) { "#{ lvl } #{ name } #{ msg }\n" }

##
# Lambda handler task wrapper
def handler(name, &block)
  define_method(name) do |event:nil, context:nil|
    $logger.progname = context.nil? ? "-" : "RequestId: #{ context.aws_request_id }"
    $logger.info("EVENT #{ event.to_json }")
    result = yield event, context if block_given?
    $logger.info("RETURN #{ result.to_json }")
    result
  end
end

##
# SNS message yielder
def each_sns_message(event, &block)
  event["Records"]&.each do |record|
    record["Sns"].then do |sns|
      yield sns["Message"], sns["MessageAttributes"]
    end
  end
end

EVENT_BUS_NAME = ENV["EVENT_BUS_NAME"]

EVENTS   = Aws::EventBridge::Client.new
DYNAMODB = Aws::DynamoDB::Client.new

handler :forward do |event|
  each_sns_message event do |message, attrs|
    params = {
      entries: [{
        event_bus_name: EVENT_BUS_NAME,
        source: "slack",
        detail_type: attrs.dig("type", "Value"),
        detail: message
      }]
    }
    $logger.info("PUT EVENTS #{ params.to_json }")
    EVENTS.put_events(**params)
  end
end

handler :events_app_uninstalled do |event|
  snake_case = -> (str) { str.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym }
  params = event.transform_keys(&snake_case)
  params[:projection_expression] = "GUID,SORT"
  $logger.info("QUERY #{ params.to_json }")
  keys = DYNAMODB.query(**params).items.map do |key|
    $logger.info("- #{ key.to_json }")
    { delete: { key: key, **params.slice(:table_name) } }
  end
  pages = keys.each_slice(25)
  pages.each_with_index do |page, i|
    params = { transact_items: page }
    $logger.info("TRANSACT DELETE [#{ i + 1 }/#{ pages.count }]")
    DYNAMODB.transact_write_items(**params)
  end

  keys
end
