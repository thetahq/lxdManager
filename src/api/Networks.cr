
# Class for the /1.0/networks API portion

class Networks
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/networks
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/networks").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |entry| l << entry.to_s }
        l
    end

    def create(name : String, description : String, config : Hash(String, String)) # POST /1.0/networks
        payload = { "name" => name, "description" => description, "config" => config }
        @lxd.not_nil!.post "/1.0/networks", payload.to_json
    end

    def get(name : String) : Network # GET /1.0/networks/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/networks/#{name.gsub("/1.0/networks/", "")}").body
        @lxd.not_nil!.logger.debug json
        Network.from_json json["metadata"].to_json
    end

    def rename(name : String, newName : String) # POST /1.0/networks/<name>
        res = @lxd.not_nil!.post "/1.0/networks/#{name.gsub("/1.0/networks/","")}", { "name" => newName }
        raise Common::FailureException.new "Failed to rename a Network!" if res.status_code != 204
    end

    def replaceInfo(name : String, description : String, config : Hash(String, String)) # PUT /1.0/networks/<name>
        payload = { "description" => description, "config" => config }
        @lxd.not_nil!.put "/1.0/networks/#{name.gsub("/1.0/networks/","")}", payload.to_json
    end

    def updateInfo(name : String, description : String? = nil, config : Hash(String, String)? = nil) # PATCH /1.0/networks/<name>
        payload = {} of String => String | Hash(String, String)
        payload["description"] = description if !description.nil?
        payload["config"] = config if !config.nil?
        @lxd.not_nil!.patch "/1.0/networks/#{name.gsub("/1.0/networks/","")}", payload.to_json if !payload.empty?
    end

    def delete(name : String) # DELETE /1.0/networks/<name>
        res = @lxd.not_nil!.delete "/1.0/networks/#{name.gsub("/1.0/networks/","")}"
        raise Common::FailureException.new "Failed to delete a Network!" if res.status_code != 202
    end

    def getState(name : String) : NetworkState # GET /1.0/networks/<name>/state
        json = JSON.parse @lxd.not_nil!.get("/1.0/networks/#{name.gsub("/1.0/networks/", "")}/state").body
        @lxd.not_nil!.logger.debug json
        NetworkState.from_json json["metadata"].to_json
    end

    enum NetworkType # @ToDo: Add others
        None
        Bridge
        Physical
        Loopback
    end

    struct Network
        JSON.mapping(
            config: Hash(String, String),
            description: String,
            name: String,
            managed: Bool,
            type: NetworkType,
            used_by: Array(String)
        )

        def getState
            LXDSocket.i.not_nil!.networks.getState @name
        end

        def rename(newName : String)
            LXDSocket.i.not_nil!.networks.rename @name, newName
        end

        def replaceInfo(description : String, config : Hash(String, String))
            LXDSocket.i.not_nil!.networks.replaceInfo @name, description, config
        end

        def updateInfo(description : String? = nil, config : Hash(String, String)? = nil)
            LXDSocket.i.not_nil!.networks.updateInfo @name, description, config
        end

        def delete
            LXDSocket.i.not_nil!.networks.delete @name
        end
    end

    enum NetworkStateType # @ToDo: Add others
        None
        Broadcast
    end

    struct NetworkState
        JSON.mapping(
            addresses: Array(NetworkAddress),
            counters: Hash(String, UInt64),
            hwaddr: String,
            host_name: {type: String, default: ""},
            mtu: UInt32,
            state: String,
            type: NetworkStateType
        )
    end

    struct NetworkAddress
        JSON.mapping(
            family: Socket::Family,
            address: String,
            netmask: String,
            scope: String
        )
    end
end