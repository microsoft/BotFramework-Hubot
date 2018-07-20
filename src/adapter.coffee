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
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # Set initial admins if authorization is needed
        # @admins = []
        # @authorizedUsers = []

        # Initial Admins should be required
        if process.env.HUBOT_TEAMS_INITIAL_ADMINS
            robot.logger.info "#{LogPrefix} Restricting by name, setting admins"
            # @admins = process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
            # @authorizedUsers = @admins.slice()
            # *** TESTING
            @authorizedUsers = {}
            for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                @authorizedUsers[admin] = true
            robot.brain.set("authorizedUsers", @authorizedUsers)
        else
            throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required")


            # ***
            # robot.brain.set("admins", @admins)
            # robot.brain.set("authorizedUsers", @authorizedUsers)

        @connector  = new BotBuilder.ChatConnector {
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
        console.log("The activity parameter:")
        console.log(activity)

        # Drop the activity if the user cannot be authenticated with their
        # AAD Object Id or if the user is unauthorized
        authorizedUsers = @robot.brain.get("authorizedUsers")
        aadObjectId = activity?.address?.user?.aadObjectId
        if aadObjectId is undefined or authorizedUsers[aadObjectId] is undefined
           @robot.logger.info "#{LogPrefix} Unauthorized user; ignoring activity"
           return

        event = @using(activity.source).toReceivable(activity)
        if event?
            #console.log("bot is about to receive the event")
            #console.log(event)
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

            # ***
            # if payload[1]?.text == "unicorns"
                
            #     heroCard = new BotBuilder.HeroCard()
            #     console.log("CARD IS DYING HERE")
            #     button = new BotBuilder.CardAction.imBack()
            #     button.data.title ='Follow up'
            #     button.data.value = 'ping'
            #     console.log("Button was constructed")
            #     console.log(button)
            #     # .title('The mythical card')
            #     # .subtitle('The SSR 2% card')
            #     # .text('The totally collector and not actually useful card')
            #     # .images([
            #     #      BotBuilder.CardImage.create('https://sec.ch9.ms/ch9/7ff5/e07cfef0-aa3b-40bb-9baa-7c9ef8ff7ff5/buildreactionbotframework_960.jpg')
            #     # ])
            #     heroCard.buttons([button])
            #     console.log("CARD GOT BUILT AT LEAST")
            #     console.log(heroCard)
                
            #     delete payload[1].text
            #     # console.log("Deleted text")
            #     payload[1].attachments = [heroCard.toAttachment()]
            #     # console.log("Set attachments:")
            #     # console.log(payload[1].attachments)
            # ***
            
            console.log("printing payload for reply: --------------------")
            #console.log(payload)
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
