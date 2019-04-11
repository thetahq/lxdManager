require "http"
require "json"
require "base64"
require "./api/**"

class LXDSocket
    @lxdSocket : UNIXSocket
    @head : HTTP::Headers
    getter logger : Logger
    getter containers : Containers
    getter images : Images
    getter networks : Networks
    getter operations : Operations
    getter profiles : Profiles
    getter storagePools : StoragePools
    getter cluster : Cluster

    def initialize(@logger : Logger, @lxdPath : String)
        @lxdSocket = UNIXSocket.new @lxdPath
        @logger.info "LXDS: Connected to LXD Socket!"
        @head = HTTP::Headers.new
        @head.add "Host", "s"
        @head.add "User-Agent", "lxdManger #{LxdManager::VERSION}"
        @head.add "Accept", "*/*"
        @containers = Containers.new
        @images = Images.new
        @networks = Networks.new
        @operations = Operations.new
        @profiles = Profiles.new
        @storagePools = StoragePools.new
        @cluster = Cluster.new
        @containers.lxd = self
        @images.lxd = self
        @networks.lxd = self
        @operations.lxd = self
        @profiles.lxd = self
        @storagePools.lxd = self
        @cluster.lxd = self
        testConnection
        @logger.info "LXDS: Init complete!"
    end

    def getWebSocket(path : String) : HTTP::WebSocket
        @logger.info "LXDS: Creating new WebSocket on #{path}"
        uws = UNIXSocket.new @lxdPath
        rKey = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })
        head = @head.clone
        head.add "Connection", "Upgrade"
        head.add "Upgrade", "websocket"
        head.add "Sec-WebSocket-Version", HTTP::WebSocket::Protocol::VERSION
        head.add "Sec-WebSocket-Key", rKey

        HTTP::Request.new("GET", path, head).to_io uws
        uws.flush
        res = HTTP::Client::Response.from_io uws

        unless res.status_code == 101 || res.headers["Sec-WebSocket-Accept"]? == HTTP::WebSocket::Protocol.key_challenge rKey
            raise WebSocketHandshakeException.new "WebSocket denied the Handshake!"
        end
        
        ws = HTTP::WebSocket.new HTTP::WebSocket::Protocol.new(uws, true)
        spawn ws.run
        ws
    end

    macro methods
        {% for name in ["get", "post", "put", "patch", "delete"] %}
            {% if name == "get" || name == "delete" %}
            def {{name.id}}(path : String) : HTTP::Client::Response
            {% else %}
            def {{name.id}}(path : String, body : String) : HTTP::Client::Rescponse
            {% end %}
                @logger.info "LXDS: Requesting #{"{{name.id}}".upcase} #{path}"
                {% if name == "get" || name == "delete" %}
                HTTP::Request.new("{{name.id}}".upcase, path, @head).to_io(@lxdSocket)
                {% else %}
                HTTP::Request.new("{{name.id}}".upcase, path, @head, body).to_io(@lxdSocket)
                {% end %}
                Common.errorHandler HTTP::Client::Response.from_io(@lxdSocket), path, @logger
            end
        {% end %}
    end

    methods

    def testConnection # GET / # Note: This is only a (socket) sanity check
        res = get("/")
        json = JSON.parse res.body
        unless res.status_code == 200 && json["status"] == "Success" && json["error"] == "" && json["error_code"] == 0 && json["metadata"] == ["/1.0"]
            raise InvalidConnectionException.new "Connection to LXD is Invalid!"
        end
    end

    def getEvents(type : String? = nil) : HTTP::WebSocket # GET /1.0/events
        getWebSocket "/1.0/events#{type.nil? ? "" : "?type=#{type}"}"
    end

    def getServerConfiguration : ServerConfiguration # GET /1.0/
        conf = JSON.parse(get("/1.0").body)["metadata"]
        apie = [] of String
        conf["api_extensions"].as_a.each { |e| apie << e.to_s }
        aum = [] of String
        conf["auth_methods"].as_a.each { |a| aum << a.to_s }
        co = {} of String => String
        conf["config"].as_h.each { |k, v| co[k] = v.to_s }
        env = conf["environment"]
        add = [] of String
        env["addresses"].as_a.each { |a| add << a.to_s }
        arch = [] of String
        env["architectures"].as_a.each { |a| arch << a.to_s }
        kef = {} of String => String
        env["kernel_features"].as_h.each { |k, v| kef[k] = v.to_s }
        e = ServerConfiguration::Environment.new(add, arch, env["certificate"].to_s, env["certificate_fingerprint"].to_s, env["driver"].to_s, env["driver_version"].to_s, env["kernel"].to_s, env["kernel_architecture"].to_s, kef, env["kernel_version"].to_s, env["project"].to_s, env["server"].to_s, env["server_clustered"].as_bool, env["server_name"].to_s, env["server_pid"].as_i, env["server_version"].to_s, env["storage"].to_s, env["storage_version"].to_s)
        ServerConfiguration.new(apie, conf["api_status"].to_s, conf["api_version"].to_s, conf["auth"].to_s, aum, co, e, conf["public"].as_bool)
    end

    struct ServerConfiguration
        property api_extensions, api_status, api_version, auth, auth_methods, config, environment, public

        def initialize(@api_extensions : Array(String), @api_status : String, @api_version : String, @auth : String, @auth_methods : Array(String), @config : Hash(String, String), @environment : Environment, @public : Bool)
        end

        struct Environment
            property addresses, architectures, certificate, certificate_fingerprint, driver, driver_version, kernel, kernel_architecture, kernel_features, kernel_version, project, server, server_clustered, server_name, server_pid, server_version, storage, storage_version

            def initialize(@adresses : Array(String), @archtectures : Array(String), @certificate : String, @certificate_fingerprint : String, @driver : String, @driver_verion : String, @kernel : String, @kernel_architecture : String, @kernel_features : Hash(String, String), @kernel_version : String, @project : String, @server : String, @server_clustered : Bool, @server_name : String, @server_pid : Int32, @server_version : String, @storage : String, @storage_version : String)
            end
        end
    end

    def getServerResources : ServerResources # GET /1.0/resources
        res = JSON.parse(get("/1.0/resources").body)["metadata"]
        socs = [] of ServerResources::CPU::Socket
        res["cpu"]["sockets"].as_a.each { |s| socs << ServerResources::CPU::Socket.new(s["cores"].as_i.to_i8, s["frequency"].as_i.to_i16, s["frequency_turbo"].as_i.to_i16, s["name"].to_s, s["vendor"].to_s, s["threads"].as_i.to_i8) }
        cpu = ServerResources::CPU.new(socs, res["cpu"]["total"].as_i.to_i8)
        mem = StoragePools::Resource.new(res["memory"]["used"].as_i64, res["memory"]["total"].as_i64)
        ServerResources.new(cpu, mem)
    end

    struct ServerResources
        property cpu, memory

        def initialize(@cpu : CPU, @memory : StoragePools::Resource)
        end

        struct CPU
            property sockets, total
    
            def initialize(@sockets : Array(Socket), @total : Int8)
            end

            struct Socket
                property cores, frequency, frequency_turbo, name, vendor, threads
                
                def initialize(@cores : Int8, @frequency : Int16, @frequency_turbo : Int16, @name : String, @vendor : String, @threads : Int8)
                end
            end
        end
    end

    class WebSocketHandshakeException < Exception
    end

    class InvalidConnectionException < Exception
    end
end
