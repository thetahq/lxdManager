
# Class for the /1.0/profiles API portion

class Profiles
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/profiles
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/profiles").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |p| l << p.to_s }
        l
    end

    def create(name : String, description : String, config : Hash(String, String), devices : Hash(String, Common::Device))
        payload = { "name" => name, "description" => description, "config" => config, "devices" => devices }
        @lxd.not_nil!.post "/1.0/profiles", payload.to_json
    end

    def get(name : String) : Profile # GET /1.0/profiles/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/profiles/#{name.gsub("/1.0/profiles/","")}").body
        @lxd.not_nil!.logger.debug json
        Profile.from_json json["metadata"].to_json
    end

    def rename(name : String, newName : String) # POST /1.0/profiles/<name>
        res = @lxd.not_nil!.post "/1.0/profiles/#{name.gsub("/1.0/profiles/","")}", { "name" => newName }.to_json
        raise Common::FailureException.new "Failed to rename a Profile!" if res.status_code != 204
    end

    def replaceInfo(name : String, description : String, config : Hash(String, String), devices : Hash(String, Common::Device)) # PUT /1.0/profiles/<name>
        payload = { "description" => description, "config" => config, "devices" => devices }
        @lxd.not_nil!.put "/1.0/profiles/#{name.gsub("/1.0/profiles/","")}", payload.to_json
    end

    def updateInfo(name : String, description : String? = nil, config : Hash(String, String)? = nil, devices : Hash(String, Common::Device)? = nil) # PATCH /1.0/profiles/<name>
        payload = {} of String => String | Hash(String, String) | Hash(String, Common::Device)
        payload["description"] = description if !description.nil?
        payload["config"] = config if !config.nil?
        payload["devices"] = devices if !devices.nil?
        @lxd.not_nil!.patch "/1.0/profiles/#{name.gsub("/1.0/profiles/","")}", payload.to_json
    end

    def delete(name : String) # DELETE /1.0/profiles/<name>
        res = @lxd.not_nil!.delete "/1.0/profiles/#{name.gsub("/1.0/profiles/","")}"
        raise Common::FailureException.new "Failed to delete a Profile!" if res.status_code != 202
    end

    struct Profile
        JSON.mapping(
            name: String,
            description: String,
            config: Hash(String, String),
            devices: Hash(String, Common::Device),
            used_by: Array(String)
        )

        def rename(newName : String)
            LXDSocket.i.not_nil!.profiles.rename @name, newName
        end

        def replaceInfo(description : String, config : Hash(String, String), devices : Hash(String, Common::Device))
            LXDSocket.i.not_nil!.profiles.replaceInfo @name, description, config, devices
        end

        def updateInfo(description : String? = nil, config : Hash(String, String)? = nil, devices : Hash(String, Common::Device)? = nil)
            LXDSocket.i.not_nil!.profiles.updateInfo @name, description, config, devices
        end

        def delete
            LXDSocket.i.not_nil!.profiles.delete @name
        end
    end
end