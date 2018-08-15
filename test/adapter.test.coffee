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
    
    describe 'Test Authorization Not Suppported Error', ->
        robot = null
        adapter = null
        event = null
        beforeEach ->
            process.env.HUBOT_TEAMS_INITIAL_ADMINS = 'an-1_20@em.ail,authorized_user@email.la'
            process.env.BOTBUILDER_APP_ID = 'botbuilder-app-id'
            process.env.BOTBUILDER_APP_PASSWORD = 'botbuilder-app-password'
            process.env.HUBOT_TEAMS_ENABLE_AUTH = 'true'

            robot = new MockRobot
            adapter = BotFrameworkAdapter.use(robot)
            robot.adapter = adapter
            adapter.connector.send = (payload, cb) ->
                robot.brain.set("payload", payload)

            event =
                type: 'message'
                text: '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> about it'
                agent: 'tests'
                source: 'msteams'
                entities: [
                    type: "mention"
                    text: "<at>Bot</at>"
                    mentioned:
                        id: "bot-id"
                        name: "bot-name"
                ,
                    type: "mention"
                    text: "<at>User</at>"
                    mentioned:
                        id: "user-id"
                        name: "user-name"
                ]
                attachments: []
                sourceEvent:
                    tenant:
                        id: "tenant-id"
                address:
                    conversation:
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: "eight888-four-4444-fore-twelve121212"
                        userPrincipalName: "user-UPN"
                    serviceUrl: 'url-serviceUrl/a-url'

        it 'should return authorization not supported error for non-Teams channels', ->
            # Setup
            event.source = 'authorization-not-supported-source'

            # Action
            expect(() ->
                adapter.handleActivity(event)
            ).to.not.throw()

            # Assert
            result = robot.brain.get("payload")
            expect(result).to.be.a('Array')
            expect(result.length).to.eql 1
            expect(result[0].text).to.eql "Authorization isn't supported for this channel"
            