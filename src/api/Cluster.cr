
# Class for the /1.0/cluster API portion

class Cluster
    setter lxd : LXDSocket?

    def get : Cluster # GET /1.0/cluster
        json = JSON.parse @lxd.not_nil!.get("/1.0/cluster").body
        @lxd.not_nil!.logger.debug json
        Cluster.from_json json["metadata"].to_json
    end

    def bootstrap(name : String) : String # PUT /1.0/cluster
        res = @lxd.not_nil!.put "/1.0/cluster", { "server_name" => name, "enabled" => true }.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    def join(server_name : String, server_address : String, cluster_address : String, cluster_certificate : String, cluster_password : String, member_config : Array(MemberConfig)) : String # PUT /1.0/cluster
        payload = {"server_name" => server_name, "server_address" => server_address, "cluster_address" => cluster_address, "cluster_certificate" => cluster_certificate, "cluster_password" => cluster_password, "member_config" => member_config}
        res = @lxd.not_nil!.put "/1.0/cluster", payload.to_json
        j = JSON.parse res.body
        j["type"] == "async" ? j["operation"].to_s : j["metadata"].to_s
    end

    def disable # PUT /1.0/cluster
        @lxd.not_nil!.put "/1.0/cluster", { "enabled" => false }.to_json
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
        Member.from_json json["metadata"].to_json
    end

    def renameMember(name : String, newName : String) # PUT /1.0/cluster/members/<name>
        payload = { "server_name" => newName }
        @lxd.not_nil!.put "/1.0/cluster/members/#{name.gsub("/1.0/cluster/members/","")}", payload.to_json
    end

    def deleteMemebr(name : String, force : Bool = false) : String # DELETE /1.0/cluster/members/<name>
        res = @lxd.not_nil!.delte "/1.0/cluster/members/#{name.gsub("/1.0/cluster/members/", "")}#{force ? "?force=1" : ""}"
        JSON.parse(res.body)["operation"].to_s
    end

    struct Cluster
        JSON.mapping(
            server_name: String,
            enabled: Bool,
            member_config: Array(MemberConfig)
        )
    end

    struct MemberConfig
        JSON.mapping(
            entity: String,
            name: String,
            key: String,
            value: String?,
            description: String?,
        )

        def initialize(@entity, @name, @key, @value)
        end
    end

    struct Member
        JSON.mapping(
            server_name: String,
            url: String,
            database: Bool,
            status: String,
            message: String
        )
    end
end