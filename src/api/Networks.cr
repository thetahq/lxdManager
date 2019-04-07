
# Class for the /1.0/networks API portion

class Networks
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/networks
        l = Array(String).new
        JSON.parse(@lxd.not_nil!.get("/1.0/networks").body)["metadata"].as_a.each { |entry| l << entry.to_s }
        l
    end

    def getInfo(name : String) : Network # GET /1.0/networks/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/networks/#{name.gsub("/1.0/networks/", "")}").body
        @lxd.not_nil!.logger.debug json
        net = json["metadata"]
        config = {} of String => String
        net["config"].as_h.each { |k, v| config[k] = v.to_s }
        usedBy = [] of String
        net["used_by"].as_a.each { |v| usedBy << v.to_s }
        Network.new(config, net["description"].to_s, net["name"].to_s, net["managed"].as_bool, net["type"] == "bridge" ? NetworkType::Bridge : NetworkType::None, usedBy, self)
    end

    def getState(name : String) : NetworkState # GET /1.0/networks/<name>/state
        json = JSON.parse @lxd.not_nil!.get("/1.0/networks/#{name.gsub("/1.0/networks/", "")}/state").body
        @lxd.not_nil!.logger.debug json
        state = json["metadata"]
        add = [] of NetworkAddress
        state["addresses"].as_a.each { |a| add << NetworkAddress.new(a["family"] == "inet6" ? Socket::Family::INET6 : Socket::Family::INET, a["address"].to_s, a["netmask"].to_s.to_i16, a["scope"].to_s) }
        count = {} of String => Int64
        state["counters"].as_h.each { |k, v| count[k] = v.as_i64 }
        ty = state["type"] == "broadcast" ? NetworkStateType::Broadcast : NetworkStateType::None
        NetworkState.new(add, count, state["hwaddr"].to_s, "", state["mtu"].as_i, state["state"].to_s, ty)
    end

    enum NetworkType # @ToDo: Add others
        None
        Bridge
        Physical
    end

    struct Network
        property config, description,  name, managed, type, used_by
        @net : Networks
    
        def initialize(@config : Hash(String, String), @description : String, @name : String, @managed : Bool, @type : NetworkType, @used_by : Array(String), @net : Networks)
        end

        def getState
            @net.getState @name
        end
    end

    enum NetworkStateType # @ToDo: Add others
        None
        Broadcast
    end

    struct NetworkState
        property addressses, counters, hwaddr, host_name, mtu, state, type

        def initialize(@addresses : Array(NetworkAddress), @counters : Hash(String, Int64), @hwaddr : String, @host_name : String, @mtu : Int32, @state : String, @type : NetworkStateType)
        end
    end

    struct NetworkAddress
        property family, address, netmask, scope

        def initialize(@family : Socket::Family, @adress : String, @netmask : Int16, @scope : String)
        end
    end
end