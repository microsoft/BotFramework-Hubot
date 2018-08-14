#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Description:
#   Middleware to make Hubot work well with Microsoft Teams
#
# Configuration:
#	HUBOT_OFFICE365_TENANT_FILTER
#
# Commands:
#	None
#
# Notes:
#   1. Typing indicator support
#   2. Properly converts Slack @mentions to Teams @mentions
#   3. Properly handles chat vs. channel messages
#   4. Optionally filters out messages from outside the tenant
#   5. Properly handles image responses.
#
# Author:
#	billbliss
#

BotBuilder = require 'botbuilder'
BotBuilderTeams = require 'botbuilder-teams'
HubotResponseCards = require './hubot-response-cards'
HubotQueryParts = require './hubot-query-parts'
{ Robot, TextMessage, Message, User } = require 'hubot'
{ BaseMiddleware, registerMiddleware } = require './adapter-middleware'
LogPrefix = "hubot-msteams:"

#########################
# Flags for testing
MOCK_FETCH_MEMBERS = true

class MicrosoftTeamsMiddleware extends BaseMiddleware
    constructor: (@robot) ->
        super(@robot)

        @allowedTenants = []
        if process.env.HUBOT_OFFICE365_TENANT_FILTER?
            @allowedTenants = process.env.HUBOT_OFFICE365_TENANT_FILTER.split(",")
            @robot.logger.info("#{LogPrefix} Restricting tenants to \
                                            #{JSON.stringify(@allowedTenants)}")

    toReceivable: (activity, teamsConnector, authEnabled, cb) ->
        @robot.logger.info "#{LogPrefix} toReceivable"

        # Drop the activity if it came from an unauthorized tenant
        if @allowedTenants.length > 0 && !@allowedTenants.includes(getTenantId(activity))
            @robot.logger.info "#{LogPrefix} Unauthorized tenant; ignoring activity"
            return null

        # Get the user
        user = getUser(activity)
        user = @robot.brain.userForId(user.id, user)

        # We don't want to save the activity or room in the brain since its
        # something that changes per chat.
        user.activity = activity
        user.room = getRoomId(activity)

        # Fetch the roster of members to do authorization based on UPN
        teamsConnector.fetchMembers activity?.address?.serviceUrl, \
                            activity?.address?.conversation?.id, (err, chatMembers) =>
            if err
                console.log("YUP AN ERR")
                return

            # Set the unauthorizedError to true if auth is enabled and the user who sent
            # the message is not authorized
            unauthorizedError = false
            if authEnabled
                authorizedUsers = @robot.brain.get("authorizedUsers")
                # Get the sender's UPN
                senderUPN = getSenderUPN(user, chatMembers)
                if senderUPN is undefined or authorizedUsers[senderUPN] is undefined
                    @robot.logger.info "#{LogPrefix} Unauthorized user; returning error"
                    unauthorizedError = true
                    # activity.text = "hubot return unauthorized user error"
                    # Change this to make a call to a middleware function that returns
                    # a payload with the error text to return
                
                # Add the sender's UPN to user
                user.userPrincipalName = senderUPN

            # Return a generic message if the activity isn't a message or invoke
            if activity.type != 'message' && activity.type != 'invoke'
                cb(new Message(user), unauthorizedError)

            activity = fixActivityForHubot(activity, @robot, chatMembers)
            message = new TextMessage(user, activity.text, activity.address.id)
            cb(message, unauthorizedError)

    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} toSendable"
        activity = context?.user?.activity

        response = message
        if typeof message is 'string'
            # Trim leading or ending whitespace
            response =
                type: 'message'
                text: message.trim()
                address: activity?.address

            # If the query sent by the user should trigger a card,
            # construct the card to attach to the response
            # and remove sentQuery from the brain
            card = HubotResponseCards.maybeConstructResponseCard(response, activity.text)
            if card != null
                delete response.text
                response.attachments = [card]

            imageAttachment = convertToImageAttachment(message)

            if response.text == "List the admins"
                heroCard = new BotBuilder.HeroCard()
                heroCard.title('Teams Admins')
                
                authorizedUsers = @robot.brain.get("authorizedUsers")

                text = ""
                for user, isAdmin of authorizedUsers
                    if isAdmin
                        if text == ""
                            text = user
                        else
                            text = """#{text}
                                    #{user}"""
                text = escapeLessThan(text)
                text = escapeNewLines(text)
                heroCard.text(text)

                delete response.text
                response.attachments = [heroCard.toAttachment()]
            
            else if imageAttachment?
                delete response.text
                response.attachments = [imageAttachment]

        response = fixMessageForTeams(response, @robot)

        typingMessage =
          type: "typing"
          address: activity?.address
        
        # Check if there is a stored response

        return [typingMessage, response]
    
    # Indicates that the authorization is supported for this middleware (Teams)
    supportsAuth: () ->
        return true

    # Combines the text and attachments of multiple hubot messages sent in succession.
    # Most of the first received response is kept, and the text and attachments of
    # subsequent responses received within 500ms of the first are combined into the
    # first response.
    combineResponses: (storedPayload, newPayload) ->
        # If the stored payload is an array with typing and message messages
        if Array.isArray(storedPayload) and storedPayload.length == 2
            storedMessage = storedPayload[1]

            # If the just received payload is an array with typing and message messages
            if Array.isArray(newPayload) and newPayload.length == 2
                newMessage = newPayload[1]

                # Combine the payload text, if needed, separated by a break
                if newMessage.text != undefined
                    if storedMessage.text != undefined
                        storedMessage.text = "#{storedMessage.text}<br/>#{newMessage.text}"
                    else
                        storedMessage.text = newPayload.text

                # Combine attachments, if needed
                if newMessage.attachments != undefined
                    # If the stored message doesn't have attachments and the new one does,
                    # just store the new attachments
                    if storedMessage.attachments == undefined
                        storedMessage.attachments = newMessage.attachments

                    # Otherwise, combine them
                    else
                        storedCard = searchForAdaptiveCard(storedMessage.attachments)

                        # If the stored message doesn't have an adaptive card, just append the new
                        # attachments
                        if storedCard == null
                            storedMessage.attachments.push.apply(newMessage.attachments)

                        for attachment in newMessage.attachments
                            # If it's not an adaptive card, just append it, otherwise
                            # combine the cards
                            if attachment.contentType != "application/vnd.microsoft.card.adaptive"
                                storedMessage.attachments.push(attachment)
                            else
                                storedCard = HubotResponseCards.appendCardBody(storedCard, \
                                                                                    attachment)
                                storedCard = HubotResponseCards.appendCardActions(storedCard, \
                                                                                    attachment)

    # Constructs a text message response to indicate an error to the user in the
    # message channel they are using
    constructErrorResponse: (activity, text, appendAdmins) ->
        if appendAdmins
            authorizedUsers = @robot.brain.get("authorizedUsers")
            for userKey, isAdmin of authorizedUsers
                if isAdmin
                    text = """#{text}
                            #{userKey}"""
        typing =
            type: 'typing'
            address: activity?.address

        payload =
            type: 'message'
            text: "#{text}"
            address: activity?.address

        return [typing, payload]

    # Constructs a response containing a card for user input if needed or null
    # if user input is not needed
    maybeConstructUserInputPrompt: (event) ->
        query = event.value.hubotMessage
        console.log(query)

        card = HubotResponseCards.maybeConstructMenuInputCard(query)
        if card is null
            console.log("CARD IS NULL")
            return null

        response =
            type: 'message'
            address: event?.address
            attachments: [
                card
            ]

        return response

    #############################################################################
    # Helper methods for generating richer messages
    #############################################################################

    imageRegExp = /^(https?:\/\/.+\/(.+)\.(jpg|png|gif|jpeg$))/

    # Generate an attachment object from the first image URL in the message
    convertToImageAttachment = (message) ->
        if not typeof message is 'string'
            return null

        result = imageRegExp.exec(message)
        if result?
            attachment =
                contentUrl: result[1]
                name: result[2]
                contentType: "image/#{result[3]}"
            return attachment

        return null
        
    # Fetches the user object from the activity
    getUser = (activity) ->
        user =
            id: activity?.address?.user?.id,
            name: activity?.address?.user?.name,
            tenant: getTenantId(activity)
            aadObjectId: getUserAadObjectId(activity)
        return user
    
    # Fetches the user's name from the activity
    getUserName = (activity) ->
        return activity?.address?.user?.name

    # Fetches the user's AAD Object Id from the activity
    getUserAadObjectId = (activity) ->
        return activity?.address?.user?.aadObjectId

    # Fetches the room id from the activity
    getRoomId = (activity) ->
        return activity?.address?.conversation?.id

    # Fetches the conversation type from the activity
    getConversationType = (activity) ->
        return activity?.address?.conversation?.conversationType

    # Fetches the tenant id from the activity
    getTenantId = (activity) ->
        return activity?.sourceEvent?.tenant?.id

    # Returns the array of mentions that can be found in the message.
    getMentions = (activity, userId) ->
        entities = activity?.entities || []
        if not Array.isArray(entities)
            entities = [entities]
        return entities.filter((entity) -> entity.type == "mention" && \
                                (not userId? || userId == entity.mentioned?.id))

    # Returns the provided user's userPrincipalName (UPN) or null if one cannot be found
    getSenderUPN = (user, chatMembers) ->
        userAadObjectId = user.aadObjectId
        for member in chatMembers
            if userAadObjectId == member.objectId
                return member.userPrincipalName
        return null

        

    # Fixes the activity to have the proper information for Hubot
    #  1. Constructs the text command to send to hubot if the event is from a
    #  submit on an adaptive card (containing the value property).
    #  2. Replaces all occurrences of the channel's bot at mention name with the configured
    #  name in hubot.
    #  The hubot's configured name might not be the same name that is sent from the chat service in
    #  the activity's text.
    #  3. Replaces all occurrences of @ mentions to users with their aad object id if the user is
    #  on the roster of chanenl members from Teams. If a mentioned user is not in the chat roster,
    #  the mention is replaced with their name.
    #  4. Trims all whitespace and newlines from the beginning and end of the text.
    #  5. Prepends hubot's name to the message for personal messages if it's not already
    #  there
    fixActivityForHubot = (activity, robot, chatMembers) ->
        # If activity.value exists, the command is from a card and the correct
        # query to send to hubot should be constructed
        if activity?.value != undefined
            data = activity.value
            # Used to uniquely identify command parts since adaptive cards
            # don't differentiate between different sub-cards' data fields
            queryPrefix = data.queryPrefix

            # Get the first command part. A command always begins with a text part
            # since if activity.value is populated, the command is from a card we
            # created, and we always include at least hubot at the beginning of
            # these commands
            text = data[queryPrefix + " - query0"]
            text = text.replace("hubot", robot.name)

            # If there are inputs, add those and the next query part
            # if there is another query part
            i = 0
            input = data[queryPrefix + " - input#{i}"]
            while input != undefined
                text = text + input
                nextTextPart = data[queryPrefix + " - query" + (i + 1)]
                if nextTextPart != undefined
                    text = text + nextTextPart
                i++
                input = data[queryPrefix + " - input#{i}"]

            # Set the constructed query as the text of the activity
            activity.text = text
            #return activity

        if not activity?.text? || typeof activity.text isnt 'string'
            return activity

        myChatId = activity?.address?.bot?.id
        if not myChatId?
            return activity

        # Replace all @ mentions to the bot with the bot's name, and replace
        # all @ mentions of users with a known aad object id with their aad
        # object id.
        mentions = getMentions(activity)
        for mention in mentions
            mentionTextRegExp = new RegExp(escapeRegExp(mention.text), "gi")
            replacement = mention.mentioned.name
            if mention.mentioned.id == myChatId
                replacement = robot.name
            if chatMembers != undefined
                for member in chatMembers
                    if mention.mentioned.id == member.id
                        replacement = member.userPrincipalName
                        # *** replacement = member.objectId
            activity.text = activity.text.replace(mentionTextRegExp, replacement)
        
        # Remove leading/trailing whitespace and newlines
        activity.text = activity.text.trim()

        # prepends the robot's name for direct messages if it's not already there
        if getConversationType(activity) == 'personal' && activity.text.search(robot.name) != 0
            activity.text = "#{robot.name} #{activity.text}"
            
        return activity

    slackMentionRegExp = /<@([^\|>]*)\|?([^>]*)>/g

    # Fixes the response to have the proper information that teams needs
    # 1. Replaces all slack @ mentions with Teams @ mentions
    #  Slack mentions take the form of <@[username or id]|[mention text]>
    #  We have to convert this into a mention object which needs the id.
    # 2. Escapes all < to render hubot help properly
    # 3. Replaces all newlines with break tags to render line breaks properly
    fixMessageForTeams = (response, robot) ->
        if not response?.text?
            return response
        mentions = []
        while match = slackMentionRegExp.exec(response.text)
            foundUser = null
            users = robot.brain.users()
            for userId, user of users
                if userId == match[1] || user.name == match[1]
                    foundUser = user

            userId = foundUser?.id || match[1]
            userName = foundUser?.name || match[1]
            userText = "<at>#{match[2] || userName}</at>"
            mentions.push(
                full: match[0]
                mentioned:
                    id: userId
                    name: userName
                text: userText
                type: "mention")
        
        for mention in mentions
            mentionTextRegExp = new RegExp(escapeRegExp(mention.full), "gi")
            response.text = response.text.replace(mentionTextRegExp, mention.text)
            delete mention.full
        response.entities = mentions

        # Escape < in hubot help commands, determined by the response text
        # starting with 'hubot'
        if response.text.search("hubot") == 0
            response.text = escapeLessThan(response.text)

        # Replace new lines with <br/>
        response.text = escapeNewLines(response.text)

        return response

    escapeRegExp = (str) ->
        return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

    escapeLessThan = (str) ->
        #str = str.replace(/</g, "`<")
        str = str.replace(/</g, "&lt;")
        #str = str.replace(/>/g, ">`")
        return str

    escapeNewLines = (str) ->
        return str.replace(/\n/g, "<br/>")

    # Helper method for retrieving the first adaptive card from a list of
    # attachments or null if there are none
    searchForAdaptiveCard = (attachments) ->
        card = null
        for attachment in attachments
            if attachment.contentType == "application/vnd.microsoft.card.adaptive"
                card = attachment
        return card


registerMiddleware 'msteams', MicrosoftTeamsMiddleware

module.exports = MicrosoftTeamsMiddleware
