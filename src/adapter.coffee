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
Middleware = require './adapter-middleware'
MicrosoftTeamsMiddleware = require './msteams-middleware'

LogPrefix = "hubot-botframework-adapter:"

class BotFrameworkAdapter extends Adapter
    constructor: (robot) ->
        super robot
        @appId = process.env.BOTBUILDER_APP_ID
        @appPassword = process.env.BOTBUILDER_APP_PASSWORD
        @endpoint = process.env.BOTBUILDER_ENDPOINT || "/api/messages"
        @enableAuth = false
        if process.env.HUBOT_TEAMS_ENABLE_AUTH? and process.env.HUBOT_TEAMS_ENABLE_AUTH == 'true'
            @enableAuth = true
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # Initial Admins should be required when auth is enabled
        if @enableAuth
            if process.env.HUBOT_TEAMS_INITIAL_ADMINS
                # If there isn't a list of authorized users in the brain, populate
                # it with admins from the environment variable
                if robot.brain.get("authorizedUsers") is null
                    robot.logger.info "#{LogPrefix} Restricting by name, setting admins"
                    authorizedUsers = {}
                    for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                        authorizedUsers[admin.toLowerCase()] = true
                    robot.brain.set("authorizedUsers", authorizedUsers)
            else
                throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required for authorization")

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

        @connector.onInvoke (events, cb) => @menuCardInvoke events, cb


    # If the command for the invoke doesn't need user input, handle the command
    # normally. If it does need user input, return a prompt for user input.
    menuCardInvoke: (invokeEvent, cb) ->
        middleware = @using(invokeEvent.source)
        payload = middleware.maybeConstructUserInputPrompt(invokeEvent)
        if payload == null
            invokeEvent.text = invokeEvent.value.hubotMessage
            delete invokeEvent.value
            @handleActivity(invokeEvent)
        else
            @sendPayload(@robot, payload)
        return

    using: (name) ->
        MiddlewareClass = Middleware.middlewareFor(name)
        new MiddlewareClass(@robot)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities

    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel:
                            #{activity.source}; type: #{activity.type}"

        # Construct the middleware
        middleware = @using(activity.source)

        # If authorization isn't supported by the activity source, use
        # the text middleware, otherwise use the Teams middleware
        if not middleware.supportsAuth()
            # Return an error to the user if the message channel doesn't support authorization
            # and authorization is enabled
            if @enableAuth
                @robot.logger.info "#{LogPrefix} Authorization isn\'t supported
                                     for the channel error"
                text = "Authorization isn't supported for this channel"
                payload = middleware.constructErrorResponse(activity, text)
                middleware.send(@robot.adapter.connector, payload)
                return
            else
                event = middleware.toReceivable activity
                if event?
                    @robot.receive event
        else
            middleware.toReceivable activity, @enableAuth, @appId, @appPassword, \
                                    (event, response) =>
                if response?
                    middleware.send(@robot.adapter.connector, response)
                else if event?
                    @robot.receive event

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        @reply context, messages...

    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"

        for msg in messages
            activity = context.user.activity
            middleware = @using(activity.source)
            payload = middleware.toSendable(context, msg)
            middleware.send(@robot.adapter.connector, payload)

    run: ->
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout (=> @emit "connected"), 1000

module.exports = {
    Middleware,
    MicrosoftTeamsMiddleware
}

module.exports.use = (robot) ->
    new BotFrameworkAdapter robot
