class MockRobot
    constructor: ->
        @name = "robot"
        @logger =
            info: ->
            warn: ->
        @commands = [
            "hubot a - does something a"
            "hubot b - does something b"
        ]
        @brain =
            userForId: -> {}
            users: -> []
            get: (key) ->
                if @data is undefined
                    return null
                for storedKey of @data
                    if key == storedKey
                        return @data[storedKey]
                return null

        if process.env.HUBOT_TEAMS_ENABLE_AUTH == 'true'
            if process.env.HUBOT_TEAMS_INITIAL_ADMINS
                @brain.data = {}
                authorizedUsers = {}
                for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                    authorizedUsers[admin] = true
                @brain.data["authorizedUsers"] = authorizedUsers
                    
            else
                throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required")
    receive: -> {}
module.exports = MockRobot
