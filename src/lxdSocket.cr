require "http"
require "json"
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

    def initialize(@logger : Logger, lxdPath : String)
        @lxdSocket = UNIXSocket.new lxdPath
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
        @logger.debug "LXDS: Init complete!"
    end

    def get(path : String) : HTTP::Client::Response
        @logger.debug "LXDS: Requesting GET #{path}"
        HTTP::Request.new("GET", path, @head).to_io(@lxdSocket)
        HTTP::Client::Response.from_io(@lxdSocket)
    end

    def post(path : String, body : String) : HTTP::Client::Response
        @logger.debug "LXDS: Requesting POST #{path} with body #{body}"
        HTTP::Request.new("POST", path, @head, body).to_io(@lxdSocket)
        HTTP::Client::Response.from_io(@lxdSocket)
    end

    def testConnection
        # GET /
    end

    def getServerResources
        # GET /1.0/resources
    end

    class Images
        setter lxd : LXDSocket?

        def getList : Array(String)
            # GET /1.0/images
        end

        def getInfo(fingerprint : String)
            # GET /1.0/images/<fingerprint>
        end

        def getAliasesList : Array(String)
            # GET /1.0/images/aliases
        end

        def getAliasInfo(name : String)
            # GET /1.0/images/aliases/<name>
        end
    end

    class Operations
        setter lxd : LXDSocket?

        def getList : Array(String)
            # GET /1.0/operations
        end

        def getInfo(uuid : String)
            # GET /1.0/operations/<uuid>
        end

        def wait(uuid : String, timeout : Int? = nil)
            # GET /1.0/operations/<uuid>/wait
        end
    end

    class Profiles
        setter lxd : LXDSocket?

        def getList : Array(String)
            # GET /1.0/profiles
        end

        def getInfo(name : String)
            # GET /1.0/profiles/<name>
        end
    end

    class StoragePools
        setter lxd : LXDSocket?

        def getList : Array(String)
            # GET /1.0/storage-pools
        end

        def getInfo(name : String)
            # GET /1.0/storage-pools/<name>
        end

        def getResources(name : String)
            # GET /1.0/storage-pools/<name>/resources
        end

        def getVolumes(name : String)
            # GET /1.0/storage-pools/<name>/volumes
        end
    end

    class Cluster
        setter lxd : LXDSocket?

        def getInfo
            # GET /1.0/cluster
        end

        def getMembers : Array(String)
            # GET /1.0/cluster/members
        end

        def getMemberInfo(name : String)
            # GET /1.0/cluster/members/<name>
        end
    end
end
