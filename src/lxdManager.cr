require "option_parser"
require "file_utils"
require "logger"
require "socket"
require "./lxdSocket"

module LxdManager
  VERSION = "0.1.0"
  LXD_SOCKET_PATH = "/var/lib/lxd/unix.socket"
  SERVER_SOCKET_PATH = "/tmp/lxdManager.socket"

  log = Logger.new STDOUT

  OptionParser.parse! do |parser|
    parser.banner = "Usage: #{PROGRAM_NAME} [--debug] [--config=<path>]"
    parser.on "-d", "--debug", "Switch to Debug log level" { log.level = Logger::DEBUG }
    parser.on "-c", "--config", "Path to configuration file" {}
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid argument!"
      STDERR.puts parser
      exit 1
    end
  end

  lxd = LXDSocket.new log, LXD_SOCKET_PATH
  if File.exists? SERVER_SOCKET_PATH
    log.debug "Found leftover socket! Deleting..."
    FileUtils.rm SERVER_SOCKET_PATH
  end
  server = UNIXServer.new SERVER_SOCKET_PATH
  log.debug "Init complete!"

  # spawn lxd.test

  spawn do
    while ss = server.accept?
      client = ss.nil? ? next : ss
      spawn do
        while !client.closed?
          mess = client.gets
          next if mess.nil?
          begin
            json = JSON.parse mess
            if json.dig?("type").to_s.downcase == "get" && json.dig?("request") != nil
              req = json["request"]
              if req.dig?("path") != nil
                path = req["path"].to_s
                client.send lxd.get(path).body
              else
                client.send({ "error" => "Invalid request! No path!" }.to_json)
              end
            else
              client.send({ "error" => "No type or request!" }.to_json)
            end
          rescue
            client.send({ "error" => "Invalid message!" }.to_json)
          end
        end
      end
    end
  end

  Signal::INT.trap do
    log.debug "SIGINT"
    server.close true
    exit
  end

  Channel(Nil).new.receive
end
