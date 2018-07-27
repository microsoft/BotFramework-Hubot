maybeConstructCard = (activity, response, query) ->
    # Check if response.text matches one of the reg exps in the LUT
    for regex of followUpButtons
        regexObject = new RegExp(regex)
        if regexObject.test(query)
            card = initializeAdaptiveCard(response.text)
            # card.content.body[0].text = response.text
            # card.content.body[0].speak = "<s>" + response.text + "</s>"
            card.content.actions = followUpButtons[regex]
            return card
    return null

    # *** v2
    # Split into array of words minus the robot's name at the beginning,
    # so assumes the query is at least the robot's name (*** check this)
    # words = response.text.split(" ")
    # words = words.slice(1)

    # Traverse the tree until at the end of the command or undefined
    

    # if so, return that card
    # return null

initializeAdaptiveCard = (text) ->
    card = {
        'contentType': 'application/vnd.microsoft.card.adaptive'
        'content': {
            "type": "AdaptiveCard"
            "version": "1.0"
            "body": [
                {
                    'type': 'TextBlock'
                    'text': "#{text}"
                    'speak': "<s>#{text}</s>"
                }
            ]
        }
    }
    return card

# v1: An object mapping regex strings to an array of follow up buttons
followUpButtons = {
    "(.+) gho create team (.+){1,257}": [
        {
            'type': 'Action.Submit'
            'title': 'Add to team'
            'data': {
                'query0': 'hubot gho add to team'
                'numInputs': 0
            }
        },
        {
            'type': 'Action.Submit'
            'title': 'Delete a team'
            'data': {
                'query0': 'hubot gho delete what team'
                'numInputs': 0
            }
        }
    ]
    "(.+) gho list (.+){1,257}": [
        {
            'type': 'Action.Submit'
            'title': 'List teams'
            'data': {
                'query0': 'hubot gho list teams'
                'numInputs': 0
            }
        },
        {
            'type': 'Action.Submit'
            'title': 'List repos'
            'data': {
                'query0': 'hubot gho list repos'
                'numInputs': 0
            }
        },
        {
            'type': 'Action.Submit'
            'title': 'List members'
            'data': {
                'query0': 'hubot gho list members'
                'numInputs': 0
            }
        }
    ]
}



# v2: A tree-like structure to hold cards for commands for specific cards
# Look-up tree containing cards to construct cards for
# cards = 
#     gho:
#         create:
#             team: hubot_githubCreateTeamCard

# The card schemas to return  

module.exports = {
    maybeConstructCard
}