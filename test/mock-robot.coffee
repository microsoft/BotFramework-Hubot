class MockRobot
    constructor: ->
        @name = "robot"
        @logger =
            info: ->
            warn: ->
        @brain =
            userForId: -> {}
            users: -> []
module.exports = MockRobot
