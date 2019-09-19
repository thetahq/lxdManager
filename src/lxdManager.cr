require "option_parser"
require "file_utils"
require "logger"
require "socket"
require "toml"
require "./lxdSocket"
require "./RequestManager"
require "./requests/**"

module LxdManager
  VERSION = "0.1.0"
  SERVER_SOCKET_PATH = "/tmp/lxdManager.socket"

  log = Logger.new STDOUT
  configPath = "./config.toml"
  lxdSocketPath = "/var/snap/lxd/common/lxd/unix.socket"

  OptionParser.parse! do |parser|
    parser.banner = "Usage: #{PROGRAM_NAME} [options]"
    parser.separator
    parser.on "-d", "--debug", "Switch to Debug log level" { log.level = Logger::DEBUG }
    parser.on "-s", "--socket", "Path to LXD Socket" do |s|
      lxdSocketPath = s
      log.debug "Set LXD Socket to: #{lxdSocketPath}"
    end
    parser.on "-c", "--config=PATH", "Path to configuration file" do |c|
      configPath = c
      log.debug "Set config file to: #{configPath}"
    end
    parser.on "-v", "--version", "Shows version" do
      puts "LXDManager v#{VERSION}"
      exit
    end
    parser.on "-h", "--help", "Show this message" do
      puts parser
      exit
    end
    parser.separator
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid argument!"
      STDERR.puts parser
      exit 1
    end
  end

  #S Config loader

  if !File.exists? configPath
    log.error "Config not found!"
    log.error "Please provide valid path!"
    exit 1
  end
  begin
    config = TOML.parse File.new(configPath).gets_to_end
  rescue e
    log.error "Invalid Config!"
    log.error e.to_s
    exit 1
  end
  log.debug "Config loaded!"

  #S Connect to mongo

  # ToDo: MONGO HERE

  #S Socket loader

  lxd = LXDSocket.new log, lxdSocketPath
  if File.exists? SERVER_SOCKET_PATH
    log.debug "Found leftover socket! Deleting..."
    FileUtils.rm SERVER_SOCKET_PATH
  end
  socketRM = RequestManager.new lxd
  server = UNIXServer.new SERVER_SOCKET_PATH
  log.debug "Init complete!"

  #S LXD Logger

  ws = lxd.getEvents
  ws.on_message do |mess|
    log.debug mess # @ToDo: Rewrite into proper logger
  end

  #S Tests (for development)

  # None
  # log.info lxd.containers.getList
  # c = {} of String => String
  # lxd.networks.getList.each do |n|
  #   net = lxd.networks.get(n)
  #   log.info net
  #   log.info net.getState if net.managed
  #   c = net.config if net.name = "ALO"
  # end
  # lxd.images.deleteAlias("a")

  #S Server Socket main loop

  spawn do
    while ss = server.accept?
      client = ss.nil? ? next : ss
      spawn do
        while !client.closed?
          mess = client.gets
          next if mess.nil?
          log.debug "SOC: Received message: #{mess}"
          begin
            sm = RequestManager::SocketMessage.from_json mess
            socketRM.handle sm, client
          rescue e
            client.send({ "status" => "error", "error" => e.to_s }.to_json)
          end
        end
      end
    end
  end

  #S Misc

  Signal::INT.trap do
    log.debug "SIGINT"
    server.close true
    exit
  end

  Channel(Nil).new.receive
end
