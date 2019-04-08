
# Class for the /1.0/events API portion

class Events
    setter lxd : LXDSocket?

    def getEvents(type : String) : HTTP::WebSocket # @ToDo: Create a Universal WebSocket creator in LXDSocket
        wslxd = UNIXSocket.new @lxd.not_nil!.lxdPath
        head = HTTP::Headers.new
        head["Host"] = "s"
        head["User-Agent"] = "lxdManger #{LxdManager::VERSION}"
        head["Accept"] = "*/*"
        head["Connection"] = "Upgrade"
        head["Upgrade"] = "websocket"
        head["Sec-WebSocket-Version"] = "13"
        rKey = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })
        head["Sec-WebSocket-Key"] = rKey
        HTTP::Request.new("GET", "/1.0/events?type=#{type}", head).to_io wslxd
        wslxd.flush
        res = HTTP::Client::Response.from_io wslxd

        unless res.status_code == 101 || res.headers["Sec-WebSocket-Accept"]? == HTTP::WebSocket::Protocol.key_challenge rKey
            raise "Handshake got denied!"
        end

        ws = HTTP::WebSocket.new HTTP::WebSocket::Protocol.new(wslxd, true)
        spawn ws.run
        ws
    end
end