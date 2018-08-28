chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, User } = require 'hubot'
MockRobot = require './mock-robot'
SkypeMiddleware = require '../src/skype-middleware'

describe 'SkypeMiddleware', ->
    describe 'toReceivable', ->
        robot = null
        event = null
        beforeEach ->
            robot = new MockRobot
            event =
                type: 'message'
                text: '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> about it'
                agent: 'tests'
                source: 'skype'
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

        it 'return generic message when appropriate type is not found', ->
            # Setup
            event.type = 'typing'
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.not.null

        it 'should work when activity text is an object', ->
            # Setup
            event.text = event
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable.text).to.equal(event)

        it 'should work when mentions not provided', ->
            # Setup
            delete event.entities
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable.text).to.equal(event.text)

        it 'should replace all @ mentions', ->
            # Setup
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell user-name about it"
            expect(receivable.text).to.equal(expected)

        it 'should replace at mentions even when entities is not an array', ->
            # Setup
            event.entities = event.entities[0]
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell <at>User</at> about it"
            expect(receivable.text).to.equal(expected)

        it 'should prepend bot name in 1:1 chats', ->
            # Setup
            event.address.conversation.id = event.address.user.id
            event.text = 'do something <at>Bot</at> and tell <at>User</at> about it'
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = skypeMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell user-name about it"
            expect(receivable.text).to.equal(expected)

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
                        text: '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> about it'
                        agent: 'tests'
                        source: 'skype'
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
            message = "message"

        it 'should create message object for string messages', ->
            # Setup
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = skypeMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                text: message
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should not alter non-string messages', ->
            # Setup
            message =
              type: "some message type"
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = skypeMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                message
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert images', ->
            # Setup
            message = "http://test.com/thisisanimage.jpg"
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = skypeMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                attachments: [
                  contentUrl: message,
                  name: 'thisisanimage',
                  contentType: 'image/jpg'
                ]
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should not convert other links', ->
            # Setup
            message = "http://test.com/thisisanimage.html"
            skypeMiddleware = new SkypeMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = skypeMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                text: "http://test.com/thisisanimage.html"
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)