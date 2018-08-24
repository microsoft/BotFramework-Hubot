# Description:
#   Tests for helper methods used to construct Adaptive Cards for specific hubot
#   commands when used with the Botframework adapter

chai = require 'chai'
expect = chai.expect

HubotResponseCards = require '../src/hubot-response-cards'

describe 'HubotResponseCards', ->
    describe 'maybeConstructResponseCard', ->
        query = null
        response = null
        beforeEach ->
            query = 'hubot gho create team team-name'
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
                        userPrincipalName: 'user-UPN'
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

        it 'should not construct response card for the query', ->
            # Setup
            query = 'hubot ping'

            # Action
            card = null
            expect(() ->
                card = HubotResponseCards.maybeConstructResponseCard(response, query)
            ).to.not.throw()

            # Assert
            expect(card).to.be.null

        it 'should construct response card for the query', ->
            # Setup
            query = 'hubot gho create team team-name'
            followUp1 = 'gho add (members|repos) <members|repos> to team <team name>'
            followUp2 = 'gho list (teams|repos|members)'
            followUp3 = 'gho delete team <team name>'
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
                            'size': 'large'
                        },
                        {
                            'type': 'TextBlock'
                            'text': "#{response.text}"
                            'speak': "<s>#{response.text}</s>"
                        }
                    ],
                    'actions': [
                        {
                            "title": "gho add"
                            "type": "Action.ShowCard"
                            "card": {
                                "type": "AdaptiveCard"
                                "body": [
                                    {
                                        'type': 'TextBlock'
                                        'text': "gho add"
                                        'speak': "<s>gho add</s>"
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
                            "title": "gho delete team"
                            "type": "Action.ShowCard"
                            "card": {
                                "type": "AdaptiveCard"
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

            # Action
            card = null
            expect(() ->
                card = HubotResponseCards.maybeConstructResponseCard(response, query)
            ).to.not.throw()

            # Assert
            expect(card).to.eql(expected)

    describe 'maybeConstructMenuInputCard', ->
        it 'should not construct menu input card for the query', ->
            # Setup
            query = 'ping'

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.maybeConstructMenuInputCard(query)
            )

            # Assert
            expect(result).to.be.null

        it 'should construct menu input card for the query', ->
            # Setup
            query = 'gho list (teams|repos|members)'
            expected = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
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
            }

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.maybeConstructMenuInputCard(query)
            ).to.not.throw()

            # Assert
            expect(result).to.eql(expected)

    describe 'appendCardBody', ->
        card1 = null
        card2 = null
        expected = null
        beforeEach ->
            card1 = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "body": [
                        {
                            'type': 'TextBlock'
                            'text': "Card1"
                            'speak': "<s>Card1</s>"
                            'weight': 'bolder'
                            'size': 'large'
                        },
                        {
                            'type': 'Input.Text'
                            'id': "the-same-id"
                            'speak': "<s>the same text</s>"
                            'wrap': true
                            'style': 'text'
                        },
                        {
                            'type': 'TextBlock'
                            'text': "This is unique to 1"
                            'speak': "<s>This is unique to 1</s>"
                        },
                        {
                            "type": "Input.ChoiceSet"
                            "id": "a-selector-unique-to-card1-id"
                            "style": "compact"
                            "choices": [
                                {
                                    "title": "Card 1 choice"
                                    "value": "Card 1 choice"
                                },
                                {
                                    "title": "Another card 1 choice"
                                    "value": "Another card 1 choice"
                                }
                            ]
                            "value": "Another card 1 choice"
                        }
                    ]
                }
            }
            card2 = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "body": [
                        {
                            'type': 'TextBlock'
                            'text': "Card2"
                            'speak': "<s>Card2</s>"
                            'weight': 'bolder'
                            'size': 'large'
                        },
                        {
                            'type': 'TextBlock'
                            'text': "This is unique to 2"
                            'speak': "<s>This is unique to 2</s>"
                        },
                        {
                            'type': 'Input.Text'
                            'id': "the-same-id"
                            'speak': "<s>the same text</s>"
                            'wrap': true
                            'style': 'text'
                        },
                        {
                            "type": "Input.ChoiceSet"
                            "id": "a-selector-unique-to-card2-id"
                            "style": "compact"
                            "choices": [
                                {
                                    "title": "Card 2 choice"
                                    "value": "Card 2 choice"
                                },
                                {
                                    "title": "Another card 2 choice"
                                    "value": "Another card 2 choice"
                                }
                            ]
                            "value": "Another card 2 choice"
                        }
                    ]
                }
            }
            expected = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "body": [
                        {
                            'type': 'TextBlock'
                            'text': "Card1"
                            'speak': "<s>Card1</s>"
                            'weight': 'bolder'
                            'size': 'large'
                        },
                        {
                            'type': 'Input.Text'
                            'id': "the-same-id"
                            'speak': "<s>the same text</s>"
                            'wrap': true
                            'style': 'text'
                        },
                        {
                            'type': 'TextBlock'
                            'text': "This is unique to 1"
                            'speak': "<s>This is unique to 1</s>"
                        },
                        {
                            "type": "Input.ChoiceSet"
                            "id": "a-selector-unique-to-card1-id"
                            "style": "compact"
                            "choices": [
                                {
                                    "title": "Card 1 choice"
                                    "value": "Card 1 choice"
                                },
                                {
                                    "title": "Another card 1 choice"
                                    "value": "Another card 1 choice"
                                }
                            ]
                            "value": "Another card 1 choice"
                        }
                    ]
                }
            }

        it 'both cards don\'t have bodies, should return card1 unchanged', ->
            # Setup
            delete card1.content.body
            delete card2.content.body
            delete expected.content.body

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardBody(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)
        
        it 'card2 doesn\'t have a body, should return card1 unchanged', ->
            # Setup
            delete card2.content.body

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardBody(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        it 'card1 doesn\'t have a body, result body should equal card2\'s body', ->
            # Setup
            delete card1.content.body
            expected.content.body = card2.content.body

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardBody(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        it 'both cards have bodies, should combine both bodies into card1 and remove duplicates', ->
            # Setup
            expected.content.body.push({
                'type': 'TextBlock'
                'text': "Card2"
                'speak': "<s>Card2</s>"
                'weight': 'bolder'
                'size': 'large'
            })
            expected.content.body.push({
                'type': 'TextBlock'
                'text': "This is unique to 2"
                'speak': "<s>This is unique to 2</s>"
            })
            expected.content.body.push({
                "type": "Input.ChoiceSet"
                "id": "a-selector-unique-to-card2-id"
                "style": "compact"
                "choices": [
                    {
                        "title": "Card 2 choice"
                        "value": "Card 2 choice"
                    },
                    {
                        "title": "Another card 2 choice"
                        "value": "Another card 2 choice"
                    }
                ]
                "value": "Another card 2 choice"
            })

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardBody(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

    describe 'appendCardActions', ->
        card1 = null
        card2 = null
        expected = null
        beforeEach ->
            card1 = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "actions": [
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-shared-field": "shared"
                            }
                        },
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-field-card1": "a-value-card1"
                            }
                        }
                    ]
                }
            }
            card2 = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "actions": [
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-shared-field": "shared"
                            }
                        },
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-field-card2": "a-value-card2"
                            }
                        },
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-shared-field": "shared"
                            }
                        }
                    ]
                }
            }
            expected = {
                'contentType': 'application/vnd.microsoft.card.adaptive'
                'content': {
                    "type": "AdaptiveCard"
                    "version": "1.0"
                    "actions": [
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-shared-field": "shared"
                            }
                        },
                        {
                            'type': 'Action.Submit'
                            'title': 'Submit'
                            'speak': '<s>Submit</s>'
                            'data': {
                                "a-field-card1": "a-value-card1"
                            }
                        }
                    ]
                }
            }

        it 'both cards don\'t have actions, should return card1 unchanged', ->
            # Setup
            delete card1.content.actions
            delete card2.content.actions
            delete expected.content.actions

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardActions(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        it 'card2 doesn\'t have actions, should return card1 unchanged', ->
            # Setup
            delete card2.content.actions

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardActions(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        it 'card1 doesn\'t have actions, result actions should equal card2\'s actions', ->
            # Setup
            delete card1.content.actions
            expected.content.actions = card2.content.actions

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardActions(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)

        it 'both cards have actions, should combine both actions into card1 and remove duplicates', ->
            # Setup
            expected.content.actions.push({
                'type': 'Action.Submit'
                'title': 'Submit'
                'speak': '<s>Submit</s>'
                'data': {
                    "a-field-card2": "a-value-card2"
                }
            })

            # Action
            result = null
            expect(() ->
                result = HubotResponseCards.appendCardActions(card1, card2)
            ).to.not.throw()

            # Assert
            expect(result).to.deep.equal(expected)
