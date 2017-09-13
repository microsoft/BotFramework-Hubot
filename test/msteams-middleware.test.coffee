chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, User } = require 'hubot'
MockRobot = require './mock-robot'
MicrosoftTeamsMiddleware = require '../src/msteams-middleware'

describe 'MicrosoftTeamsMiddleware', ->
    describe 'toReceivable', ->
        robot = null
        event = null
        beforeEach ->
            delete process.env.HUBOT_OFFICE365_TENANT_FILTER
            robot = new MockRobot
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

        it 'should allow messages without tenant id when tenant filter is empty', ->
            # Setup
            delete event.sourceEvent
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.a('Object')

        it 'should allow messages with tenant id when tenant filter is empty', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.a('Object')

        it 'should allow messages from allowed tenant ids', ->
            # Setup
            process.env.HUBOT_OFFICE365_TENANT_FILTER = event.sourceEvent.tenant.id
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.a('Object')

        it 'should block messages from unallowed tenant ids', ->
            # Setup
            process.env.HUBOT_OFFICE365_TENANT_FILTER = event.sourceEvent.tenant.id
            event.sourceEvent.tenant.id = "different-tenant-id"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.null

        it 'return generic message when appropriate type is not found', ->
            # Setup
            event.type = 'typing'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.not.null

        it 'should work when activity text is an object', ->
            # Setup
            event.text = event
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable.text).to.equal(event)

        it 'should work when mentions not provided', ->
            # Setup
            delete event.entities
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expect(receivable.text).to.equal(event.text)


        it 'should replace all @ mentions', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell user-name about it"
            expect(receivable.text).to.equal(expected)

        it 'should replace at mentions even when entities is not an array', ->
            # Setup
            event.entities = event.entities[0]
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell <at>User</at> about it"
            expect(receivable.text).to.equal(expected)

        it 'should prepend bot name in 1:1 chats', ->
            # Setup
            event.address.conversation.id = event.address.user.id
            event.text = 'do something <at>Bot</at> and tell <at>User</at> about it'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event)
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
            message = "message"

        it 'should create message object for string messages', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                entities: []
                text: message
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should not alter non-string messages', ->
            # Setup
            message =
              type: "some message type"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                message
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert slack @ mentions with only id', ->
            # Setup
            robot.brain.users = () ->
                return 1234:
                    id: '1234'
                    name:'user'

            message = "<@1234> Hello! <@1234>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                entities: [
                    type: 'mention',
                    text: '<at>user</at>'
                    mentioned:
                      id: '1234',
                      name: 'user'
                ,
                    type: 'mention',
                    text: '<at>user</at>'
                    mentioned:
                      id: '1234',
                      name: 'user'
                ]
                text: '<at>user</at> Hello! <at>user</at>'
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert slack @ mentions with only id and display', ->
            # Setup
            robot.brain.users = () ->
                return 1234:
                    id: '1234'
                    name:'user'

            message = "<@1234|mention text> Hello! <@1234|different>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                entities: [
                    type: 'mention',
                    text: '<at>mention text</at>'
                    mentioned:
                      id: '1234',
                      name: 'user'
                ,
                    type: 'mention',
                    text: '<at>different</at>'
                    mentioned:
                      id: '1234',
                      name: 'user'
                ]
                text: '<at>mention text</at> Hello! <at>different</at>'
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert slack @ mentions with unfound user', ->
            # Setup
            message = "<@1234> Hello! <@1234|different>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                entities: [
                    type: 'mention',
                    text: '<at>1234</at>'
                    mentioned:
                      id: '1234',
                      name: '1234'
                ,
                    type: 'mention',
                    text: '<at>different</at>'
                    mentioned:
                      id: '1234',
                      name: '1234'
                ]
                text: '<at>1234</at> Hello! <at>different</at>'
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert images', ->
            # Setup
            message = "http://test.com/thisisanimage.jpg"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                text: "http://test.com/thisisanimage.html"
                entities: []
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)