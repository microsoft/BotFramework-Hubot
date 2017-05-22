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
        user = @robot.brain.userForId address.user.id, name: address.user.name, room: address.conversation.id
        user.activity = activity

        if activity.type == 'message'
            return new TextMessage(user, activity.text, activity.sourceEvent.clientActivityId)
        
        return new Message(user)
    
    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} TextMiddleware toSendable"
        if typeof message is 'string'
            return {
                type: 'message'
                text: message
                address: context.user.activity.address
            }
        
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