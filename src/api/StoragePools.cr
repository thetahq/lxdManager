
# Class for the /1.0/storage-pools API portion

class StoragePools
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/storage-pools
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/storage-pools").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |s| l << s.to_s }
        l
    end

    def create(name : String, description : String, driver : String, config : Hash(String, String)) # POST /1.0/storage-pools
        payload = { "name" => name, "description" => description, "driver" => driver, "config" => config }
        @lxd.not_nil!.post "/1.0/storage-pools", payload.to_json
    end

    def get(name : String) : StoragePool # GET /1.0/storage-pools/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}").body
        @lxd.not_nil!.logger.debug json
        StoragePool.from_json json["metadata"].to_json
    end

    def replaceInfo(name : String, description : String, config : Hash(String, String)) # PUT /1.0/storage-pools/<name>
        payload = { "description" => description, "config" => config }
        @lxd.not_nil!.put "/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}", payload.to_json
    end

    def updateInfo(name : String, description : String? = nil, config : Hash(String, String)? = nil) # PATCH /1.0/storage-pools/<name>
        payload = {} of String => String | Hash(String, String)
        payload["description"] = description if !description.nil?
        payload["config"] = config if !config.nil?
        @lxd.not_nil!.patch "/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}", payload.to_json
    end

    def delete(name : String) # DELETE /1.0/storage-pools/<name>
        @lxd.not_nil!.delete "/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}"
    end

    def getResources(name : String) : StorageResources # GET /1.0/storage-pools/<name>/resources
        json = JSON.parse @lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}/resources").body
        @lxd.not_nil!.logger.debug json
        StorageResources.from_json json["metadata"].to_json
    end

    def getVolumes(name : String) : Array(String) # GET /1.0/storage-pools/<name>/volumes
        vols = [] of String
        JSON.parse(@lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/","")}/volumes").body)["metadata"].as_a.each { |v| vols << v.to_s }
        vols
    end

    def createVolume(name : String, volName : String, config : Hash(String, String), type : String = "custom", source : VolumeSource? = nil) # POST /1.0/storage-pools/<name>/volumes
        payload = {} of String => String | Hash(String, String) | VolumeSource
        payload["name"] = volName
        payload["type"] = type
        payload["config"] = config
        payload["source"] = source if !source.nil?
        @lxd.not_nil!.post "/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/","")}/volumes", payload.to_json
    end

    struct StoragePool
        JSON.mapping(
            name: String,
            description: String,
            driver: String,
            used_by: Array(String),
            config: Hash(String, String)
        )

        def getResources
            LXDSocket.i.not_nil!.storagePools.getResources @name
        end

        def getVolumes
            LXDSocket.i.not_nil!.storagePools.getVolumes @name
        end

        def replaceInfo(description : String, config : Hash(String, String))
            LXDSocket.i.not_nil!.storagePools.replaceInfo @name, description, config
        end

        def updateInfo(description : String? = nil, config : Hash(String, String)? = nil)
            LXDSocket.i.not_nil!.storagePools.updateInfo @name, description, config
        end

        def delete
            LXDSocket.i.not_nil!.storagePools.delete @name
        end

        def createVolume(volName : String, config : Hash(String, String), type : String = "custom", source : VolumeSource? = nil)
            LXDSocket.i.not_nil!.storagePools.createVolume @name, volName, config, type, source
        end
    end

    struct StorageResources
        JSON.mapping(
            space: Common::Resource,
            inodes: Common::Resource
        )
    end

    abstract struct VolumeSource
    end

    struct CopyVolume < VolumeSource
        JSON.mapping(
            pool: String,
            name: String,
            type: String
        )

        def initialize(@pool, @name)
            @type = "copy"
        end
    end

    struct MigrateVolume < VolumeSource
        JSON.mapping(
            pool: String,
            name: String,
            type: String,
            mode: String
        )

        def initialize(@pool, @name, @mode : String = "pull")
            @type = "migration"
        end
    end
end