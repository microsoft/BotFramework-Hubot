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
BotBuilderTeams = require 'botbuilder-teams'
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
        console.log(process.env.HUBOT_TEAMS_ENABLE_AUTH?)
        console.log(process.env.HUBOT_TEAMS_ENABLE_AUTH == 'true')
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
        console.log(activity)
        # Construct the middleware
        middleware = @using(activity.source)

        # If authorization isn't supported by the activity source, use
        # the text middleware, otherwise use the Teams middleware
        if not middleware.supportsAuth()
            # Return an error to the user if the message channel doesn't support authorization
            # and authorization is enabled
            if @enableAuth
                @robot.logger.info "#{LogPrefix} Authorization isn\'t supported for the channel error"
                text = "Authorization isn't supported for this channel"
                payload = middleware.constructErrorResponse(activity, text)
                @sendPayload(@robot, payload)
                return
            else
                event = middleware.toReceivable activity
                if event?
                    @robot.receive event
        else
            teamsConnector = new BotBuilderTeams.TeamsChatConnector {
                appId: @robot.adapter.appId
                appPassword: @robot.adapter.appPassword
            }
            middleware.toReceivable activity, teamsConnector, @enableAuth, \
                                    (event, response) =>
                if response?
                     @sendPayload(@robot, response)
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

            # If the message isn't from Teams, send it immediately
            if activity.source != 'msteams'
                @sendPayload(@robot, payload)
                return

            # The message is from Teams, so combine hubot responses
            # received within the next 200 ms then send the combined
            # response
            if @robot.brain.get("justReceivedResponse") is null
                @robot.brain.set("teamsResponse", payload)
                @robot.brain.set("justReceivedResponse", true)
                setTimeout(@sendPayload, 200, @robot, @robot.brain.get("teamsResponse"))
            else
                middleware.combineResponses(@robot.brain.get("teamsResponse"), payload)

    sendPayload: (robot, payload) ->
        if !Array.isArray(payload)
            payload = [payload]
        robot.adapter.connector.send payload, (err, _) ->
            if err
                throw err
            robot.brain.remove("teamsResponse")
            robot.brain.remove("justReceivedResponse")

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
