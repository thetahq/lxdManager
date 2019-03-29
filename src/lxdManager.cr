require "option_parser"
require "logger"
require "socket"

module LxdManager
  VERSION = "0.1.0"

  log = Logger.new STDOUT

  OptionParser.parse! do |parser|
    parser.banner = "Usage: #{PROGRAM_NAME} [-d]"
    parser.on "-d", "--debug", "Switch to Debug log level" { log.level = Logger::DEBUG }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid argument!"
      STDERR.puts parser
      exit 1
    end
  end

  sock = UNIXSocket.new "/var/lib/lxd/unix.socket"
end
