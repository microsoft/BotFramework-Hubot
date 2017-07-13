#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Description:
#   Middleware to make Hubot work well with Microsoft Teams
#
# Dependencies:
# 	"hubot-botframework": "0.9.0"
#
# Configuration:
#	HUBOT_OFFICE365_TENANT_FILTER
#
# Commands:
#	None
#
# Notes:
#   1. Typing indicator support
#	  2. Properly formats multi-line messages and changes <> to []
#	  3. Properly handles chat vs. channel messages
#	  4. Optionally filters out messages from outside the tenant
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
        if @allowedTenants.length > 0 &&
        !@allowedTenants.includes(activity.sourceEvent?.tenant?.id)
            @robot.logger.info "#{LogPrefix} Unauthorized tenant; ignoring activity"
            return null

        address = activity.address
        user = @robot.brain.userForId(
            address.user.id,
            name: address.user.name,
            room: address.conversation.id)
        user.activity = activity

        if activity.type == 'message'
            message = new TextMessage user, activity.text, activity.address.id
            # Adjust raw message text so that Microsoft Teams @ mentions are
            #  what Hubot expects
            # Adjustment logic is not Microsoft Teams specific
            message.text = hubotifyBotMentions(
                activity.text,
                getMentions(activity),
                activity.address.bot.id,
                @robot.name)
            return message

        return new Message(user)

    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} toSendable"
        msg = message
        conversationAddress = context.user.activity.address

        if typeof message is 'string'
            msg =
              type: 'message'
              text: message
              attachments: []
              address: conversationAddress

            # If there's at least one image URL in the message text,
            #  make an attachment out of it
            imageAttachment = generateImageAttachment msg.text

            # If the entire message is an image URL, set msg.text to null
            if imageAttachment isnt null and msg.text is imageAttachment.contentUrl
                msg.text = null
            if imageAttachment isnt null
                msg.attachments.push(imageAttachment)

        if msg.text?
            msg.text = hubotifyAtMentions(
                msg.text,
                getMentions(context.message.user.activity))
            # Escape < and >
            msg.text = msg.text.replace /</g, "["
            msg.text = msg.text.replace />/g, "]"
            # Add proper line breaks
            msg.text = msg.text.replace /\n/g, "<br/>"

        typingMessage =
          type: "typing"
          address: conversationAddress

        return [typingMessage, msg]

    #############################################################################
    # Helper methods for generating richer messages
    #############################################################################

    # If the message text contains an image URL,
    #  extract it and generate the data Bot Framework needs
    getImageRef = (text) ->
        imgRegex = /(https*:\/\/.+\/(.+)\.(jpg|png|gif|jpeg$))/
        result = imgRegex.exec(text)
        if result?
            img =
              url: result[1]
              filename: result[2]
              type: result[3]
        else
            null

    # Generate an attachment object from the first image URL in the message
    generateImageAttachment = (msgText) ->
        imgRef = getImageRef msgText
        if imgRef is null
            return imgRef
        else
            attachment =
              contentType: "image/" + imgRef.type
              contentUrl: imgRef.url
              name: imgRef.filename
            return attachment

    # Helper functions for Bot Framework / Microsoft Teams
    #  Transform Bot Framework/Microsoft Teams @mentions into Hubot's
    #  name as configured
    hubotifyBotMentions = (msgText, mentions, bfBotId, hubotBotName) ->
        for m in mentions when m.mentioned.id is bfBotId
            msgText = msgText.replace(new RegExp(m.text, "gi"), hubotBotName)
        return msgText

    # Transform Bot Framework/Microsoft Teams @mentions of end users
    hubotifyAtMentions = (msgText, mentions) ->
        for m in mentions
            msgText = msgText.replace(new RegExp(m.text, "gi"), '@[' + m.mentioned.name + ']')
        return msgText

    # Returns the array of @mentions in the message object
    getMentions = (activity) -> e for e in activity.entities when e.type is "mention"

registerMiddleware 'msteams', MicrosoftTeamsMiddleware

module.exports = MicrosoftTeamsMiddleware