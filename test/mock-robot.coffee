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
            data: {}
            userForId: (id, options) ->
                user = {
                    id: "#{id}"
                    name: "a-hubot-user-name"
                }
                if options is null
                    return user
                else
                    for key of options
                        user[key] = options[key]
                return user

            users: -> []
            get: (key) ->
                if @data is undefined
                    return null
                for storedKey of @data
                    if key == storedKey
                        return @data[storedKey]
                return null
            set: (key, value) ->
                @data[key] = value
            on: (eventType, functionToRun) ->
                functionToRun()

    receive: (event) ->
        @brain.data["event"] = event
module.exports = MockRobot
