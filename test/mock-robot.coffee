class MockRobot
    constructor: ->
        @name = "robot"
        @logger =
            info: ->
            warn: ->
        @commands = [
            "hubot a - does something a",
            "hubot b - does something b"
        ]
        if process.env.HUBOT_TEAMS_INITIAL_ADMINS
            authorizedUsers = {}
            for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                authorizedUsers[admin] = true
            @brain = 
                "authorizedUsers": authorizedUsers
                userForId: -> {}
                users: -> []
        else
            throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required")
module.exports = MockRobot
