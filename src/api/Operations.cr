
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
        op = json["metadata"]
        cat = Time::Format::YAML_DATE.parse? op["created_at"].to_s
        uat = Time::Format::YAML_DATE.parse? op["updated_at"].to_s
        res = {} of String => Array(String)
        op["resources"].as_h.each do |k, v|
            r = [] of String
            v.as_a.each { |e| r << e.to_s }
            res[k] = r
        end
        meta = {} of String => String
        op["metadata"].as_h.each { |k, v| meta[k] = v.to_s }
        Operation.new(op["id"].to_s, op["class"].to_s, cat.nil? ? Time.new : cat, uat.nil? ? Time.new : uat, op["status"].to_s, op["status_code"].as_i.to_i16, res, meta, op["may_cancel"].as_bool, op["err"].to_s)
    end

    def wait(uuid : String, timeout : Int? = nil)
        # GET /1.0/operations/<uuid>/wait # @ToDo: Later, this is not needed for now
    end

    def getWebsocket(uuid : String) : HTTP::WebSocket # GET /1.0/operations/<uuid>/websocket
        @lxd.not_nil!.getWebSocket "/1.0/operations/#{uuid.gsub("/1.0/operations/", "")}/websocket"
    end

    struct Operation
        property id, "class", created_at, updated_at, status, status_code, resources, metadata, may_cancel, err

        def initialize(@id : String, @class : String, @created_at : Time, @updated_at : Time, @status : String, @status_code : Int16, @resources : Hash(String, Array(String)), @metadata : Hash(String, String), @may_cancel : Bool, @err : String)
        end
    end
end
