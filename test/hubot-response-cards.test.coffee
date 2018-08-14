chai = require 'chai'
expect = chai.expect

HubotResponseCards = require '../src/hubot-response-cards'

describe 'MicrosoftTeamsMiddleware', ->
    # Define any needed variables
    query = null
    response = {
        type: 'message',
        text: 'The team: `team-name` was successfully created',
        address: {
            id: 'id',
            channelId: 'msteams',
            user: {
                id: 'user-id',
                name: 'user-name',
                aadObjectId: 'user-aad-id'
            },
            conversation: {
                conversationType: 'conversation-type',
                id: 'conversation-id'
            },
            bot: {
                id: 'botframework-bot-id',
                name: 'botframework-bot-name'
            },
            serviceUrl: 'a-service-url'
        }
    }

    it 'should not construct card', ->
        # Setup
        query = 'hubot ping'

        # Action and Assert
        expect(() ->
                card = HubotResponseCards.maybeConstructCard(response, query)
                expect(card).to.be.null
        ).to.not.throw()

    it 'should construct card', ->
        # Setup
        query = 'hubot gho create team team-name'
        followUp1 = 'gho add (members|repos) <members|repos> to team <team name>'
        followUp2 = 'gho list (teams|repos|members)'
        followUp3 = 'gho delete team <team name>'
        

        # Action
        card = null
        expect(() ->
                card = HubotResponseCards.maybeConstructCard(response, query)
                expect(card).to.be.not.null
        ).to.not.throw()

        # Assert
        expected = {
            'contentType': 'application/vnd.microsoft.card.adaptive'
            'content': {
                "type": "AdaptiveCard"
                "version": "1.0"
                "body": [
                    {
                        'type': 'TextBlock'
                        'text': "#{query}"
                        'speak': "<s>#{query}</s>"
                        'weight': 'bolder'
                        'size': 'medium'
                    },
                    {
                        'type': 'TextBlock'
                        'text': "#{response.text}"
                        'speak': "<s>#{response.text}</s>"
                    }
                ],
                'actions': [
                    {
                        "title": "gho add "
                        "type": "Action.ShowCard"
                        "card": {
                            "type": "AdaptiveCard"
                            "body": [
                                {
                                    'type': 'TextBlock'
                                    'text': "gho add "
                                    'speak': "<s>gho add </s>"
                                    'weight': 'bolder'
                                    'size': 'large'
                                },
                                {
                                    'type': 'TextBlock'
                                    'text': 'Add members or repos?'
                                    'speak': "<s>Add members or repos?</s>"
                                },
                                {
                                    "type": "Input.ChoiceSet"
                                    "id": "#{followUp1} - input0"
                                    "style": "compact"
                                    "value": "members"
                                    "choices": [
                                        {
                                            "title": "members"
                                            "value": "members"
                                        },
                                        {
                                            "title": "repos"
                                            "value": "repos"
                                        }
                                    ]
                                },
                                {
                                    'type': 'TextBlock'
                                    'text': 'Input a comma separated list to add'
                                    'speak': "<s>Input a comma separated list to add</s>"
                                },
                                {
                                    'type': 'Input.Text'
                                    'id': "#{followUp1} - input1"
                                    'speak': '<s>Input a comma separated list to add</s>'
                                    'wrap': true
                                    'style': 'text'
                                    'maxLength': 1024
                                },
                                {
                                    'type': 'TextBlock'
                                    'text': 'What is the name of the team to add to?'
                                    'speak': "<s>What is the name of the team to add to?</s>"
                                },
                                {
                                    'type': 'Input.Text'
                                    'id': "#{followUp1} - input2"
                                    'speak': '<s>What is the name of the team to add to?</s>'
                                    'wrap': true
                                    'style': 'text'
                                    'maxLength': 1024
                                }
                            ],
                            'actions': [
                                {
                                    'type': 'Action.Submit'
                                    'title': 'Submit'
                                    'speak': '<s>Submit</s>'
                                    'data': {
                                        'queryPrefix': "#{followUp1}"
                                        "#{followUp1} - query0": 'hubot gho add '
                                        "#{followUp1} - query1": ' '
                                        "#{followUp1} - query2": ' to team '
                                    }
                                }
                            ]
                        }
                    },
                    {
                        "title": "gho list "
                        "type": "Action.ShowCard"
                        "card": {
                            "type": "AdaptiveCard"
                            "body": [
                                {
                                    'type': 'TextBlock'
                                    'text': "gho list "
                                    'speak': "<s>gho list </s>"
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
                                    "id": "#{followUp2} - input0"
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
                                        'queryPrefix': "#{followUp2}"
                                        "#{followUp2} - query0": 'hubot gho list '
                                    }
                                }
                            ]
                        }
                    },
                    {
                        "title": "gho delete team "
                        "type": "Action.ShowCard"
                        "card": {
                            "type": "AdaptiveCard"
                            "body": [
                                {
                                    'type': 'TextBlock'
                                    'text': "gho delete team "
                                    'speak': "<s>gho delete team </s>"
                                    'weight': 'bolder'
                                    'size': 'large'
                                },
                                {
                                    'type': 'TextBlock'
                                    'text': 'What is the name of the team to delete? (Max 1024 characters)'
                                    'speak': "<s>What is the name of the team to delete? (Max 1024 characters)</s>"
                                },
                                {
                                    'type': 'Input.Text'
                                    'id': "#{followUp3} - input0"
                                    'speak': "<s>What is the name of the team to delete? (Max 1024 characters)</s>"
                                    'wrap': true
                                    'style': 'text'
                                    'maxLength': 1024
                                }
                            ],
                            'actions': [
                                {
                                    'type': 'Action.Submit'
                                    'title': 'Submit'
                                    'speak': '<s>Submit</s>'
                                    'data': {
                                        'queryPrefix': "#{followUp3}"
                                        "#{followUp3} - query0": 'hubot gho delete team '
                                    }
                                }
                            ]
                        }
                    }
                ]
            }
        }
        expect(card).to.eql(expected)

    # # Test initializeAdaptiveCard
    # it 'should initialize the adaptive card properly', ->
    #     # Setup
    #     text = "This should be the text for the title of the card"

    #     # Action
    #     card = initializeAdaptiveCard(text)

    #     # Assert
    #     expected = {
    #         'contentType': 'application/vnd.microsoft.card.adaptive'
    #         'content': {
    #             "type": "AdaptiveCard"
    #             "version": "1.0"
    #         }
    #         'body': [
    #             {
    #                 'type': 'TextBlock'
    #                 'text': "#{text}"
    #                 'speak': "<s>#{text}</s>"
    #                 'weight': 'bolder'
    #                 'size': 'medium'
    #             }
    #         ]
    #     }
    #     expect(card).to.equal(expected)


    # # Test addTextBlock
    # it 'should add a TextBlock', ->
    #     # Setup

    #     # Action

    #     # Assert

    # Test addTextInput

    # Test addSelector

    # Test createMenuInputCard (*** if use adaptive card for menu, won't need this)

    # Test getFollowUpButtons