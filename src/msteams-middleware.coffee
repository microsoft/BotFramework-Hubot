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
  # Flag to ensure SendTyping is only sent once per batch of messages (once per invocation/creation of the class)
  _sendTypingSent = false

  constructor: (@robot) ->
    @robot.logger.info "#{LogPrefix} creating middleware..."
    # Initialize Hubot Middleware

    # Sends a typing indicator before sending a message
    @robot.responseMiddleware (context, next, done) ->
      if not @_sendTypingSent
        @_sendTypingSent = true
        conversationAddress = context.response.message.user.activity.address
        msg =
          type: "typing"
          address: conversationAddress
          conversation: conversationAddress.conversation
          serviceUrl: conversationAddress.serviceUrl
        robot.adapter.connector.send [msg]
      next()

    # Properly handle chat vs. channel messages
    @robot.responseMiddleware (context, next, done) ->
      activity = context.response.message.user.activity
      tenant = if activity.sourceEvent.tenant? then activity.sourceEvent.tenant.id else null
      if activity.sourceEvent?
        eventType = if activity.sourceEvent.eventType? then activity.sourceEvent.eventType else "(none)"
        convType = if activity.sourceEvent.team?
          "team (#{activity.sourceEvent.team.id})"
        else
          "personal"
        robot.logger.info "#{LogPrefix} event type: #{eventType}; Team: #{convType}; Tenant: #{tenant}"
      next()

    # Adds proper line breaks, escape < and > characters, and fix up @mentions which look ugly in plaintext
    @robot.responseMiddleware (context, next, done) ->
      for str,i in context.strings
        # Fix up @mentions
        msgText = _hubotifyAtMentions str, _getMentions(context.response.message.user.activity)
        # Escape < and >
        msgText = msgText.replace /</g, "["
        msgText = msgText.replace />/g, "]"
        # Add proper line breaks
        msgText = str.replace /\n/g, "<br/>" # or "\n\n but that leaves blank lines between every content line"
        context.strings[i] = msgText
      next()

    # Ignores messages from outside the tenant using receiveMiddleware
    # If HUBOT_OFFICE365_TENANT_FILTER is set and current tenant isn't that, exit immediately (no response)
    @robot.receiveMiddleware (context, next, done) ->
      activity = context.response.message.user.activity
      if activity.sourceEvent?
        tenant = if activity.sourceEvent.tenant? then activity.sourceEvent.tenant.id else null
      if process.env.HUBOT_OFFICE365_TENANT_FILTER?
        if process.env.HUBOT_OFFICE365_TENANT_FILTER isnt tenant
          robot.logger.info "#{LogPrefix}: Attempted access from a different Office 365 tenant (#{tenant}): message rejected"
          context.response.message.finish()
          done()
      else
        next()

  toReceivable: (activity) ->
    @robot.logger.info "#{LogPrefix} toReceivable"
    address = activity.address

    # Retrieve Microsoft Teams tenant information if present to persist in the brain
    # If not running inside Teams, tenant will be null
    if activity.sourceEvent?
      tenant = if activity.sourceEvent.tenant? then activity.sourceEvent.tenant.id else null

    user = @robot.brain.userForId address.user.id, name: address.user.name, room: address.conversation.id, tenant: tenant
    user.activity = activity

    if activity.type == 'message'
      message = new TextMessage user, activity.text, activity.address.id
      # Adjust raw message text so that Microsoft Teams @ mentions are what Hubot expects
      # Adjustment logic is not Microsoft Teams specific
      message.text = _hubotifyBotMentions(activity.text, _getMentions(activity), activity.address.bot.id, @robot.name)
      return message

    return new Message(user)

  toSendable: (context, message) ->
    @robot.logger.info "#{LogPrefix} toSendable"
    msg = message

    if typeof message is 'string'
      msg = {
        type: 'message'
        text: message
        attachments: []
        address: context.user.activity.address
      }

      # If there's at least one image URL in the message text, make an attachment out of it
      imageAttachment = _generateImageAttachment msg.text

      # If the entire message is an image URL, set msg.text to null
      if imageAttachment isnt null and msg.text is imageAttachment.contentUrl
        msg.text = null
      if imageAttachment isnt null
        msg.attachments.push(imageAttachment)

    return msg

  #############################################################################
  # Helper methods for generating richer messages
  #############################################################################

  # If the message text contains an image URL, extract it and generate the data Bot Framework needs
  _getImageRef = (text) ->
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
  _generateImageAttachment = (msgText) ->
    imgRef = _getImageRef msgText
    if imgRef is null
        return imgRef
    else
      attachment =
        contentType: "image/" + imgRef.type
        contentUrl: imgRef.url
        name: imgRef.filename
      return attachment

  # Helper functions for Bot Framework / Microsoft Teams
  # Transform Bot Framework/Microsoft Teams @mentions into Hubot's name as configured
  _hubotifyBotMentions = (msgText, mentions, bfBotId, hubotBotName) ->
    msgText = msgText.replace(new RegExp(m.text, "gi"), hubotBotName) for m in mentions when m.mentioned.id is bfBotId
    return msgText

  # Transform Bot Framework/Microsoft Teams @mentions of end users
  _hubotifyAtMentions = (msgText, mentions) ->
    msgText = msgText.replace(new RegExp(m.text, "gi"), '@[' + m.mentioned.name + ']') for m in mentions
    return msgText

  # Returns the array of @mentions in the message object
  _getMentions = (activity) -> e for e in activity.entities when e.type is "mention"

module.exports = {
  MicrosoftTeamsMiddleware
}

################################
# Register Middleware with same name as activity.source
# Note: Must be an exact match and it's case sensitive
################################
registerMiddleware 'msteams', MicrosoftTeamsMiddleware