
# Class for the /1.0/operations API portion

class Operations
    setter lxd : LXDSocket?

    def getList : Array(String)# GET /1.0/operations
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/operations").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |o| l << o.to_s }
        l
    end

    def get(uuid : String) : Operation # GET /1.0/operations/<uuid>
        json = JSON.parse @lxd.not_nil!.get("/1.0/operations/#{name.gsub("/1.0/operations/", "")}").body
        @lxd.not_nil!.debug json
        Operation.from_json json["metadata"].to_json
    end

    def cancel(uuid : String)  # DELETE /1.0/operations/<uuid>
        res = @lxd.not_nil!.delete "/1.0/operations/#{uuid.gsub("/1.0/operations/", "")}"
        raise Common::FailureException.new "Failed to cancel operation!" if res.status_code != 202
    end

    def wait(uuid : String, timeout : Int? = nil)
        # GET /1.0/operations/<uuid>/wait # @ToDo: Later, this is not needed for now
    end

    def getWebsocket(uuid : String) : HTTP::WebSocket # GET /1.0/operations/<uuid>/websocket
        @lxd.not_nil!.getWebSocket "/1.0/operations/#{uuid.gsub("/1.0/operations/", "")}/websocket"
    end

    struct Operation
        JSON.mapping(
            id: String,
            "class": String,
            created_at: Time,
            updated_at: Time,
            status: String,
            status_code: UInt16,
            resources: Hash(String, Array(String)),
            metadata: Hash(String, String),
            may_cancel: Bool,
            err: String
        )

        def cancel
            LXDSocket.i.operations.cancel @id
        end

        def getWebsocket
            LXDSocket.i.operations.getWebsocket @id
        end
    end
end
