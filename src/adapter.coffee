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
SkypeMiddleware = require './skype-middleware'

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
        @initialAdmins = process.env.HUBOT_TEAMS_INITIAL_ADMINS
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # When the adapter is ready to be run, load the authorized users if needed
        @on( "loadAuthorizedUsers", () =>
            if @enableAuth
                if @initialAdmins?
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
        )

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

        @connector.onInvoke (events, cb) => @onInvoke events, cb

    # Handles the invoke and passes an event to be handled, if needed
    onInvoke: (invokeEvent, cb) ->
        middleware = @using(invokeEvent.source)
        event = middleware.handleInvoke(invokeEvent, @connector)
        if event != null
            @handleActivity(event)

    using: (name) ->
        MiddlewareClass = Middleware.middlewareFor(name)
        new MiddlewareClass(@robot, @appId, @appPassword)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities

    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel:
                            #{activity.source}; type: #{activity.type}"

        # Construct the middleware
        middleware = @using(activity.source)
        middleware.maybeReceive(activity, @connector, @enableAuth)

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        @reply context, messages...

    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"

        for msg in messages
            activity = context.user.activity
            middleware = @using(activity.source)
            payload = middleware.toSendable(context, msg)
            middleware.send(@connector, payload)

    run: ->
        @emit "loadAuthorizedUsers"
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout (=> @emit "connected"), 1000

module.exports = {
    Middleware,
    MicrosoftTeamsMiddleware,
    SkypeMiddleware
}

module.exports.use = (robot) ->
    new BotFrameworkAdapter robot
