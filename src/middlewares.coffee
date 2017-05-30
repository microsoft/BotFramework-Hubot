#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Microsoft Bot Framework: http://botframework.com
#
# Bot Builder SDK Github:
# https://github.com/Microsoft/BotBuilder
#
# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License:
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

{ Robot, TextMessage, Message, User } = require 'hubot'

LogPrefix = "hubot-botframework-middleware:"

class BaseMiddleware
    constructor: (@robot) ->
        @robot.logger.info "#{LogPrefix} creating middleware..."

    toReceivable: (activity) ->
        throw new Error('toReceivable not implemented')

    toSendable: (context, message) ->
        throw new Error('toSendable not implemented')

class TextMiddleware extends BaseMiddleware
    toReceivable: (activity) ->
        @robot.logger.info "#{LogPrefix} TextMiddleware toReceivable"
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
            message.text = hubotifyBotMentions(activity.text, getMentions(activity), activity.address.bot.id, @robot.name)
            return message
        
        return new Message(user)
    
    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} TextMiddleware toSendable"
        if typeof message is 'string'
            msg = {
                type: 'message'
                text: message
                attachments: [
                ]
                address: context.user.activity.address
            }
            # If there's at least one image URL in the message text, make an attachment out of it
            imageAttachment = generateImageAttachment msg.text
            # If the entire message is an image URL, set msg.text to null
            if imageAttachment isnt null and msg.text is imageAttachment.contentUrl
                msg.text = null
            if imageAttachment isnt null 
                msg.attachments.push(imageAttachment)

            return msg

        message

Middlewares = {
    '*': TextMiddleware
}

module.exports = {
    registerMiddleware: (name, middleware) ->
        Middlewares[name] = middleware
    
    middlewareFor: (name) ->
        Middlewares[name] || Middlewares['*']
        
    BaseMiddleware
    TextMiddleware
}

# Helper functions for generating richer messages

# If the message text contains an image URL, extract it and generate the data Bot Framework needs
getImageRef = (text) ->
    imgRegex = /(https*:\/\/.+\/(.+)\.(jpg|png|gif|jpeg$))/
    result = imgRegex.exec(text)
    if result is null
        result
    else
        img =
            url: result[1]
            filename: result[2]
            type: result[3]

# Generate an attachment object from the first image URL in the message
generateImageAttachment = (msgText) ->
    imgRef = getImageRef msgText
    if imgRef is null
        imgRef
    else
        attachment =
            contentType: "image/" + imgRef.type
            contentUrl: imgRef.url
            name: imgRef.filename + "." + imgRef.type

# Helper functions for Bot Framework / Microsoft Teams

# Transform Bot Framework/Microsoft Teams @mentions into Hubot's name as configured
hubotifyBotMentions = (msgText, mentions, bfBotId, hubotBotName) ->
    msgText = msgText.replace(new RegExp(m.text, "gi"), hubotBotName) for m in mentions when m.mentioned.id is bfBotId
    return msgText

# Returns the array of @mentions in the message object
getMentions = (activity) ->
    e for e in activity.entities when e.type is "mention"
