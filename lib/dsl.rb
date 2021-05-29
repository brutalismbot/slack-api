class String
  def snake_case
    gsub(/([a-z])([A-Z])/, '\1_\2').downcase
  end
end

class Symbol
  def snake_case
    to_s.snake_case.to_sym
  end
end

module Brutalismbot
  module DSL
    ##
    # Lambda handler task wrapper
    def handler(name, &block)
      define_method(name) do |event:nil, context:nil|
        original_progname = logger.progname
        logger.progname = context&.aws_request_id
        logger.info("EVENT #{ event.to_json }")
        yield(event, context).tap { |res| logger.info("RETURN #{ res.to_json }") }
      ensure
        logger.progname = original_progname
      end
    end

    ##
    # SNS message yielder
    def each_sns_message(event, &block)
      event["Records"].each do |record|
        record["Sns"].then do |sns|
          yield sns["Message"], sns["MessageAttributes"]
        end
      end
    end
  end
end

extend Brutalismbot::DSL
