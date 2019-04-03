require "socket"
require "http"
require "logger"
require "json"

class LXDSocket
    @lxdSocket : UNIXSocket
    @head : HTTP::Headers

    def initialize(@logger : Logger, lxdPath : String)
        @lxdSocket = UNIXSocket.new lxdPath
        @logger.info "Connected to LXD Socket!"
        @head = HTTP::Headers.new
        @head.add "Host", "s"
        @head.add "User-Agent", "lxdManger 1.0"
        @head.add "Accept", "*/*"
    end

    def get(path : String) : HTTP::Client::Response
        HTTP::Request.new("GET", path, @head).to_io(@lxdSocket)
        HTTP::Client::Response.from_io(@lxdSocket)
    end

    def post(path : String, body : String) : HTTP::Client::Response
        HTTP::Request.new("POST", path, @head, body).to_io(@lxdSocket)
        HTTP::Client::Response.from_io(@lxdSocket)
    end

    def test
        # payload = { "name" => "test", "architecture" => "x86_64", "profiles" => ["default"], "ephemeral" => true, "source" => { "type" => "none" } }
        # res = post("/1.0/containers", payload.to_json)
        # @logger.info res.status_code
        # @logger.info JSON.parse(res.body)
        # res = get "/1.0/resources"
        # @logger.info JSON.parse(res.body)
    end
end
