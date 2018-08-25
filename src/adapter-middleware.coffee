# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Microsoft Bot Framework: http://botframework.com
#
# Bot Builder SDK Github:
# https://github.com/Microsoft/BotBuilder

{ Robot, TextMessage, Message, User } = require 'hubot'

LogPrefix = "hubot-botframework-middleware:"

class BaseMiddleware
    constructor: (@robot, appId, appPassword) ->
        @robot.logger.info "#{LogPrefix} creating middleware..."
        @appId = appId
        @appPassword = appPassword

    toReceivable: (activity) ->
        throw new Error('toReceivable not implemented')

    toSendable: (context, message) ->
        throw new Error('toSendable not implemented')

class TextMiddleware extends BaseMiddleware
    # TextMiddleware doesn't use invokes currently, so just return null
    handleInvoke: (invokeEvent, connector) ->
        return null

    toReceivable: (activity) ->
        @robot.logger.info "#{LogPrefix} TextMiddleware toReceivable"
        address = activity.address
        user = @robot.brain.userForId address.user.id, name: address.user.name, room: address.conversation.id
        user.activity = activity

        if activity.type == 'message'
            return new TextMessage(user, activity.text, activity.sourceEvent?.clientActivityId || '')
        
        return new Message(user)
    
    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} TextMiddleware toSendable"
        if typeof message is 'string'
            return {
                type: 'message'
                text: message
                address: context.user.activity.address
            }
        
        return message
    
    # Constructs a text message response to indicate an error to the user in the
    # message channel they are using
    constructErrorResponse: (activity, text) ->
        payload =
            type: 'message'
            text: "#{text}"
            address: activity?.address
        return payload

    # Sends an error message back to the user if authorization isn't supported for the
    # channel or prepares and sends the message to hubot for reception
    maybeReceive: (activity, connector, authEnabled) ->
        # Return an error to the user if the message channel doesn't support authorization
        # and authorization is enabled
        if authEnabled
            @robot.logger.info "#{LogPrefix} Authorization isn\'t supported
                                    for the channel error"
            text = "Authorization isn't supported for this channel"
            payload = @constructErrorResponse(activity, text)
            @send(connector, payload)
        else
            event = @toReceivable activity
            if event?
                @robot.receive event

    # Sends the payload to the bot framework messaging channel
    send: (connector, payload) ->
        if !Array.isArray(payload)
            payload = [payload]
        connector.send payload, (err, _) ->
            if err
                throw err

Middleware = {
    '*': TextMiddleware
}

module.exports = {
    registerMiddleware: (name, middleware) ->
        Middleware[name] = middleware
    
    middlewareFor: (name) ->
        Middleware[name] || Middleware['*']

    BaseMiddleware
    TextMiddleware
}
