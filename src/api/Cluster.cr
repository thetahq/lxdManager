
# Class for the /1.0/cluster API portion

class Cluster
    setter lxd : LXDSocket?

    def get : Cluster # GET /1.0/cluster
        json = JSON.parse @lxd.not_nil!.get("/1.0/cluster").body
        @lxd.not_nil!.logger.debug json
        cl = json["metadata"]
        mem = [] of MemberConfig
        cl["member_config"].as_a.each { |m| mem << MemberConfig.new(m["entity"].to_s, m["name"].to_s, m["key"].to_s, m["value"].to_s) }
        Cluster.new(cl["server_name"].to_s, cl["enabled"].as_bool, mem, cl["description"].to_s)
    end

    def getMembers : Array(String) # GET /1.0/cluster/members
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/cluster/members").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |m| l << m.to_s }
        l
    end

    def getMember(name : String) : Member # GET /1.0/cluster/members/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/cluster/members/#{name.gsub("/1.0/cluster/members/","")}").body
        @lxd.not_nil!.logger.debug json
        mem = json["metadata"]
        Member.new(mem["server_name"].to_s, mem["url"].to_s, mem["database"].as_bool, mem["status"].to_s, mem["message"].to_s)
    end

    struct Cluster
        property server_name, enabled, member_config

        def initialize(@server_name : String, @enabled : Bool, @member_config : Array(MemberConfig))
        end
    end

    struct MemberConfig
        property entity, name, key, value, description

        def initialize(@entity : String, @name : String, @key : String, @value : String, @description : String)
        end
    end

    struct Member
        property server_name, url, database, status, message

        def initialize(@server_name : String, @url : String, @database : Bool, @status : String, @message : String)
        end
    end
end