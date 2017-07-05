#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Microsoft Bot Framework: http://botframework.com
#
# Bot Builder SDK Github:
# https://github.com/Microsoft/BotBuilder
#

Util = require 'util'
Timers = require 'timers'

BotBuilder = require 'botbuilder'
{ Robot, Adapter, TextMessage, User } = require 'hubot'
{ middlewareFor } = require './adapter-middleware'
# Uncomment the following line to enable MS Teams Middleware
# { MicrosoftTeamsMiddleware } = require './msteams-middleware'

LogPrefix = "hubot-botframework-adapter:"

class BotFrameworkAdapter extends Adapter
    constructor: (robot) ->
        super robot
        @appId = process.env.BOTBUILDER_APP_ID
        @appPassword = process.env.BOTBUILDER_APP_PASSWORD
        @endpoint = process.env.BOTBUILDER_ENDPOINT || "/api/messages"
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

    using: (name) ->
        MiddlewareClass = middlewareFor(name)
        new MiddlewareClass(@robot)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities
            
    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel: #{activity.source}; type: #{activity.type}"
        @robot.receive @using(activity.source).toReceivable(activity)

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        @reply context, messages...
 
    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"
        for msg in messages
            activity = context.user.activity
            payload = @using(activity.source).toSendable(context, msg)
            if !Array.isArray(payload)
               payload = [payload]
            @connector.send payload, (err, _) -> 
                if err
                    throw err if err
 
    run: ->
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout (=> @emit "connected"), 1000

exports.use = (robot) ->
    new BotFrameworkAdapter robot

exports.middleware = require './adapter-middleware'
