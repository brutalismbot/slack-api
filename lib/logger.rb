require "logger"

module Brutalismbot
  module Logger
    class LambdaFormatter < ::Logger::Formatter
      Format = "%s %s %s\n"

      def call(severity, time, progname, msg)
        Format % [ severity, progname.nil? ? "-" : "RequestId: #{ progname }", msg2str(msg).strip ]
      end
    end

    attr_accessor :logger

    def logger
      @logger ||= Logger.new STDOUT, formatter: Logger::LambdaFormatter.new
    end
  end
end

extend Brutalismbot::Logger
