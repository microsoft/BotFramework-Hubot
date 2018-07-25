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
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # Initial Admins should be required
        if process.env.HUBOT_TEAMS_INITIAL_ADMINS
            if robot.brain.get("authorizedUsers") is null
                robot.logger.info "#{LogPrefix} Restricting by name, setting admins"
                authorizedUsers = {}
                for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                    authorizedUsers[admin] = true
                robot.brain.set("authorizedUsers", authorizedUsers)
        else
            throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required")

        @connector  = new BotBuilderTeams.TeamsChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

    using: (name) ->
        MiddlewareClass = Middleware.middlewareFor(name)
        new MiddlewareClass(@robot)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities

    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel: #{activity.source}; type: #{activity.type}"
        # console.log("The activity parameter:")
        console.log(activity)

        # Drop the activity if the user cannot be authenticated with their
        # AAD Object Id or if the user is unauthorized
        authorizedUsers = @robot.brain.get("authorizedUsers")
        aadObjectId = activity?.address?.user?.aadObjectId
        if aadObjectId is undefined or authorizedUsers[aadObjectId] is undefined
           @robot.logger.info "#{LogPrefix} Unauthorized user; ignoring activity"
           return null

        @connector.fetchMembers activity?.address?.serviceUrl, activity?.address?.conversation?.id, (err, result) =>
            if err
                return

            # *** Could change the next line to only use the Teams adapter
            #event = @using(activity.source).toReceivable(activity, result)
            msTeamsMiddleware = new MicrosoftTeamsMiddleware(@robot)
            event = msTeamsMiddleware.toReceivable(activity, result)

            if event?
                console.log("Hubot event:")
                console.log(event)
                @robot.receive event

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
            
            console.log("printing payload for reply: --------------------")
            console.log(JSON.stringify(payload, null, 2))
            @connector.send payload, (err, _) ->
                if err
                    console.log("THIS IS WHERE ITS THROWING THE ERROR")
                    throw err

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
