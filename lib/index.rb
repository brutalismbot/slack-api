require "json"
require "logger"
require "net/http"

require "aws-sdk-eventbridge"
require "aws-sdk-dynamodb"

class LambdaFormatter < Logger::Formatter
  Format = "%s %s %s\n"

  def call(severity, time, progname, msg)
    Format % [ severity, progname.nil? ? "-" : "RequestId: #{ progname }", msg2str(msg).strip ]
  end
end

$logger = Logger.new STDOUT, formatter: LambdaFormatter.new

def handler(name, &block)
  define_method(name) do |event:nil, context:nil|
    original_progname = $logger.progname
    $logger.progname = context&.aws_request_id
    $logger.info("EVENT #{ event.to_json }")
    yield(event, context).tap { |res| $logger.info("RETURN #{ res.to_json }") }
  ensure
    $logger.progname = original_progname
  end
end

def each_sns_message(event, &block)
  event["Records"].each do |record|
    record["Sns"].then do |sns|
      yield sns["Message"], sns["MessageAttributes"]
    end
  end
end

EVENTS   = Aws::EventBridge::Client.new
DYNAMODB = Aws::DynamoDB::Client.new

handler :forward do |event|
  each_sns_message event do |message, attrs|
    params = { entries: [ {
      event_bus_name: ENV["EVENT_BUS_NAME"],
      source:         "slack",
      detail_type:    attrs.dig("type", "Value"),
      detail:         message
    } ] }
    $logger.info("PUT EVENTS #{ params.to_json }")
    EVENTS.put_events(**params)
  end
end
