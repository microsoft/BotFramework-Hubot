# Contains helper methods and data structures for constructing and
# combining cards to return to Teams.

HubotQueryParts = require './hubot-query-parts'

maybeConstructResponseCard = (response, query) ->
    # Check if response.text matches one of the reg exps in the LUT and
    # construct a card if so. Otherwise, return null
    for regex of HubotResponseCards
        regexObject = new RegExp(regex)
        if regexObject.test(query)
            card = initializeAdaptiveCard(query)
            card.content.body.push(addTextBlock(response.text))
            card.content.actions = getFollowUpButtons(query, regex)
            return card
    return null

# Constructs an input card or returns null if the
# query doesn't need user input
maybeConstructMenuInputCard = (query) ->
    queryParts = HubotQueryParts[query]

    # Check if the query needs a user input card
    if queryParts.inputParts is undefined
        return null

    shortQuery = constructShortQuery(query)
    card = initializeAdaptiveCard(shortQuery)

    # Create the input fields of the sub card
    for i in [0 ... queryParts.inputParts.length]
        inputPart = queryParts.inputParts[i]
        index = inputPart.search('/')

        # Create the prompt
        promptEnd = inputPart.length
        if index != -1
            promptEnd = index
        card.content.body.push(addTextBlock("#{inputPart.substring(0, promptEnd)}"))

        # Create selector
        if index != -1
            card.content.body.push(addSelector(query, inputPart.substring(index + 1),
                                                query + " - input" + "#{i}"))
        # Create text input
        else
            card.content.body.push(addTextInput(query + " - input" + "#{i}", inputPart))

    # Create the submit button
    data = {
        'queryPrefix': query
    }
    for i in [0 ... queryParts.textParts.length]
        textPart = queryParts.textParts[i]
        data[query + " - query" + "#{i}"] = textPart

    card.content.actions = [
        {
            'type': 'Action.Submit'
            'title': 'Submit'
            'speak': '<s>Submit</s>'
            'data': data
        }
    ]
    return card

# Initializes card structure
initializeAdaptiveCard = (query) ->
    card = {
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
                }
            ]
        }
    }
    return card

# Constructs an adaptive card text block to add to a card
addTextBlock = (text) ->
    textBlock = {
        'type': 'TextBlock'
        'text': "#{text}"
        'speak': "<s>#{text}</s>"
    }
    return textBlock

# Constructs an adaptive card input selector to add to a card
addSelector = (queryPrefix, choicesText, id) ->
    selector = {
        "type": "Input.ChoiceSet"
        "id": id
        "style": "compact"
    }
    choices = []
    for choice in choicesText.split(" or ")
        choices.push({
            'title': choice
            'value': choice
        })
    selector.choices = choices
    # Set the default value to the first choice
    selector.value = choices[0].value

    return selector

# Constructs an adaptive card text input to add to a card
addTextInput = (id, inputPart) ->
    textInput = {
        'type': 'Input.Text'
        'id': id
        'speak': "<s>#{inputPart}</s>"
        'wrap': true
        'style': 'text'
        'maxLength': 1024
    }
    return textInput

# Creates an array of JSON adaptive card actions to use for
# a specific card
getFollowUpButtons = (query, regex) ->
    actions = []
    for followUpQuery in HubotResponseCards[regex]
        shortQuery = constructShortQuery(followUpQuery)
        action = {
            'title': shortQuery
        }
        queryParts = HubotQueryParts[followUpQuery]

        # Doesn't need user input, just run the command when the
        # follow up button is pressed
        if queryParts.inputParts is undefined
            action.type = 'Action.Submit'
            action.data = {
                'queryPrefix': followUpQuery
            }

            # Add the text parts to the data field of the action
            for i in [0 ... queryParts.textParts.length]
                textPart = queryParts.textParts[i]
                action.data[followUpQuery + " - query" + "#{i}"] = textPart

        # Construct a card to show with input fields for each user input
        # and a submit button containing the text parts
        else
            action.type = 'Action.ShowCard'
            # Add the title for the sub card
            action.card = {
                'type': 'AdaptiveCard'
                'body': [
                    {
                        'type': 'TextBlock'
                        'text': "#{shortQuery}"
                        'speak': "<s>#{shortQuery}</s>"
                        'weight': 'bolder'
                        'size': 'large'
                    }
                ]
            }

            # Create the input fields of the sub card
            for i in [0 ... queryParts.inputParts.length]
                inputPart = queryParts.inputParts[i]
                index = inputPart.search('/')

                # Create the prompt
                promptEnd = inputPart.length
                if index != -1
                    promptEnd = index
                action.card.body.push(addTextBlock(inputPart.substring(0, promptEnd)))

                # Create selector
                if index != -1
                    action.card.body.push(addSelector(followUpQuery, \
                                            inputPart.substring(index + 1), \
                                            followUpQuery + " - input" + "#{i}"))
                # Create text input
                else
                    action.card.body.push(addTextInput(followUpQuery + " - input" + "#{i}", \
                                            inputPart))

            # Create the submit button in the sub card
            data = {
                'queryPrefix': followUpQuery
            }
            for i in [0 ... queryParts.textParts.length]
                textPart = queryParts.textParts[i]
                data[followUpQuery + " - query" + "#{i}"] = textPart

            action.card.actions = [
                {
                    'type': 'Action.Submit'
                    'title': 'Submit'
                    'speak': '<s>Submit</s>'
                    'data': data
                }
            ]

        # Add the action to actions
        actions.push(action)

    return actions

# Appends the card body of card2 to card1, skipping
# duplicate card body blocks, and returns card1. In the
# case that both card bodies are undefined
appendCardBody = (card1, card2) ->
    if card2.content.body is undefined
        return card1

    if card1.content.body is undefined
        card1.content.body = card2.content.body
        return card1

    for newBlock in card2.content.body
        hasBlock = false
        for storedBlock in card1.content.body
            if JSON.stringify(storedBlock) == JSON.stringify(newBlock)
                hasBlock = true
                break

        if not hasBlock
            card1.content.body.push(newBlock)
    return card1

# Appends the card actions of card2 to those of card1, skipping
# actions which card1 already contains
appendCardActions = (card1, card2) ->
    if card2.content.actions is undefined
        return card1

    if card1.content.actions is undefined
        card1.content.actions = card2.content.actions
        return card1

    for newAction in card2.content.actions
        hasAction = false
        for storedAction in card1.content.actions
            if JSON.stringify(storedAction) == JSON.stringify(newAction)
                hasAction = true
                break

        # if not in storedActions, add it
        if not hasAction
            card1.content.actions.push(newAction)
    return card1

# Helper method to create a short version of the command by including only the
# start of the command to the first user input marked by ( or <
constructShortQuery = (query) ->
    shortQueryEnd = query.search(new RegExp("[(<]"))
    if shortQueryEnd == -1
        shortQueryEnd = query.length
    shortQuery = query.substring(0, shortQueryEnd)
    return shortQuery.trim()

# HubotResponseCards maps from regex's of hubot queries to an array of follow up hubot
# queries stored as strings
HubotResponseCards = {
    "(.+) gho list (teams|repos|members)": [
        "gho list (teams|repos|members)",
        "gho list public repos"
    ]
    "(.+) gho create team (.+){1,1024}": [
        "gho add (members|repos) <members|repos> to team <team name>",
        "gho list (teams|repos|members)",
        "gho delete team <team name>"
    ]
    "(.+) gho create repo [^/]{1,1024}(|/(|private|public))$": [
        "gho add (members|repos) <members|repos> to team <team name>",
        "gho list (teams|repos|members)"
    ]
    "(.+) gho add (repos|members) (.+)(,.)* to team (.+){1,1024}": [
        "gho remove (repos|members) <members|repos> from team <team name>"
    ]
    "(.+) gho remove (repos|members) (.+)(,.)* from team (.+){1,1024}": [
        "gho add (members|repos) <members|repos> to team <team name>"
    ]
    "(.+) gho delete team (.+){1,1024}": [
        "gho create team <team name>",
        "gho list (teams|repos|members)"
    ]
}

module.exports = {
    maybeConstructResponseCard,
    maybeConstructMenuInputCard,
    appendCardBody,
    appendCardActions
}
