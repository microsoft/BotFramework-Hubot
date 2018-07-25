chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, User } = require 'hubot'
MockRobot = require './mock-robot'
MicrosoftTeamsMiddleware = require '../src/msteams-middleware'

describe 'MicrosoftTeamsMiddleware', ->
    describe 'toReceivable', ->
        robot = null
        event = null
        chatMembers = null
        beforeEach ->
            delete process.env.HUBOT_OFFICE365_TENANT_FILTER
            process.env.HUBOT_TEAMS_INITIAL_ADMINS = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee,eight888-four-4444-fore-twelve121212'
            
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
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
            chatMembers = [
                {
                    id: 'user-id',
                    objectId: 'eight888-four-4444-fore-twelve121212',
                    name: 'user-name',
                    givenName: 'user-',
                    surname: 'name',
                    email: 'em@ai.l',
                    userPrincipalName: 'em@ai.l'
                },
                {
                    id: 'user2-id',
                    objectId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                    name: 'user2 two',
                    givenName: 'user2',
                    surname: 'two',
                    email: 'em@ai.l2',
                    userPrincipalName: 'em@ai.l2'
                }
            ]

        it 'should allow messages without tenant id when tenant filter is empty', ->
            # Setup
            delete event.sourceEvent
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(receivable).to.be.a('Object')

        it 'should allow messages with tenant id when tenant filter is empty', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
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
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
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
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
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
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
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
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
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
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(receivable.text).to.equal(event.text)


        it 'should replace all @ mentions to the bot with the bot name', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell #{event.address.user.aadObjectId} about it"
            expect(receivable.text).to.equal(expected)
        
        it 'should replace all @ mentions to chat users with their aad object id', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)
            event.text = '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> and <at>User2</at> about it'
            user2 = 
                id: 'user2-id',
                objectId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                name: 'user2-name',
                givenName: 'user2-',
                surname: 'name2',
                email: 'em@ai.l2',
                userPrincipalName: 'em@ai.l2'

            event.entities.push(
                type: "mention"
                text: "<at>User2</at>"
                mentioned:
                    id: user2.id
                    name: user2.name
            )
            chatMembers.push(
                user2
            )

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell #{event.address.user.aadObjectId} and #{user2.objectId} about it"
            expect(receivable.text).to.equal(expected)

        it 'should replace @ mentions even when entities is not an array', ->
            # Setup
            event.entities = event.entities[0]
            event.text = "<at>Bot</at> do something <at>Bot</at>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name}"
            expect(receivable.text).to.equal(expected)
        
        it 'should replace @ mentions to non-chat roster users with their name', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)
            event.entities[1] =
                type: "mention"
                text: "<at>User</at>"
                mentioned:
                    id: "not-a-valid-user-id"
                    name: "not-a-user"

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell #{event.entities[1].mentioned.name} about it"
            expect(receivable.text).to.equal(expected)

            

        it 'should prepend bot name in 1:1 chats', ->
            # Setup
            event.address.conversation.id = event.address.user.id
            event.text = 'do something <at>Bot</at> and tell <at>User</at> about it'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot)

            # Action
            receivable = null
            expect(() ->
                receivable = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell #{event.address.user.aadObjectId} about it"
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
        
        it 'should construct card for command list', ->
            # Setup
            message = "MS Teams Command list card"
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
                    {
                        "content": {
                            "text": """hubot a - does something a
                            hubot b - does something b"""
                            "title": "Hubot commands"
                            "buttons": [
                                {
                                    "title": "a"
                                    "type": "imBack"
                                    "value": "a"
                                },
                                {
                                    "title": "b"
                                    "type": "imBack"
                                    "value": "b"
                                }
                            ]
                        }
                        "contentType": "application/vnd.microsoft.card.hero"
                    }
                ]
                address: context.user.activity.address
            ]
        
            expect(sendable).to.deep.equal(expected)
