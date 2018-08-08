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
        @enableAuth = process.env.HUBOT_TEAMS_ENABLE_AUTH || 'false'
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # Initial Admins should be required when auth is enabled or not set
        if @enableAuth == 'true'
            if process.env.HUBOT_TEAMS_INITIAL_ADMINS
                if robot.brain.get("authorizedUsers") is null
                    robot.logger.info "#{LogPrefix} Restricting by name, setting admins"
                    authorizedUsers = {}
                    for admin in process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
                        authorizedUsers[admin] = true
                    robot.brain.set("authorizedUsers", authorizedUsers)
            else
                throw new Error("HUBOT_TEAMS_INITIAL_ADMINS is required for authorization")

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

        @connector.onInvoke (events, cb) => @sendTextToHubot events, cb

    sendTextToHubot: (invokeEvent, cb) ->
        console.log("In the invoke handler")
        invokeEvent.text = invokeEvent.value.hubotMessage
        delete invokeEvent.value
        console.log(invokeEvent)
        @handleActivity(invokeEvent)


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
        console.log(JSON.stringify(activity, null, 2))

        # Construct the middleware
        middleware = @using(activity.source)

        # Drop the activity if the user cannot be authenticated with their
        # AAD Object Id or if the user is unauthorized
        authorizedUsers = @robot.brain.get("authorizedUsers")
        aadObjectId = activity?.address?.user?.aadObjectId
        if @enableAuth == 'true'
            if middleware.supportsAuth()
                if aadObjectId is undefined or authorizedUsers[aadObjectId] is undefined
                    @robot.logger.info "#{LogPrefix} Unauthorized user; returning error"
                    activity.text = "hubot return unauthorized user error"
            else
                @robot.logger.info "#{LogPrefix} Message source doesn't support authorization"
                activity.text = "hubot return source authorization not supported error"

        # If authorization isn't supported by the activity source, use
        # the text middleware
        if not middleware.supportsAuth()
            event = middleware.toReceivable activity
            if event?
                console.log("Hubot event, not callback:")
                console.log(event)

                @robot.receive event
        else
            middleware.toReceivable activity, (event) =>
                console.log("AFTER TO RECEIVABLE")
                console.log(event)
                if event?
                    console.log("Hubot event:")
                    console.log(event)

                    @robot.receive event

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        @reply context, messages...

    sendPayload: (robot) ->
        console.log("IN SEND PAYLOAD")
        payload = robot.brain.get("teamsResponse")
        if !Array.isArray(payload)
            payload = [payload]
        console.log("printing payload for reply: --------------------")
        console.log(JSON.stringify(payload, null, 2))
        robot.adapter.connector.send payload, (err, _) ->
            if err
                console.log("THIS IS WHERE ITS THROWING THE ERROR")
                throw err
            robot.brain.remove("teamsResponse")
            robot.brain.remove("justReceivedResponse")

    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"
        console.log("============================================================")
        console.log(@robot.brain.get("teamsResponse"))
        console.log(@robot.brain.get("justReceivedResponse"))

        for msg in messages
            activity = context.user.activity
            payload = @using(activity.source).toSendable(context, msg)

            # Only gather responses and send them together if the message is from the
            # Teams channel
            if activity.source != 'msteams'
                if !Array.isArray(payload)
                    payload = [payload]
                
                console.log("printing payload for reply: --------------------")
                console.log(JSON.stringify(payload, null, 2))
                @connector.send payload, (err, _) ->
                    if err
                        console.log("THIS IS WHERE ITS THROWING THE ERROR")
                        console.log(err.name)
                        console.log(err.message)
                        throw err
                return
                

            # If a certain period of time hasn't passed since receiving the first message,
            # combine the message payload texts and attachments
            console.log(@robot.brain.get("justReceivedResponse") is null)
            console.log(@robot.brain.get("justReceivedResponse") == null)
            if @robot.brain.get("justReceivedResponse") is null
                console.log("++++++++++++++++++++++++++++++++++++++++++")
                @robot.brain.set("teamsResponse", payload)
                setTimeout(this.sendPayload, 500, @robot)
                console.log("After set timeout")
                @robot.brain.set("justReceivedResponse", true)
            else
                console.log("--------------------------------------------")
                storedPayload = @robot.brain.get("teamsResponse")
                # If the stored payload is an array with typing and the message,
                if Array.isArray(storedPayload) and storedPayload.length == 2
                    console.log("HEEEEEEEEEEEEEEEEEERE")
                    storedMessage = storedPayload[1]
                    # If the just received payload is an array with typing and the message,
                    if Array.isArray(payload) and payload.length == 2
                        console.log("HEEEEEEEEEEEEEEEEEERE")
                        newMessage = payload[1]
                        # Combine the payload text, if needed, separated by a break
                        if newMessage.text != undefined
                            if storedMessage.text != undefined
                                storedMessage.text = "#{storedMessage.text}<br/>#{newMessage.text}"
                            else
                                storedMessage.text = payload.text

                        # Combine the payload attachments, if any
                        if newMessage.attachments != undefined
                            console.log("HEEEEEEEEEEEEEEEEEERE")
                            storedMessageAdaptiveCard = null
                            # Find the adaptive card, if there is one, in newMessage's
                            # attachments
                            if storedMessage.attachments == undefined
                                storedMessage.attachments = []
                            else
                                for storedAttachment in storedMessage.attachments
                                    if storedAttachment.contentType = "application/vnd.microsoft.card.adaptive"
                                        storedMessageAdaptiveCard = storedAttachment
                            console.log(storedMessageAdaptiveCard)

                            for attachment in newMessage.attachments
                                # If it's not an adaptive card, just append it
                                if attachment.contentType != "application/vnd.microsoft.card.adaptive"
                                    storedMessage.attachments.push(attachment)
                                else
                                    # If the storedMessage doesn't contain a card, just append it
                                    if storedMessageAdaptiveCard == null
                                        storedMessage.attachments.push(attachment)
                                        storedMessageAdaptiveCard = attachment
                                    # Otherwise, combine the cards
                                    else
                                        # Combine the bodies
                                        if storedMessageAdaptiveCard.content.body is undefined
                                            storedMessageAdaptiveCard.content.body = attachment.content.body
                                        else
                                            for newBlock in attachment.content.body
                                                hasBlock = false
                                                for storedBlock in storedMessageAdaptiveCard.content.body
                                                    if JSON.stringify(storedBlock) == JSON.stringify(newBlock)
                                                        hasBlock = true
                                                        break

                                                if not hasBlock
                                                    storedMessageAdaptiveCard.content.body.push(newBlock)

                                        # Combine the actions
                                        if storedMessageAdaptiveCard.content.actions is undefined
                                            storedMessageAdaptiveCard.content.actions = card2.content.actions
                                        else
                                            for newAction in attachment.content.actions
                                                hasAction = false
                                                for storedAction in storedMessageAdaptiveCard.content.actions
                                                    if JSON.stringify(storedAction) == JSON.stringify(newAction)
                                                        hasAction = true
                                                        break

                                                # if not in storedActions, add it
                                                if not hasAction
                                                    storedMessageAdaptiveCard.content.actions.push(newAction)
                            console.log(storedMessageAdaptiveCard)

                            # for attachment in newMessage.attachments
                            #     storedMessage.attachments.push(attachment)


            # if !Array.isArray(payload)
            #     payload = [payload]
            
            # console.log("printing payload for reply: --------------------")
            # console.log(JSON.stringify(payload, null, 2))
            # @connector.send payload, (err, _) ->
            #     if err
            #         console.log("THIS IS WHERE ITS THROWING THE ERROR")
            #         console.log(err.name)
            #         console.log(err.message)
            #         throw err

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
