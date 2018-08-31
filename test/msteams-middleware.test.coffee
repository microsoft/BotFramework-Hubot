chai = require 'chai'
expect = chai.expect
{ TextMessage, Message, User } = require 'hubot'
rewiremock = require('rewiremock/node').default
MockRobot = require './mock-robot'
MicrosoftTeamsMiddleware = require '../src/msteams-middleware'

describe 'MicrosoftTeamsMiddleware', ->
    describe 'handleInvoke', ->
        rewiremock('botbuilder-teams').with(require('./mock-botbuilder-teams'))
        BotBuilderTeams = null
        robot = null
        event = null
        options = null
        teamsChatConnector = null
        authEnabled = false
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        cb = () -> {}

        beforeEach ->
            rewiremock.enable()
            BotBuilderTeams = require 'botbuilder-teams'
            MicrosoftTeamsMiddleware = require '../src/msteams-middleware'

            robot = new MockRobot
            options = {
                appId: 'botframework-app-id'
                appPassword: 'botframework-app-password'
            }
            teamsChatConnector = new BotBuilderTeams.TeamsChatConnector(options)
            teamsChatConnector.send = (payload) ->
                robot.brain.set("payload", payload)

            event =
                type: 'invoke'
                text: '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> about it'
                value:
                    hubotMessage: 'gho list (teams|repos|members)'
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
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
                        userPrincipalName: 'em@ai.l'
        
        afterEach ->
            rewiremock.disable()

        it 'should send user input card for specific queries', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.handleInvoke(event, teamsChatConnector)
            ).to.not.throw()

            # Assert
            expect(result).to.be.null
            response = robot.brain.get("payload")
            expect(response).to.be.a('Array')
            expect(response.length).to.eql(2)
        
        it 'should return event to handle', ->
            # Setup
            event.value.hubotMessage = "gho list public repos"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.handleInvoke(event, teamsChatConnector)
            ).to.not.throw()

            # Assert
            expect(result).to.not.be.null
            expect(result).to.be.a('Object')
            response = robot.brain.get("payload")
            expect(response).to.be.null

    describe 'toReceivable', ->
        rewiremock('botbuilder-teams').with(require('./mock-botbuilder-teams'))
        BotBuilderTeams = null
        robot = null
        event = null
        options = null
        teamsChatConnector = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
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

        beforeEach ->
            rewiremock.enable()
            MicrosoftTeamsMiddleware = require '../src/msteams-middleware'
            BotBuilderTeams = require 'botbuilder-teams'

            delete process.env.HUBOT_OFFICE365_TENANT_FILTER
            robot = new MockRobot
            options = {
                appId: 'botframework-app-id'
                appPassword: 'botframework-app-password'
            }
            teamsChatConnector = new BotBuilderTeams.TeamsChatConnector(options)
            authEnabled = false
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
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
                        userPrincipalName: 'em@ai.l'
        
        afterEach ->
            rewiremock.disable()

        it 'should allow messages without tenant id when tenant filter is empty', ->
            # Setup
            delete event.sourceEvent
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.a('Object')

        it 'should allow messages with tenant id when tenant filter is empty', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.a('Object')

        it 'should allow messages from allowed tenant ids', ->
            # Setup
            process.env.HUBOT_OFFICE365_TENANT_FILTER = event.sourceEvent.tenant.id
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.a('Object')

        it 'should block messages from unallowed tenant ids', ->
            # Setup
            process.env.HUBOT_OFFICE365_TENANT_FILTER = event.sourceEvent.tenant.id
            event.sourceEvent.tenant.id = "different-tenant-id"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.null

        it 'return generic message when appropriate type is not found', ->
            # Setup
            event.type = 'typing'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.not.null
        
        # Test when message is from follow up button
        it 'should construct query when activity value is defined (message from button click)', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            delete event.text
            prefix = "gho add (members|repos) <members|repos> to team <team name>"
            event.value = {
                "queryPrefix": prefix
                "#{prefix} - query0": "hubot gho add "
                "#{prefix} - query1": " "
                "#{prefix} - query2": " to team "
                "#{prefix} - input0": "members"
                "#{prefix} - input1": "a-member"
                "#{prefix} - input2": "some-team"
            }

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result).to.be.a('Object')
            expect(result.text).to.eql "#{robot.name} gho add members a-member to team some-team"

        it 'should work when activity text is an object', ->
            # Setup
            event.text = event
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result.text).to.equal(event)

        it 'should work when mentions not provided', ->
            # Setup
            delete event.entities
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expect(result.text).to.equal(event.text)

        it 'should replace all @ mentions to the bot with the bot name', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell \
                        #{event.address.user.userPrincipalName} about it"
            expect(result.text).to.equal(expected)
        
        it 'should replace all @ mentions to chat users with their user principal name', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            event.text = '<at>Bot</at> do something <at>Bot</at> and tell <at>User</at> \
                        and <at>User2</at> about it'
            event.entities.push(
                type: "mention"
                text: "<at>User2</at>"
                mentioned:
                    id: 'user2-id'
                    name: 'user2 two'
            )

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell \
                        #{event.address.user.userPrincipalName} and em@ai.l2 about it"
            expect(result.text).to.equal(expected)

        it 'should replace @ mentions even when entities is not an array', ->
            # Setup
            event.entities = event.entities[0]
            event.text = "<at>Bot</at> do something <at>Bot</at>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name}"
            expect(result.text).to.equal(expected)
        
        it 'should replace @ mentions to non-chat roster users with their name', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            event.entities[1] =
                type: "mention"
                text: "<at>User</at>"
                mentioned:
                    id: "not-a-valid-user-id"
                    name: "not-a-user"

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell \
                        #{event.entities[1].mentioned.name} about it"
            expect(result.text).to.equal(expected)

        it 'should trim whitespace before and after text', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            event.text = "   #{event.text}      \n   "

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell \
                        #{event.address.user.userPrincipalName} about it"
            expect(result.text).to.equal(expected)

        it 'should prepend bot name in 1:1 chats when name is not there', ->
            # Setup
            event.address.conversation.conversationType = 'personal'
            delete event.address.conversation.isGroup
            event.text = 'do something <at>Bot</at> and tell <at>User</at> about it'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.toReceivable(event, chatMembers)
            ).to.not.throw()

            # Assert
            expected = "#{robot.name} do something #{robot.name} and tell \
                        #{event.address.user.userPrincipalName} about it"
            expect(result.text).to.equal(expected)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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

        # Should construct response card for specific queries
        it 'should construct response card for specific queries', ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            context.user.activity.text = 'hubot gho list teams'

            # Action
            sendable = null
            expect(() ->
                sendable = teamsMiddleware.toSendable(context, message)
            ).to.not.throw()

            # Verify
            expectedResponseCard = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "body": [
                        {
                            'type': 'TextBlock'
                            'text': "#{context.user.activity.text}"
                            'speak': "<s>#{context.user.activity.text}</s>"
                            'weight': 'bolder'
                            'size': 'large'
                        },
                        {
                            'type': 'TextBlock'
                            'text': "#{message}"
                            'speak': "<s>#{message}</s>"
                        }
                    ]
                    "actions": [
                        {
                            "title": "gho list"
                            "type": "Action.ShowCard"
                            "card": {
                                "type": "AdaptiveCard"
                                "body": [
                                    {
                                        'type': 'TextBlock'
                                        'text': "gho list"
                                        'speak': "<s>gho list</s>"
                                        'weight': 'bolder'
                                        'size': 'large'
                                    },
                                    {
                                        'type': 'TextBlock'
                                        'text': 'List what?'
                                        'speak': "<s>List what?</s>"
                                    },
                                    {
                                        "type": "Input.ChoiceSet"
                                        "id": "gho list (teams|repos|members) - input0"
                                        "style": "compact"
                                        "value": "teams"
                                        "choices": [
                                            {
                                                "title": "teams"
                                                "value": "teams"
                                            },
                                            {
                                                "title": "repos"
                                                "value": "repos"
                                            },
                                            {
                                                "title": "members"
                                                "value": "members"
                                            }
                                        ]
                                    }
                                ],
                                'actions': [
                                    {
                                        'type': 'Action.Submit'
                                        'title': 'Submit'
                                        'speak': '<s>Submit</s>'
                                        'data': {
                                            'queryPrefix': "gho list (teams|repos|members)"
                                            "gho list (teams|repos|members) - query0": 'hubot gho list '
                                        }
                                    }
                                ]
                            }
                        },
                        {
                            'type': 'Action.Submit'
                            'title': 'gho list public repos'
                            'data': {
                                'queryPrefix': "gho list public repos"
                                "gho list public repos - query0": 'hubot gho list public repos'
                            }
                        }
                    ]
                }
            }
            expected = [
                type: 'typing',
                address: context.user.activity.address
            ,
                type: 'message'
                address: context.user.activity.address
                attachments: [
                    expectedResponseCard
                ]
            ]

            expect(sendable).to.deep.equal(expected)

        it 'should convert slack @ mentions with only id', ->
            # Setup
            robot.brain.users = () ->
                return 1234:
                    id: '1234'
                    name:'user'

            message = "<@1234> Hello! <@1234>"
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)

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

        it "should escape < when message starts with 'hubot' (such as for hubot help)", ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            message = "hubot command <blah> - this message has < symbols in multiple places <"

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
                text: "hubot command &lt;blah> - this message has &lt; symbols in multiple places &lt;"
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

        it "should replace \\n with <br/> in text to render correctly in Teams", ->
            # Setup
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            message = "some \nmessage"

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
                text: "some <br/>message"
                address: context.user.activity.address
            ]

            expect(sendable).to.deep.equal(expected)

    describe 'maybeReceive', ->
        rewiremock('botbuilder-teams').with(require('./mock-botbuilder-teams'))
        BotBuilderTeams = null
        robot = null
        teamsMiddleware = null
        connector = null
        authEnabled = true
        event = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'

        beforeEach ->
            rewiremock.enable()
            MicrosoftTeamsMiddleware = require '../src/msteams-middleware'
            BotBuilderTeams = require 'botbuilder-teams'

            robot = new MockRobot
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            connector = new BotBuilderTeams.TeamsChatConnector({
                appId: 'a-app-id'
                appPassword: 'a-app-password'
            })
            connector.send = (payload, cb) ->
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
                attachments: []
                sourceEvent:
                    tenant:
                        id: "tenant-id"
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
                        userPrincipalName: 'em@ai.l'

        afterEach ->
            rewiremock.disable()

        # Hubot receives message when auth disabled
        it 'hubot receives message when auth is disabled', ->
            # Setup
            authEnabled = false

            # Action
            expect(() ->
                teamsMiddleware.maybeReceive(event, connector, authEnabled)
            ).to.not.throw()

            # Assert
            resultEvent = robot.brain.get("event")
            expect(resultEvent).to.not.be.null
            expect(resultEvent).to.be.a('Object')

        # Hubot receives message when auth enabled and user is authorized
        it 'hubot receives message when auth is enabled and user is authorized', ->
            # Setup
            robot.brain.set("authorizedUsers", {
                'an-1_20@em.ail': true
                'em@ai.l': false
                'user-UPN': true
            })

            # Action
            expect(() ->
                teamsMiddleware.maybeReceive(event, connector, authEnabled)
            ).to.not.throw()

            # Assert
            resultEvent = robot.brain.get("event")
            expect(resultEvent).to.not.be.null
            expect(resultEvent).to.be.a('Object')

        # Hubot sends error resposne when auth enabled and user is not authorized
        it 'hubot sends error response when auth is enabled and user is not authorized', (done) ->
            # Setup
            robot.brain.set("authorizedUsers", {
                'an-1_20@em.ail': true
                'user-UPN': true
            })
            expected = [{
                type: 'typing'
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
                        userPrincipalName: 'em@ai.l'
            },
            {
                type: 'message'
                text: "You are not authorized to send commands to hubot. To gain access, \
                        talk to your admins:\r\n- an-1_20@em.ail\r\n- user-UPN"
                address:
                    conversation:
                        isGroup: 'true'
                        conversationType: 'channel'
                        id: "19:conversation-id"
                    bot:
                        id: "bot-id"
                    user:
                        id: "user-id"
                        name: "user-name"
                        aadObjectId: 'eight888-four-4444-fore-twelve121212'
                        userPrincipalName: 'em@ai.l'
            }]

            # Action
            expect(() ->
                teamsMiddleware.maybeReceive(event, connector, authEnabled)
            ).to.not.throw()

            # Assert
            setTimeout((robot, expected) ->
                result = robot.brain.get("payload")
                expect(result).to.not.be.null
                expect(result).to.be.a('Array')
                expect(result).to.deep.eql(expected)
                done()
            , 200, robot, expected)

    describe 'send', ->
        rewiremock('botbuilder-teams').with(require('./mock-botbuilder-teams'))
        BotBuilderTeams = null
        robot = null
        teamsMiddleware = null
        connector = null
        payload = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        cb = () -> {}

        beforeEach ->
            rewiremock.enable()
            MicrosoftTeamsMiddleware = require '../src/msteams-middleware'
            BotBuilderTeams = require 'botbuilder-teams'

            robot = new MockRobot
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            connector = new BotBuilderTeams.TeamsChatConnector({
                appId: 'a-app-id'
                appPassword: 'a-app-password'
            })
            connector.send = (payload, cb) ->
                robot.brain.set("payload", payload)

            payload = [{
                type: 'typing'
                address:
                    id: 'address-id'
                    channelId: 'channel-id'
                    user:
                        id: 'user-id'
                        name: 'user-name'
                        aadObjectId: 'user-aadobject-id'
                        userPrincipalName: "user-UPN"
                    conversation:
                        conversationType: 'personal'
                        id: 'conversation-id'
                    bot:
                        id: 'bot-id'
                        name: 'bot-name'
                    serviceUrl: 'service-url'
            },
            {
                type: 'message'
                text: "a message"
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]
        
        afterEach ->
            rewiremock.disable()
        
        it 'should set justReceivedResponse on first message received and store response', ->
            # Setup

            # Action
            expect(() ->
                teamsMiddleware.send(connector, payload)
            ).to.not.throw()

            # Assert
            expect(robot.brain.get("justReceivedResponse")).to.be.true
            expect(robot.brain.get("teamsResponse")).to.not.be.null

        it 'should send correct response when one response is sent', (done) ->
            # Setup
            expected = [{
                type: 'typing'
                address:
                    id: 'address-id'
                    channelId: 'channel-id'
                    user:
                        id: 'user-id'
                        name: 'user-name'
                        aadObjectId: 'user-aadobject-id'
                        userPrincipalName: "user-UPN"
                    conversation:
                        conversationType: 'personal'
                        id: 'conversation-id'
                    bot:
                        id: 'bot-id'
                        name: 'bot-name'
                    serviceUrl: 'service-url'
            },
            {
                type: 'message'
                text: "a message"
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]

            # Action
            expect(() ->
                teamsMiddleware.send(connector, payload)
            ).to.not.throw()

            # Assert, after 200ms to allow the payload to be "sent"
            setTimeout((robot, expected) ->
                result = robot.brain.get("payload")
                expect(result).to.deep.eql(expected)
                done()
            , 200, robot, expected)

        it 'should send combined responses for messages received within 100ms', ->
            # Setup
            payload2 = [{
                type: 'typing'
                address:
                    id: 'address-id'
                    channelId: 'channel-id'
                    user:
                        id: 'user-id'
                        name: 'user-name'
                        aadObjectId: 'user-aadobject-id'
                        userPrincipalName: "user-UPN"
                    conversation:
                        conversationType: 'personal'
                        id: 'conversation-id'
                    bot:
                        id: 'bot-id'
                        name: 'bot-name'
                    serviceUrl: 'service-url'
            },
            {
                type: 'message'
                text: "another message"
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]
            expected = [{
                type: 'typing'
                address:
                    id: 'address-id'
                    channelId: 'channel-id'
                    user:
                        id: 'user-id'
                        name: 'user-name'
                        aadObjectId: 'user-aadobject-id'
                        userPrincipalName: "user-UPN"
                    conversation:
                        conversationType: 'personal'
                        id: 'conversation-id'
                    bot:
                        id: 'bot-id'
                        name: 'bot-name'
                    serviceUrl: 'service-url'
            },
            {
                type: 'message'
                text: "a message\nanother message"
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]

            # Action
            expect(() ->
                teamsMiddleware.send(connector, payload)
            ).to.not.throw()
            expect(() ->
                teamsMiddleware.send(connector, payload2)
            ).to.not.throw()

            # Assert, after 200ms to allow the payload to be "sent"
            setTimeout((robot, expected) ->
                result = robot.brain.get("payload")
                expect(result).to.deep.eql(expected)
                done()
            , 200, robot, expected)

    describe 'sendPayload', ->
        rewiremock('botbuilder-teams').with(require('./mock-botbuilder-teams'))
        BotBuilderTeams = null
        robot = null
        teamsMiddleware = null
        connector = null
        payload = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'
        cb = () -> {}

        beforeEach ->
            rewiremock.enable()
            MicrosoftTeamsMiddleware = require '../src/msteams-middleware'
            BotBuilderTeams = require 'botbuilder-teams'

            robot = new MockRobot
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }
        
        afterEach ->
            rewiremock.disable()

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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]

            # Action
            expect(() ->
                teamsMiddleware.sendPayload(connector, payload)
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
                        aadObjectId: "user-aad-id"
                        userPrincipalName: "user-UPN"
            }]

            # Action
            expect(() ->
                teamsMiddleware.sendPayload(connector, payload)
            ).to.not.throw()

            # Assert
            result = robot.brain.get("payload")
            expect(result).to.deep.eql(expected)
    
    describe 'combineResponses', ->
        robot = null
        teamsMiddleware = null
        storedPayload = null
        newPayload = null
        expected = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'

        beforeEach ->
            robot = new MockRobot
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            storedPayload = [
                {
                    type: 'typing'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                },
                {
                    type: 'message'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                    entities: [
                        {
                            field: 'some entity'
                        }
                    ]
                }
            ]
            newPayload = [
                {
                    type: 'typing'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                },
                {
                    type: 'message'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                    entities: [
                        {
                            field: 'another entitiy'
                        }
                    ]
                }
            ]
            expected = [
                {
                    type: 'typing'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                },
                {
                    type: 'message'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                    entities: [
                        {
                            field: 'some entity'
                        }
                    ]
                }
            ]

        it 'should not change stored payload text when both stored and new payload text is undefined', ->
            # Setup

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should not change stored payload text when new payload text is undefined', ->
            # Setup
            storedPayload[1].text = 'this is some stored text'
            expected[1].text = 'this is some stored text'

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should add new payload text when stored payload text is undefined', ->
            # Setup
            newPayload[1].text = 'new payload'
            expected[1].text = 'new payload'

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should combine both payload texts when both have text', ->
            # Setup
            storedPayload[1].text = 'this is some stored text'
            newPayload[1].text = 'new payload'
            expected[1].text = "this is some stored text\r\nnew payload"

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should not change stored payload attachments when both stored and new don\'t have attachments', ->
            # Setup

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should not change stored payload attachments when new doesn\'t have attachments', ->
            # Setup
            storedPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                }
            ]
            expected[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                }
            ]

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        # stored doesn't have, set stored to equal new attachments
        it 'should add all attachments to stored when stored doesn\'t have attachments and new does', ->
            # Setup
            newPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                }
            ]
            expected[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                }
            ]

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        # both have but stored doesn't have adaptive card, append new attachments
        # stored doesn't have, set stored to equal new attachments
        it 'should append all new attachments when stored doesn\'t have adaptive card attachment', ->
            # Setup
            storedPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                }
            ]
            newPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'another-image-url'
                },
                {
                    'contentType': 'application/vnd.microsoft.card.adaptive'
                    'content': {
                        "type": "AdaptiveCard"
                        "version": "1.0"
                        "body": [
                            {
                                'type': 'TextBlock'
                                'text': "Some text"
                                'speak': "<s>Some text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            }
                        ]
                    }
                }
            ]
            expected[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                },
                {
                    contentType: 'image'
                    url: 'another-image-url'
                },
                {
                    'contentType': 'application/vnd.microsoft.card.adaptive'
                    'content': {
                        "type": "AdaptiveCard"
                        "version": "1.0"
                        "body": [
                            {
                                'type': 'TextBlock'
                                'text': "Some text"
                                'speak': "<s>Some text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            }
                        ]
                    }
                }
            ]

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

        it 'should combine attachments correctly so there is only one adaptive card attachment in the end', ->
            # Setup
            storedPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                },
                {
                    'contentType': 'application/vnd.microsoft.card.adaptive'
                    'content': {
                        "type": "AdaptiveCard"
                        "version": "1.0"
                        "body": [
                            {
                                'type': 'TextBlock'
                                'text': "Some text"
                                'speak': "<s>Some text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            }
                        ]
                    }
                }
            ]
            newPayload[1].attachments = [
                {
                    contentType: 'image'
                    url: 'another-image-url'
                },
                {
                    'contentType': 'application/vnd.microsoft.card.adaptive'
                    'content': {
                        "type": "AdaptiveCard"
                        "version": "1.0"
                        "body": [
                            {
                                'type': 'TextBlock'
                                'text': "Some more text"
                                'speak': "<s>Some more text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            }
                        ]
                    }
                }
            ]
            expected[1].attachments = [
                {
                    contentType: 'image'
                    url: 'some-image-url'
                },
                {
                    'contentType': 'application/vnd.microsoft.card.adaptive'
                    'content': {
                        "type": "AdaptiveCard"
                        "version": "1.0"
                        "body": [
                            {
                                'type': 'TextBlock'
                                'text': "Some text"
                                'speak': "<s>Some text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            },
                            {
                                'type': 'TextBlock'
                                'text': "Some more text"
                                'speak': "<s>Some more text</s>"
                                'weight': 'bolder'
                                'size': 'large'
                            }
                        ]
                    }
                },
                {
                    contentType: 'image'
                    url: 'another-image-url'
                }
            ]

            # Action
            expect(() ->
                teamsMiddleware.combineResponses(storedPayload, newPayload)
            ).to.not.throw()

            # Assert
            expect(storedPayload).to.deep.equal(expected)

    describe 'constructErrorResponse', ->
        robot = null
        teamsMiddleware = null
        activity = null
        text = null
        appendAdmins = false
        expected = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'

        beforeEach ->
            robot = new MockRobot
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            activity =
                address:
                    addressField: "a value"
                    anotherProperty: "something else"
            text = "This text will be displayed to the user"
            appendAdmins = false
            expected = [
                {
                    type: 'typing'
                    address:
                        addressField: "a value"
                        anotherProperty: "something else"
                },
                {
                    type: 'message'
                    text: "#{text}"
                    address:
                        addressField: "a value"
                        anotherProperty: "something else"
                }
            ]

        it 'should return a proper payload with the error text', ->
            # Setup
            
            # Action
            payload = null
            expect(() ->
                payload = teamsMiddleware.constructErrorResponse(activity, text, appendAdmins)
            ).to.not.throw()

            # Assert
            expect(payload).to.deep.equal(expected)

        it 'should include admins in the payload message text when requested', ->
            # Setup
            appendAdmins = true
            robot.brain.set("authorizedUsers", {
                "user0@some.upn": false
                "user1@website.place": true
                "user2@someother.upn": false
                "user3@another.site": true
            })
            expected[1].text = "#{expected[1].text}\r\n- user1@website.place\r\n- user3@another.site"

            # Action
            payload = null
            expect(() ->
                payload = teamsMiddleware.constructErrorResponse(activity, text, appendAdmins)
            ).to.not.throw()

            # Assert
            expect(payload).to.deep.equal(expected)
    
    describe 'maybeConstructUserInputPrompt', ->
        robot = null
        teamsMiddleware = null
        event = null
        expected = null
        appId = 'a-app-id'
        appPassword = 'a-app-password'

        beforeEach ->
            robot = new MockRobot
            robot.name = 'hubot'
            teamsMiddleware = new MicrosoftTeamsMiddleware(robot, appId, appPassword)
            event =
                value:
                    hubotMessage: 'hubot gho delete team <team name>'
                address:
                    id: 'address-id'
                    channelId: 'channel-id'
                    user:
                        id: 'user-id'
                        name: 'user-name'
                        aadObjectId: 'user-aadobject-id'
                        userPrincipalName: "user-UPN"
                    conversation:
                        conversationType: 'personal'
                        id: 'conversation-id'
                    bot:
                        id: 'bot-id'
                        name: 'bot-name'
                    serviceUrl: 'service-url'
            expected = [
                {
                    type: 'typing'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                },
                {
                    type: 'message'
                    address:
                        id: 'address-id'
                        channelId: 'channel-id'
                        user:
                            id: 'user-id'
                            name: 'user-name'
                            aadObjectId: 'user-aadobject-id'
                            userPrincipalName: "user-UPN"
                        conversation:
                            conversationType: 'personal'
                            id: 'conversation-id'
                        bot:
                            id: 'bot-id'
                            name: 'bot-name'
                        serviceUrl: 'service-url'
                    attachments: [
                        {
                            'contentType': 'application/vnd.microsoft.card.adaptive'
                            'content': {
                                "type": "AdaptiveCard"
                                "version": "1.0"
                                "body": [
                                    {
                                        'type': 'TextBlock'
                                        'text': "gho delete team"
                                        'speak': "<s>gho delete team</s>"
                                        'weight': 'bolder'
                                        'size': 'large'
                                    },
                                    {
                                        'type': 'TextBlock'
                                        'text': "What is the name of the team to delete? (Max 1024 characters)"
                                        'speak': "<s>What is the name of the team to delete? (Max 1024 characters)</s>"
                                    },
                                    {
                                        'type': 'Input.Text'
                                        'id': "gho delete team <team name> - input0"
                                        'speak': "<s>What is the name of the team to delete? (Max 1024 characters)</s>"
                                        'wrap': true
                                        'style': 'text'
                                        'maxLength': 1024
                                    }
                                ]
                                "actions": [
                                    {
                                        'type': 'Action.Submit'
                                        'title': 'Submit'
                                        'speak': '<s>Submit</s>'
                                        'data': {
                                            'queryPrefix': 'gho delete team <team name>'
                                            'gho delete team <team name> - query0': 'hubot gho delete team '
                                        }
                                    }
                                ]
                            }
                        }
                    ]
                }
            ]

        # Should construct a payload containing a user input card for specific queries
        it 'should construct payload containing user input card for specific queries', ->
            # Setup
            
            # Action
            result = null
            expect(() ->
                result = teamsMiddleware.maybeConstructUserInputPrompt(event)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        # Should return null for queries other than those that should return a payload
        it 'should return null for queries that don\'t need an input card', ->
            # Setup
            event.value.hubotMessage = 'hubot gho'
            
            # Action and Assert
            expect(teamsMiddleware.maybeConstructUserInputPrompt(event)).to.be.null
