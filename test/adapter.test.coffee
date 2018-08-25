chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, Robot, User } = require 'hubot'
BotFrameworkAdapter = require '../src/adapter'
MockRobot = require './mock-robot'


describe 'Main Adapter', ->
    describe 'Test Authorization Setup', ->
        beforeEach ->
            process.env.HUBOT_TEAMS_INITIAL_ADMINS = 'an-1_20@em.ail,authorized_user@email.la'
            process.env.HUBOT_TEAMS_ENABLE_AUTH = 'true'

        it 'should not set initial admins when auth enable is not set', ->
            # Setup
            delete process.env.HUBOT_TEAMS_ENABLE_AUTH
            robot = new MockRobot

            # Action
            expect(() ->
                adapter = BotFrameworkAdapter.use(robot)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("authorizedUsers")).to.be.null

        it 'should not set initial admins when auth is not enabled', ->
            # Setup
            process.env.HUBOT_TEAMS_ENABLE_AUTH = 'false'
            robot = new MockRobot

            # Action
            expect(() ->
                adapter = BotFrameworkAdapter.use(robot)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("authorizedUsers")).to.be.null
        
        it 'should throw error when auth is enabled and initial admins', ->
            # Setup
            delete process.env.HUBOT_TEAMS_INITIAL_ADMINS
            robot = new MockRobot

            # Action and Assert
            expect(() ->
                adapter = BotFrameworkAdapter.use(robot)
            ).to.throw()

        it 'should set initial admins when auth is enabled', ->
            # Setup
            robot = new MockRobot

            # Action
            expect(() ->
                adapter = BotFrameworkAdapter.use(robot)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("authorizedUsers")).to.eql {
                'an-1_20@em.ail': true
                'authorized_user@email.la': true
            }
