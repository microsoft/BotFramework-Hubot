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
#   6. Generates adaptive cards with follow up buttons for specific commands
#   7. Optionally restricts authorization to Hubot to a defined list of users
#
# Author:
#	billbliss
#

BotBuilderTeams = require 'botbuilder-teams'
HubotResponseCards = require './hubot-response-cards'
HubotQueryParts = require './hubot-query-parts'
{ Robot, TextMessage, Message, User } = require 'hubot'
{ BaseMiddleware, registerMiddleware } = require './adapter-middleware'
LogPrefix = "hubot-msteams:"


class MicrosoftTeamsMiddleware extends BaseMiddleware
    constructor: (@robot, appId, appPassword) ->
        super(@robot)
        @appId = appId
        @appPassword = appPassword

        @allowedTenants = []
        if process.env.HUBOT_OFFICE365_TENANT_FILTER?
            @allowedTenants = process.env.HUBOT_OFFICE365_TENANT_FILTER.split(",")
            @robot.logger.info("#{LogPrefix} Restricting tenants to \
                                            #{JSON.stringify(@allowedTenants)}")

    # If the invoke is due to a command that needs user input, sends a user input card
    # otherwise, returns an event to handle, if needed, or null
    handleInvoke: (invokeEvent, connector) ->
        payload = @maybeConstructUserInputPrompt(invokeEvent)
        if payload != null
            @sendPayload(connector, payload)
            return null
        else
            invokeEvent.text = invokeEvent.value.hubotMessage
            delete invokeEvent.value
            return invokeEvent

    toReceivable: (activity, chatMembers) ->
        @robot.logger.info "#{LogPrefix} toReceivable"

        # Drop the activity if it came from an unauthorized tenant
        if @allowedTenants.length > 0 && !@allowedTenants.includes(getTenantId(activity))
            @robot.logger.info "#{LogPrefix} Unauthorized tenant; ignoring activity"
            return null

        # Get the user
        user = getUser(activity)
        
        # Store the UPN temporarily to re-add it to user and ensure
        # the user has a UPN.
        upn = user.userPrincipalName
        user = @robot.brain.userForId(user.id, user)
        user.userPrincipalName = upn

        # We don't want to save the activity or room in the brain since its
        # something that changes per chat.
        user.activity = activity
        user.room = getRoomId(activity)

        # Return a generic message if the activity isn't a message or invoke
        if activity.type != 'message' && activity.type != 'invoke'
            return new Message(user)

        activity = fixActivityForHubot(activity, @robot, chatMembers)
        message = new TextMessage(user, activity.text, activity.address.id)
        return message

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
            card = HubotResponseCards.maybeConstructResponseCard(response, activity.text)
            if card != null
                delete response.text
                response.attachments = [card]
            else
                imageAttachment = convertToImageAttachment(message)
                if imageAttachment?
                    delete response.text
                    response.attachments = [imageAttachment]

        response = fixMessageForTeams(response, @robot)

        typingMessage =
          type: "typing"
          address: activity?.address

        return [typingMessage, response]

    # Converts the activity to a hubot message and passes it to
    # hubot for reception on success
    maybeReceive: (activity, connector, authEnabled) ->
        # Fetch the roster of members to do authorization, if enabled, based on UPN
        teamsConnector = new BotBuilderTeams.TeamsChatConnector {
            appId: @appId
            appPassword: @appPassword
        }
        teamsConnector.fetchMembers activity?.address?.serviceUrl, \
                            activity?.address?.conversation?.id, (err, chatMembers) =>
            if err
                throw err
            # Return with unauthorized error as true if auth is enabled and the user who sent
            # the message is not authorized
            if authEnabled
                authorizedUsers = @robot.brain.get("authorizedUsers")
                user = getUser(activity)
                senderUPN = getSenderUPN(user, chatMembers).toLowerCase()
                if senderUPN is undefined or authorizedUsers[senderUPN] is undefined
                    @robot.logger.info "#{LogPrefix} Unauthorized user; returning error"
                    text = "You are not authorized to send commands to hubot.
                            To gain access, talk to your admins:"
                    errorResponse = @constructErrorResponse(activity, text, true)
                    @send(connector, errorResponse)
                    return

            # Add the sender's UPN to the activity
            activity.address.user.userPrincipalName = senderUPN

            # Convert the message to a hubot understandable form and
            # send to the robot on success
            event = @toReceivable activity, chatMembers
            if event?
                @robot.receive event

    # Combines payloads then sends the combined payload to MS Teams
    send: (connector, payload) ->
        # The message is from Teams, so combine hubot responses
        # received within the next 100 ms then send the combined
        # response
        if @robot.brain.get("justReceivedResponse") is null
            @robot.brain.set("teamsResponse", payload)
            @robot.brain.set("justReceivedResponse", true)
            setTimeout(@sendPayload.bind(this), 100, connector, @robot.brain.get("teamsResponse"))
        else
            @combineResponses(@robot.brain.get("teamsResponse"), payload)

    sendPayload: (connector, payload) ->
        if !Array.isArray(payload)
            payload = [payload]
        connector.send payload, (err, _) =>
            if err
                throw err
            @robot.brain.remove("teamsResponse")
            @robot.brain.remove("justReceivedResponse")

    # Combines the text and attachments of multiple hubot messages sent in succession.
    # Most of the first received response is kept, and the text and attachments of
    # subsequent responses received within 100ms of the first are combined into the
    # first response. Assumes inputs follow the format of the payload returned by
    # toSendable
    combineResponses: (storedPayload, newPayload) ->
        storedMessage = storedPayload[1]
        newMessage = newPayload[1]

        # Combine the payload text, if needed, separated by a break
        if newMessage.text != undefined
            if storedMessage.text != undefined
                storedMessage.text = "#{storedMessage.text}\r\n#{newMessage.text}"
            else
                storedMessage.text = newMessage.text

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
                    for attachment in newMessage.attachments
                        storedMessage.attachments.push(attachment)
                else
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
                    text = "#{text}\r\n- #{userKey}"

        payload =
            type: 'message'
            text: "#{text}"
            address: activity?.address

        return packagePayload(activity, payload)

    # Constructs a response containing a card for user input if needed or null
    # if user input is not needed
    maybeConstructUserInputPrompt: (event) ->
        query = event.value.hubotMessage
        # Remove the robot's name from the beginning of the command if it's there
        query = query.replace("#{@robot.name} ", "")

        card = HubotResponseCards.maybeConstructMenuInputCard(query)
        if card is null
            return null

        message =
            type: 'message'
            address: event?.address
            attachments: [
                card
            ]

        return packagePayload(event, message)

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
            userPrincipalName: activity?.address?.user?.userPrincipalName
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
        # If activity.value exists, the command is from a follow up button press on
        # a card and the correct query to send to hubot should be constructed
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
    # 2. Escapes all < to render 'hubot help' properly
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

        # Replace \n with html <br/> for rendering breaks in Teams
        response.text = escapeNewLines(response.text)

        return response

    escapeRegExp = (str) ->
        return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

    escapeLessThan = (str) ->
        str = str.replace(/</g, "&lt;")
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
    
    packagePayload = (activity, message) ->
        typing =
            type: 'typing'
            address: activity?.address
        return [typing, message]


registerMiddleware 'msteams', MicrosoftTeamsMiddleware

module.exports = MicrosoftTeamsMiddleware
