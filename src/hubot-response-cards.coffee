# Contains helper methods and data structures for constructing cards
# to return to Teams with defined follow up queries.

HubotQueryParts = require './hubot-query-parts'

maybeConstructCard = (activity, response, query) ->
    # Check if the response is from a list commands follow up button press.
    # If so, construct the needed input card and return it
    index = query.search("generate input card")
    if (index != -1)
        return constructInputCard(query.substring(0, index), response.text)

    # Check if response.text matches one of the reg exps in the LUT
    for regex of HubotResponseCards
        regexObject = new RegExp(regex)
        if regexObject.test(query)
            card = initializeAdaptiveCard(query)
            card.content.body.push(addTextBlock(response.text))
            card.content.actions = getFollowUpButtons(query, regex)
            return card
    return null

# Constructs an input card
constructInputCard = (query, text) ->
    card = initializeAdaptiveCard(query)
    console.log(text)
    queryParts = HubotQueryParts[text]
    console.log(queryParts)
    # Create the input fields of the sub card
    for i in [0 ... queryParts.inputParts.length]
        console.log("*********")
        console.log(queryParts.inputParts.length)
        inputPart = queryParts.inputParts[i]
        index = inputPart.search('/')

        # Create the prompt
        promptEnd = inputPart.length
        if index != -1
            promptEnd = index
        prompt = {
            'type': 'TextBlock'
            'text': "#{inputPart.substring(0, promptEnd)}"
        }
        card.content.body.push(prompt)

        # Create selector
        if index != -1
            selector = {
                "type": "Input.ChoiceSet"
                "id": query + " - input" + "#{i}"
                "style": "compact"
            }
            choices = []
            for choice in inputPart.substring(index + 1).split(" or ")
                choices.push({
                    'title': choice
                    'value': choice
                })
            selector.choices = choices
            # Set the default value to the first choice
            selector.value = choices[0].value

            card.content.body.push(selector)
        # Create text input
        else
            textInput = {
                'type': 'Input.Text'
                'id': query + " - input" + "#{i}"
                'speak': "<s>#{inputPart}</s>"
                'wrap': true
                'style': 'text'
                'maxLength': 1024
            }
            card.content.body.push(textInput)

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
    console.log("=====================================")
    console.log(card)
    console.log("=====================================")

    return card


# Initializes card structure
initializeAdaptiveCard = (query, text) ->
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
                    'size': 'medium'
                }
            ]
        }
    }
    return card

addTextBlock = (text) ->
    textBlock = {
        'type': 'TextBlock'
        'text': "#{text}"
        'speak': "<s>#{text}</s>"
    }
    return textBlock

# Creates an array of JSON adaptive card actions for the
# card in construction
getFollowUpButtons = (query, regex) ->
    actions = []
    for followUpQuery in HubotResponseCards[regex]
        console.log(followUpQuery)

        # Create a short version of the command by including only the
        # start of the command to the first user input marked by ( or <
        shortQueryEnd = followUpQuery.search(new RegExp("[(<]"))
        if shortQueryEnd == -1
            shortQueryEnd = followUpQuery.length
        shortQuery = followUpQuery.substring(0, shortQueryEnd)
        action = {
            'title': shortQuery
        }
        queryParts = HubotQueryParts[followUpQuery]

        # Doesn't need user input, just run the command
        if queryParts.inputParts is undefined
            action.type = 'Action.Submit'
            action.data = {
                'queryPrefix': followUpQuery
            }

            # Add the text parts to the data field of the action
            # *** will change this to just hold array & will change
            # query constructor code to iterate over the array
            for i in [0 ... queryParts.textParts.length]
                textPart = queryParts.textParts[i]
                action.data[followUpQuery + " - query" + "#{i}"] = textPart

        # Construct a card to show with input fields for each user input
        # and a submit button containing the text parts
        else
            action.type = 'Action.ShowCard'
            action.card = {
                'type': 'AdaptiveCard'
                'body': [
                    {
                        'type': 'TextBlock'
                        'text': "#{followUpQuery}"
                        'speak': "<s>#{followUpQuery}</s>"
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
                console.log("===========================================")
                console.log(index)
                console.log(promptEnd)
                prompt = {
                    'type': 'TextBlock'
                    'text': "#{inputPart.substring(0, promptEnd)}"
                }
                action.card.body.push(prompt)

                # Create selector
                if index != -1
                    selector = {
                        "type": "Input.ChoiceSet"
                        "id": followUpQuery + " - input" + "#{i}"
                        "style": "compact"
                    }
                    choices = []
                    for choice in inputPart.substring(index + 1).split(" or ")
                        choices.push({
                            'title': choice
                            'value': choice
                        })
                    selector.choices = choices
                    # Set the default value to the first choice
                    selector.value = choices[0].value

                    action.card.body.push(selector)
                # Create text input
                else
                    textInput = {
                        'type': 'Input.Text'
                        'id': followUpQuery + " - input" + "#{i}"
                        'speak': "<s>#{inputPart}</s>"
                        'wrap': true
                        'style': 'text'
                        'maxLength': 1024
                    }
                    action.card.body.push(textInput)



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

            console.log("+++++++++++++++++++++++++++")
            console.log(action.card.actions[0].data)

        # Add the action to actions
        actions.push(action)

    return actions


# v1: An object mapping regex strings to an array of follow up buttons
# HubotResponseCards = {
#     "(.+) gho create team (.+){1,257}": [
#         {
#             'type': 'Action.Submit'
#             'title': 'Add to team'
#             'data': {
#                 'query0': 'hubot gho add to team'
#                 'numInputs': 0
#             }
#         },
#         {
#             'type': 'Action.Submit'
#             'title': 'Delete a team'
#             'data': {
#                 'query0': 'hubot gho delete what team'
#                 'numInputs': 0
#             }
#         }
#     ]
#     "(.+) gho list (.+){1,257}": [
#         {
#             'type': 'Action.Submit'
#             'title': 'List teams'
#             'data': {
#                 'query0': 'hubot gho list teams'
#                 'numInputs': 0
#             }
#         },
#         {
#             'type': 'Action.Submit'
#             'title': 'List repos'
#             'data': {
#                 'query0': 'hubot gho list repos'
#                 'numInputs': 0
#             }
#         },
#         {
#             'type': 'Action.Submit'
#             'title': 'List members'
#             'data': {
#                 'query0': 'hubot gho list members'
#                 'numInputs': 0
#             }
#         }
#     ]
# }

# HubotResponseCards maps from regex's of hubot queries to an array of follow up hubot
# queries stored as strings

    # *** Will add list hubot-github/gho commands here
    # "list (gho|hubot-github) commands":[
    #     "gho",
    #     "gho list (teams|repos|members)",
    #     "gho list public repos",
    #     "gho create team <team name>",
    #     "gho create repo <repo name>/<private|public>",
    #     "gho add (members|repos) <members|repos> to team <team name>",
    #     "gho remove (repos|members) <members|repos> from team <team name>",
    #     "gho delete team <team name>"
    # ]
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
    maybeConstructCard
}