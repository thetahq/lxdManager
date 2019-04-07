require "option_parser"
require "file_utils"
require "logger"
require "socket"
require "toml"
require "./lxdSocket"

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
  server = UNIXServer.new SERVER_SOCKET_PATH
  log.debug "Init complete!"

  # net = lxd.networks.getInfo(lxd.networks.getList[0])
  # log.debug net.name
  # log.debug net.config
  # log.debug net.managed
  # st = net.getState
  # log.debug st.hwaddr

  cont = lxd.containers.getInfo(lxd.containers.getList[0])
  log.debug cont.name
  log.debug cont.architecture
  log.debug cont.status
  state = cont.getState
  log.debug state.cpu
  log.debug state.memory
  log.debug state.network

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

  #S Misc

  Signal::INT.trap do
    log.debug "SIGINT"
    server.close true
    exit
  end

  Channel(Nil).new.receive
end
