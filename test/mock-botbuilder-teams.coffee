class TeamsChatConnector
    constructor: (options) ->
        @appId = options.appId
        @appPassword = options.appPassword

    fetchMembers: (serviceUrl, conversationId, callback) ->
        members = [
            {
                id: 'user-id',
                objectId: 'eight888-four-4444-fore-twelve121212',
                name: 'user-name',
                givenName: 'user-',
                surname: 'name',
                email: 'em@ai.l',
                userPrincipalName: 'em@ai.l'
            },
            {
                id: 'user2-id',
                objectId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                name: 'user2 two',
                givenName: 'user2',
                surname: 'two',
                email: 'em@ai.l2',
                userPrincipalName: 'em@ai.l2'
            }
        ]

        callback false, members

BotBuilderTeams = {
    TeamsChatConnector: TeamsChatConnector
}

# module.exports = TeamsChatConnector
module.exports = BotBuilderTeams
