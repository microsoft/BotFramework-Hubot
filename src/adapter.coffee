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


Util = require 'util'
Timers = require 'timers'

BotBuilder = require 'botbuilder'
{Robot, Adapter, TextMessage, User} = require 'hubot'

LogPrefix = "hubot-botframework:"

class BotFrameworkAdapter extends Adapter
    constructor: (@robot) ->
        super @robot
        @appId = process.env.BOTBUILDER_APP_ID
        @appPassword = process.env.BOTBUILDER_APP_PASSWORD
        @endpoint = process.env.BOTBUILDER_ENDPOINT || "/api/messages"
        @robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        @connector  = new BotBuilder.ChatConnector
            appId: @appId
            appPassword: @appPassword

        @connector.onEvent (events, cb) => @onBotEvents events, cb

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities

        for activity in activities
            address = activity.address
            user = @robot.brain.userForId address.user.id, name: address.user.name, room: address.conversation.id
            user.activity = activity
            if activity.type == 'message'
                @robot.receive new TextMessage(user, activity.text, activity.sourceEvent.clientActivityId)
 
    send: (context, strings...) ->
        @robot.logger.info "#{LogPrefix} Message"
        @reply context, strings...
 
    reply: (context, strings...) ->
        @robot.logger.info "#{LogPrefix} Sending reply"
        for str in strings
            msg = 
                type: 'message'
                text: str
                address: context.user.activity.address
            @connector.send [msg]
                
 
    run: ->
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout(=> @emit "connected", 1000)

exports.use = (robot) ->
  new BotFrameworkAdapter robot