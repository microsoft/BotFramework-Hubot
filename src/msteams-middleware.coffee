# Description:
#   Middleware to make Hubot work well with Microsoft Teams
#
# Dependencies:
# 	"hubot-botframework": "0.9.0"
#
# Configuration:
#	HUBOT_OFFICE365_TENANT_FILTER
#
# Commands:
#	None
#
# Notes:
#   1. Typing indicator support
#	2. Properly formats multi-line messages and changes <> to []
#	3. Properly handles chat vs. channel messages
#	4. Optionally filters out messages from outside the tenant
#
# Author:
#	billbliss
#

module.exports = (robot) ->

	# 
	# RESPONSE MIDDLEWARE 
	#

	# Sends a typing indicator before sending a message
	robot.responseMiddleware (context, next, done) ->
		conversationAddress = context.response.message.user.activity.address
		msg =
			type: "typing"
			address: conversationAddress
			conversation: conversationAddress.conversation
			serviceUrl: conversationAddress.serviceUrl
		robot.adapter.connector.send [msg]
		next()

	# Properly handle chat vs. channel messages
	robot.responseMiddleware (context, next, done) ->
		activity = context.response.message.user.activity
		tenant = if activity.sourceEvent.tenant? then activity.sourceEvent.tenant.id else null
		if activity.sourceEvent?
			eventType = if activity.sourceEvent.eventType? then activity.sourceEvent.eventType else "(none)"
			convType = if activity.sourceEvent.team? 
				"team (#{activity.sourceEvent.team.id})" 				
			else 
				"personal"
			robot.logger.info "MS Teams event type: #{eventType}; Team: #{convType}; Tenant: #{tenant}"
		next()

	# Adds proper line breaks, escape < and > characters, and fix up @mentions which look ugly in plaintext
	robot.responseMiddleware (context, next, done) ->
		for str,i in context.strings
			# Add proper line breaks
			msgText = str.replace /\n/g, "\n\n"
			# Fix up @mentions
			msgText = hubotifyAtMentions msgText, getMentions(context.response.message.user.activity)
			# Escape < and >
			msgText = msgText.replace /</g, "["
			msgText = msgText.replace />/g, "]"
			context.strings[i] = msgText
		next()

	# 
	# RECEIVE MIDDLEWARE 
	#

	# Ignores messages from outside the tenant using receiveMiddleware
    # If HUBOT_OFFICE365_TENANT_FILTER is set and current tenant isn't that, exit immediately (no response)
	robot.receiveMiddleware (context, next, done) ->
		activity = context.response.message.user.activity
		if activity.sourceEvent?
			tenant = if activity.sourceEvent.tenant? then activity.sourceEvent.tenant.id else null
		if process.env.HUBOT_OFFICE365_TENANT_FILTER? 
			if process.env.HUBOT_OFFICE365_TENANT_FILTER isnt tenant
				robot.logger.info "MS Teams: Attempted access from a different Office 365 tenant (#{tenant}): message rejected"
				context.response.message.finish()
				done()
		else
			next()

# Helper functions

# Transform Bot Framework/Microsoft Teams @mentions of the bot into Hubot's name as configured
hubotifyBotMentions = (msgText, mentions, bfBotId, hubotBotName) ->
    msgText = msgText.replace(new RegExp(m.text, "gi"), hubotBotName) for m in mentions when m.mentioned.id is bfBotId
    return msgText

# Transform Bot Framework/Microsoft Teams @mentions of end users
hubotifyAtMentions = (msgText, mentions) ->
	msgText = msgText.replace(new RegExp(m.text, "gi"), '@[' + m.mentioned.name + ']') for m in mentions
	return msgText

# Returns the array of @mentions in the message object
getMentions = (activity) ->
    e for e in activity.entities when e.type is "mention"