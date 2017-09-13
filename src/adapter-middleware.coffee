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
