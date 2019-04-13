require "http"
require "json"
require "base64"
require "json/mapping.cr"
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

    @@instance : LXDSocket?
    def self.i
        @@instance
    end

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
        @@instance = self
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
            def {{name.id}}(path : String, body : String) : HTTP::Client::Response
            {% end %}
                @logger.info "LXDS: Requesting #{"{{name.id}}".upcase} #{path}"
                {% if name == "get" || name == "delete" %}
                HTTP::Request.new("{{name.id}}".upcase, path, @head).to_io(@lxdSocket)
                {% else %}
                HTTP::Request.new("{{name.id}}".upcase, path, @head, body).to_io(@lxdSocket)
                {% end %}
                Common.errorHandler HTTP::Client::Response.from_io(@lxdSocket), "{{name.id}}".upcase, path, @logger
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
        ServerConfiguration.from_json JSON.parse(get("/1.0").body)["metadata"].to_json
    end

    struct ServerConfiguration
        JSON.mapping(
            api_extensions: Array(String),
            api_status: String,
            api_version: String,
            auth: String,
            auth_methods: Array(String),
            config: Hash(String, String),
            environment: Environment,
            public: Bool
        )

        struct Environment
            JSON.mapping(
                addresses: Array(String),
                architectures: Array(String),
                certificate: String,
                certificate_fingerprint: String,
                driver: String,
                driver_version: String,
                kernel: String,
                kernel_architecture: String,
                kernel_features: Hash(String, String),
                kernel_version: String,
                project: String,
                server: String,
                server_clustered: Bool,
                server_name: String,
                server_pid: UInt32,
                server_version: String,
                storage: String,
                storage_version: String
            )
        end
    end

    def getServerResources : ServerResources # GET /1.0/resources
        ServerResources.from_json JSON.parse(get("/1.0/resources").body)["metadata"].to_json
    end

    struct ServerResources
        JSON.mapping(
            cpu: CPU,
            memory: Common::Resource
        )

        struct CPU
            JSON.mapping(
                sockets: Array(Socket),
                total: UInt8
            )

            struct Socket
                JSON.mapping(
                    cores: UInt8,
                    frequency: UInt16,
                    frequency_turbo: UInt16,
                    name: String,
                    vendor: String,
                    threads: UInt8
                )
            end
        end
    end

    class WebSocketHandshakeException < Exception
    end

    class InvalidConnectionException < Exception
    end
end
