# Botframework adapter for Hubot

[![npm version](https://badge.fury.io/js/hubot-botframework.svg)](https://badge.fury.io/js/hubot-botframework) [![Build Status](https://travis-ci.org/Microsoft/BotFramework-Hubot.svg?branch=master)](https://travis-ci.org/Microsoft/BotFramework-Hubot) [![Coverage Status](https://coveralls.io/repos/github/Microsoft/BotFramework-Hubot/badge.svg?branch=master)](https://coveralls.io/github/Microsoft/BotFramework-Hubot?branch=master)

# Installation
### Use hubot in Bot Framework Supported Channels
1. Install `hubot`. Make sure to `npm install --save hubot-botframework` to add this module. 

2. Create a Botframework Registration by completing the [Bot Registration Page](https://dev.botframework.com/bots/new). Store the created app id and app password for use later.

3. Configure the required environment variables, and run the command `./bin/hubot -a botframework` to run the bot from your local computer.

You can then interact with your hubot through any Bot Framework supported channel.

### Additional Steps to Use Hubot in [Microsoft Teams](https://products.office.com/en-US/microsoft-teams/)

4. Create a Microsoft Teams app package (.zip) to upload in Teams. We recommend using the manifest editor in [Teams App Studio](https://docs.microsoft.com/en-us/microsoftteams/platform/get-started/get-started-app-studio). Include the bot's app id and password in the bots section.

5. In Microsoft Teams, navigate to the Store and select `Upload a custom app`. Select the zipped Teams App Package, and install the bot for personal and/or team use.

You can then interact with hubot through a personal chat or by @mentioning the name of the uploaded custom app in a Team. In personal chats, the bot's name can be dropped from messages(`ping` or `hubot ping`). In Teams, @mention the bot and omit the bot's name from the command (`@myhubot ping`).

# Global Variables
You can configure the Hubot BotFramework adapter through environment variables.

Required (obtained from the BotFramework portal):
1. `BOTBUILDER_APP_ID` - This is the Id of your bot.
2. `BOTBUILDER_APP_PASSWORD` - This is the secret for your bot.

Optional:
1. `BOTBUILDER_ENDPOINT` - Sets a custom HTTP endpoint for your bot to receive messages on (default is `/api/messages`).

2. `HUBOT_TEAMS_ENABLE_AUTH` - When set to `true`, restricts sending commands to hubot to a specific set of users in Teams. Messages from all non-Teams channels are blocked. Authorization is disabled by default.

3. `HUBOT_TEAMS_INITIAL_ADMINS` - Required if `HUBOT_TEAMS_ENABLE_AUTH` is true. A comma-separated list of user principal names ([UPNs](https://docs.microsoft.com/en-us/windows/desktop/ADSchema/a-userprincipalname)). The users on this list will be admins and able to send commands to hubot when the hubot is first run with authorization enabled.

# Channel Specific Variables
### [Microsoft Teams](https://products.office.com/en-US/microsoft-teams/)
These variables will only take effect if a user communicates with your hubot through [Microsoft Teams](https://products.office.com/en-US/microsoft-teams/).

Optional:
1. `HUBOT_OFFICE365_TENANT_FILTER` - Comma seperated list of Office365 tenant Ids that are allowed to communicate with your hubot. By default ALL Office365 tenants can communicate with your hubot if they sideload your application manifest.

# Optional Authorization for Microsoft Teams:

**NOTE:** The UPNs used for authorization are stored in the hubot brain, so brain persistence affects the `HUBOT_TEAMS_INITIAL_ADMINS` variable as described below.

Authorization restricts the users that can send commands to hubot to a specifically defined set of Microsoft Teams users. Authorization is currently only supported for the Teams channel, so when enabled, messages from all other channels are blocked. To maximize back compatability, authorization is disabled by default and must be enabled to be used.

### Configuring authorization
Authorization is set up using the `HUBOT_TEAMS_ENABLE_AUTH` and `HUBOT_TEAMS_INITIAL_ADMINS` environment variables.

* `HUBOT_TEAMS_ENABLE_AUTH` controls whether authorization is enabled or not. If the variable is not set, authorization is disabled. To enable authorization, set the environment variable to `true`.

* `HUBOT_TEAMS_INITIAL_ADMINS` is required if authorization is enabled. This variable contains a comma-separated list of UPNs. When the hubot is run with authorization enabled for the first time, the users whose UPNs are listed will be admins and authorized to send commands to hubot. These UPNs are stored in the hubot brain. After running hubot with authorization enabled for the first time:

    - If your hubot brain is persistent, to change the list of authorized users, first delete the stored list of authorized users from your hubot's brain then change `HUBOT_TEAMS_INITIAL_ADMINS` to the new list. Also consider using the [hubot-msteams](https://github.com/jayongg/TeamsHubot) script package to dynamically control authorizations.

    - If your hubot brain isn't persistent, this list will be used to set admins every time hubot is restarted.

# Card-based Interactions for Microsoft Teams

**Add screenshots (create an images folder to store them in)**

Hubot is great, but hubot without needing to type in whole commands and with less typos is even better :D. Card-based interactions wrap hubot responses into cards and provide buttons containing useful follow-up commands on the card. To run a follow-up command, simply click the button with the command. If user input is needed, another card is shown with fields for input, and the rest of the command is constructed for you.

### Generating cards
generate cards containing buttons with follow-up hubot commands

based on what follow-up hubot commands make sense for a command that was just run. 

### Defining new card-based interactions




For menu cards used to initiate card-based interactions for any command in a script library, use the [hubot-msteams](https://github.com/jayongg/TeamsHubot) library.





# Contributing
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comm
