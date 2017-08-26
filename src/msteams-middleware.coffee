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

{ Robot, TextMessage, Message, User } = require 'hubot'
{ BaseMiddleware, registerMiddleware } = require './adapter-middleware'
LogPrefix = "hubot-msteams:"

class MicrosoftTeamsMiddleware extends BaseMiddleware
    constructor: (@robot) ->
        super(@robot)

        @allowedTenants = []
        if process.env.HUBOT_OFFICE365_TENANT_FILTER?
            @allowedTenants = process.env.HUBOT_OFFICE365_TENANT_FILTER.split(",")
            @robot.logger.info("#{LogPrefix} Restricting tenants to #{JSON.stringify(@allowedTenants)}")

    toReceivable: (activity) ->
        @robot.logger.info "#{LogPrefix} toReceivable"

        # Drop the activity if it came from an unauthorized tenant
        if @allowedTenants.length > 0 && !@allowedTenants.includes(getTenantId(activity))
            @robot.logger.info "#{LogPrefix} Unauthorized tenant; ignoring activity"
            return null

        # Get the user
        user = getUser(activity)
        user = @robot.brain.userForId(user.id, user)

        # We don't want to save the activity or room in the brain since its something that changes per chat.
        user.activity = activity
        user.room = getRoomId(activity)

        if activity.type == 'message'
            activity = fixActivityForHubot(activity, @robot)
            message = new TextMessage(user, activity.text, activity.address.id)
            return message

        return new Message(user)

    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} toSendable"
        activity = context?.user?.activity

        response = message
        if typeof message is 'string'
            response =
                type: 'message'
                text: message
                address: activity?.address
            
            imageAttachment = convertToImageAttachment(message)
            if imageAttachment?
                delete response.text
                response.attachments = [imageAttachment]

        response = fixMessageForTeams(response, @robot)

        typingMessage =
          type: "typing"
          address: activity?.address

        return [typingMessage, response]

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
        return user

    # Fetches the room id from the activity
    getRoomId = (activity) ->
        return activity?.address?.conversation?.id

    # Fetches the tenant id from the activity
    getTenantId = (activity) ->
        return activity?.sourceEvent?.tenant?.id

    # Returns the array of mentions that can be found in the message.
    getMentions = (activity, userId) ->
        entities = activity?.entities || []
        if not Array.isArray(entities)
            entities = [entities]
        return entities.filter((entity) -> entity.type == "mention" && (not userId? || userId == entity.mentioned?.id))

    # Fixes the activity to have the proper information for Hubot
    # 1. Replaces all occurances of the channel's bot at mention name with the configured name in hubot.
    #  The hubot's configured name might not be the same name that is sent from the chat service in
    #  the activity's text.
    # 2. Prepends hubot's name to the message if this is a direct message.
    fixActivityForHubot = (activity, robot) ->
        if not activity?.text? || typeof activity.text isnt 'string'
            return activity
        myChatId = activity?.address?.bot?.id
        if not myChatId?
            return activity

        # replace all @ mentions with the robot's name
        mentions = getMentions(activity)
        for mention in mentions
            mentionTextRegExp = new RegExp(escapeRegExp(mention.text), "gi")
            replacement = mention.mentioned.name
            if mention.mentioned.id == myChatId
                replacement = robot.name

            activity.text = activity.text.replace(mentionTextRegExp, replacement)

        # prepends the robot's name for direct messages
        roomId = getRoomId(activity)
        if roomId? and not roomId.startsWith("19:") and not activity.text.startsWith(robot.name)
            activity.text = "#{robot.name} #{activity.text}"
            
        return activity

    slackMentionRegExp = /<@([^\|>]*)\|?([^>]*)>/g

    # Fixes the response to have the proper information that teams needs
    # 1. Replaces all slack @ mentions with Teams @ mentions
    #  Slack mentions take the form of <@[username or id]|[mention text]>
    #  We have to convert this into a mention object which needs the id.
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
        return response

    escapeRegExp = (str) ->
        return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")


registerMiddleware 'msteams', MicrosoftTeamsMiddleware

module.exports = MicrosoftTeamsMiddleware
