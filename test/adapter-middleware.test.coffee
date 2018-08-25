chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, User } = require 'hubot'
MockRobot = require './mock-robot'
{ BaseMiddleware, TextMiddleware, middlewareFor } = require '../src/adapter-middleware'
BotBuilderTeams = require('./mock-botbuilder-teams')

describe 'middlewareFor', ->
    it 'should return Middleware for null', ->
        middleware = middlewareFor(null)
        expect(middleware).to.be.not.null

    it 'should return Middleware for any string', ->
        middleware = middlewareFor("null")
        expect(middleware).to.be.not.null

    it 'should return Middleware for proper channel', ->
        middleware = middlewareFor("msteams")
        expect(middleware).to.be.not.null
        

describe 'BaseMiddleware', ->
    describe 'toReceivable', ->
        robot = null
        event = null
        beforeEach ->
            robot = new MockRobot
            event =
                type: 'message'
                text: 'Bot do something and tell User about it'
                agent: 'tests'
                source: '*'
                address:
                    conversation:
                        id: "conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"

        it 'should throw', ->
            middleware = new BaseMiddleware(robot)
            expect(() ->
                middleware.toReceivable(event)
            ).to.throw()

    describe 'toSendable', ->
        robot = null
        message = null
        context = null
        beforeEach ->
            robot = new MockRobot
            context =
                user:
                    id: 'user-id'
                    name: 'user-name'
                    activity:
                        type: 'message'
                        text: 'Bot do something and tell User about it'
                        agent: 'tests'
                        source: '*'
                        address:
                            conversation:
                                id: "conversation-id"
                            bot:
                                id: "bot-id"
                            user:
                                id: "user-id"
                                name: "user-name"
            message = "message"

        it 'should throw', ->
            middleware = new BaseMiddleware(robot)
            expect(() ->
                middleware.toSendable(context, message)
            ).to.throw()

describe 'TextMiddleware', ->
    describe 'handleInvoke', ->
        robot = null
        event = null
        connector = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        beforeEach ->
            robot = new MockRobot
            event =
                type: 'invoke'
                text: 'Bot do something and tell User about it'
                agent: 'tests'
                source: '*'
                address:
                    conversation:
                        id: "conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
            connector = 
                send: () -> {}

        it 'should return null', ->
            # Setup
            middleware = new TextMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = middleware.handleInvoke(event, connector)
            ).to.not.throw()

            # Assert
            expect(result).to.be.null

    describe 'toReceivable', ->
        robot = null
        event = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        beforeEach ->
            robot = new MockRobot
            event =
                type: 'message'
                text: 'Bot do something and tell User about it'
                agent: 'tests'
                source: '*'
                address:
                    conversation:
                        id: "conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"

        it 'return generic message when appropriate type is not found', ->
            # Setup
            event.type = 'typing'
            middleware = new TextMiddleware(robot, appId, appPassword)

            # Action
            receivable = null
            expect(() ->
                receivable = middleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.not.null

        it 'return message when type is message', ->
            # Setup
            middleware = new TextMiddleware(robot, appId, appPassword)

            # Action
            receivable = null
            expect(() ->
                receivable = middleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.not.null

    describe 'toSendable', ->
        robot = null
        message = null
        context = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        beforeEach ->
            robot = new MockRobot
            context =
                user:
                    id: 'user-id'
                    name: 'user-name'
                    activity:
                        type: 'message'
                        text: 'Bot do something and tell User about it'
                        agent: 'tests'
                        source: '*'
                        address:
                            conversation:
                                id: "conversation-id"
                            bot:
                                id: "bot-id"
                            user:
                                id: "user-id"
                                name: "user-name"
            message = "message"

        it 'should create message object for string messages', ->
            # Setup
            middleware = new TextMiddleware(robot, appId, appPassword)

            # Action
            sendable = null
            expect(() ->
                sendable = middleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = {
                type: 'message'
                text: message
                address: context.user.activity.address
            }
            expect(sendable).to.deep.equal(expected)

        it 'should not alter non-string messages', ->
            # Setup
            message =
              type: "some message type"
            middleware = new TextMiddleware(robot, appId, appPassword)

            # Action
            sendable = null
            expect(() ->
                sendable = middleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = message
            expect(sendable).to.deep.equal(expected)
    
    describe 'maybeReceive', ->
        robot = null
        middleware = null
        authEnabled = true
        connector = null
        event = null

        beforeEach ->
            robot = new MockRobot
            middleware = new TextMiddleware(robot, 'a-app-id', 'a-app-password')
            connector =
                send: (payload, cb) ->
                    robot.brain.set("payload", payload)
            authEnabled = true
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

        it 'should return authorization not supported error when auth is enabled', ->
            # Setup

            # Action
            expect(() ->
                middleware.maybeReceive(event, connector, authEnabled)
            ).to.not.throw()

            # Assert
            resultEvent = robot.brain.get("event")
            expect(resultEvent).to.be.null
            resultPayload = robot.brain.get("payload")
            expect(resultPayload).to.be.a('Array')
            expect(resultPayload.length).to.eql 1
            expect(resultPayload[0].text).to.eql "Authorization isn't supported for this channel"

        it 'should work when auth is not enabled', ->
            # Setup
            authEnabled = false

            # Action
            expect(() ->
                middleware.maybeReceive(event, connector, authEnabled)
            ).to.not.throw()

            # Assert
            resultEvent = robot.brain.get("event")
            expect(resultEvent).to.not.be.null
            expect(resultEvent).to.be.a('Object')
            resultPayload = robot.brain.get("payload")
            expect(resultPayload).to.be.null

    describe 'constructErrorResponse', ->
        it 'return a proper payload with the text of the error', ->
            # Setup
            robot = new MockRobot
            middleware = new TextMiddleware(robot, 'a-app-id', 'a-app-password')
            event =
                type: 'message'
                text: 'Bot do something and tell User about it'
                agent: 'tests'
                source: '*'
                address:
                    conversation:
                        id: "conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"

            # Action
            result = null
            expect(() ->
                result = middleware.constructErrorResponse(event, "an error message")
            ).to.not.throw()

            # Assert
            expect(result).to.eql {
                type: 'message'
                text: 'an error message'
                address:
                    conversation:
                        id: "conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
            }
    
    describe 'send', ->
        robot = null
        middleware = null
        connector = null
        payload = null
        cb = () -> {}

        beforeEach ->
            robot = new MockRobot
            middleware = new TextMiddleware(robot, 'a-app-id', 'a-app-password')
            connector = new BotBuilderTeams.TeamsChatConnector({
                appId: 'a-app-id'
                appPassword: 'a-app-password'
            })
            connector.send = (payload, cb) ->
                robot.brain.set("payload", payload)

            payload = {
                type: 'message'
                text: ""
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: 'a-app-id'
                    user:
                        id: "user-id"
                        name: "user-name"
            }

        it 'should package non-array payload in array before sending', ->
            # Setup
            expected = [{
                type: 'message'
                text: ""
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: 'a-app-id'
                    user:
                        id: "user-id"
                        name: "user-name"
            }]

            # Action
            expect(() ->
                middleware.send(connector, payload)
            ).to.not.throw()

            # Assert
            result = robot.brain.get("payload")
            expect(result).to.deep.eql(expected)


        it 'should pass payload array through unchanged', ->
            # Setup
            payload = [payload]
            expected = [{
                type: 'message'
                text: ""
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: 'a-app-id'
                    user:
                        id: "user-id"
                        name: "user-name"
            }]

            # Action
            expect(() ->
                middleware.send(connector, payload)
            ).to.not.throw()

            # Assert
            result = robot.brain.get("payload")
            expect(result).to.deep.eql(expected)
