chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, Robot, User } = require 'hubot'
BotFrameworkAdapter = require '../src/adapter'
MockRobot = require './mock-robot'

describe 'Main Adapter', ->
    describe 'Test Auth', ->
        beforeEach ->
            process.env.HUBOT_TEAMS_INITIAL_ADMINS = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee,eight888-four-4444-fore-twelve121212'
            process.env.BOTBUILDER_APP_ID = 'botbuilder-app-id'
            process.env.BOTBUILDER_APP_PASSWORD = 'botbuilder-app-password'
            process.env.HUBOT_DEBUG_LEVEL = 'error'
            process.env.HUBOT_TEAMS_ENABLE_AUTH = 'true'

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

        it 'should set initial admins when auth is enabled', ->
            # Setup
            robot = new MockRobot

            # Action
            expect(() ->
                adapter = BotFrameworkAdapter.use(robot)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("authorizedUsers")).to.eql {
                'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee': true
                'eight888-four-4444-fore-twelve121212': true
            }
        
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
    
        it 'should allow messages from authorized users', ->
            # Setup
            robot = new MockRobot
            adapter = BotFrameworkAdapter.use(robot)
            robot.adapter = adapter
            adapter.connector.fetchMembers = (serviceUrl, teamId, callback) ->
                members = [
                    {
                        id: 'id-1'
                        objectId: 'aad-object-id-1'
                        name: 'user1 one'
                        givenName: 'user1'
                        surname: 'one'
                        email: 'one@user.one'
                        userPrincipalName: 'one@user.one'
                    },
                    {
                        id: 'user-id'
                        objectId: 'eight888-four-4444-fore-twelve121212'
                        name: 'user-name'
                        givenName: 'user-'
                        surname: 'name'
                        email: 'em@ai.l'
                        userPrincipalName: 'em@ai.l'
                    }
                ]
                callback false, members
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
                    serviceUrl: 'url-serviceUrl/a-url'

            # Action
            expect(() ->
                result = adapter.handleActivity(event)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("authorizedUsers")).to.eql {
                'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee': true
                'eight888-four-4444-fore-twelve121212': true
            }

        # it 'should overwrite the hubot command text to return an error message to unauthorized users', ->
        #     # Setup
        #     robot = new Robot('../../hubot-botframework', 'botframework', false, 'hubot')
        #     adapter = BotFrameworkAdapter.use(robot)
        #     adapter.connector.fetchMembers = (serviceUrl, teamId, callback) ->
        #         members = [
        #             {
        #                 id: 'id-1'
        #                 objectId: 'aad-object-id-1'
        #                 name: 'user1 one'
        #                 givenName: 'user1'
        #                 surname: 'one'
        #                 email: 'one@user.one'
        #                 userPrincipalName: 'one@user.one'
        #             },
        #             {
        #                 id: 'user-id'
        #                 objectId: 'eight888-four-4444-fore-twelve121212'
        #                 name: 'user-name'
        #                 givenName: 'user-'
        #                 surname: 'name'
        #                 email: 'em@ai.l'
        #                 userPrincipalName: 'em@ai.l'
        #             }
        #         ]
        #         callback false, members
        #     event =
        #         type: 'message'
        #         text: '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> about it'
        #         agent: 'tests'
        #         source: 'msteams'
        #         entities: [
        #             type: "mention"
        #             text: "<at>Bot</at>"
        #             mentioned:
        #                 id: "bot-id"
        #                 name: "bot-name"
        #         ,
        #             type: "mention"
        #             text: "<at>User</at>"
        #             mentioned:
        #                 id: "user-id"
        #                 name: "user-name"
        #         ]
        #         attachments: []
        #         sourceEvent:
        #             tenant:
        #                 id: "tenant-id"
        #         address:
        #             conversation:
        #                 id: "19:conversation-id"
        #             bot:
        #                 id: "bot-id"
        #             user:
        #                 id: "id-1"
        #                 name: "user1 one"
        #                 aadObjectId: "aad-object-id-1"
        #             serviceUrl: 'url-serviceUrl/a-url'

        #     # Action
        #     expect(() ->
        #         result = adapter.handleActivity(event)
        #     ).to.not.throw()

        #     console.log("=======================================")
        #     console.log(adapter)

        #     # Assert
        #     expect(robot.brain.get("authorizedUsers")).to.eql {
        #         'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee': true
        #         'eight888-four-4444-fore-twelve121212': true
        #     }