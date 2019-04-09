
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

    def get(name : String) : StoragePool # GET /1.0/storage-pools/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}").body
        @lxd.not_nil!.logger.debug json
        stor = json["metadata"]
        uby = [] of String
        stor["used_by"].as_a.each { |s| uby << s.to_s }
        conf = {} of String => String
        stor["config"].as_h.each { |k, v| conf[k] = v.to_s }
        StoragePool.new(stor["name"].to_s, stor["description"].to_s, stor["driver"].to_s, uby, conf, self)
    end

    def getResources(name : String) : StorageResources # GET /1.0/storage-pools/<name>/resources
        json = JSON.parse @lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/", "")}/resources").body
        @lxd.not_nil!.logger.debug json
        res = json["metadata"]
        sp = Resource.new(res["space"]["used"].as_i64, res["space"]["total"].as_i64)
        ino = Resource.new(res["inodes"]["used"].as_i64, res["inodes"]["total"].as_i64)
        StorageResources.new(sp, ino)
    end

    def getVolumes(name : String) : Array(String) # GET /1.0/storage-pools/<name>/volumes
        vols = [] of String
        JSON.parse(@lxd.not_nil!.get("/1.0/storage-pools/#{name.gsub("/1.0/storage-pools/","")}/volumes").body)["metadata"].as_a.each { |v| vols << v.to_s }
        vols
    end

    struct StoragePool
        property name, description, driver, used_by, config

        def initialize(@name : String, @description : String, @driver : String, @used_by : Array(String), @config : Hash(String, String), @stp : StoragePools)
        end

        def getResources
            @stp.getResources @name
        end

        def getVolumes
            @stp.getVolumes @name
        end
    end

    struct StorageResources
        property space, inodes

        def initialize(@space : Resource, @inodes : Resource)
        end
    end

    struct Resource # @ToDo: Maybe move to common
        property used, total

        def initialize(@used : Int64, @total : Int64)
        end
    end
end