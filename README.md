# Botframework adapter for Hubot

# Installation
Install `hubot`. Make sure to `npm install --save hubot-botframework` to add this module. Run the command `./bin/hubot -a botframework` to run the bot from your local computer.

# Global Variables
You can configure the Hubot BotFramework adapter through environment variables.

Required (obtained from the BotFramework portal):
1. `BOTBUILDER_APP_ID` - This is the Id of your bot.
2. `BOTBUILDER_APP_PASSWORD` - This is the secret for your bot.

Optional:
1. `BOTBUILDER_ENDPOINT` - Sets a custom HTTP endpoint for your bot to receive messages on (defualt is `/api/messages`).

# Channel Specific Variables
## [Microsoft Teams](https://products.office.com/en-US/microsoft-teams/)
These variables will only take effect if a user communicates with your hubot through [Microsoft Teams](https://products.office.com/en-US/microsoft-teams/).

Optional:
1. `HUBOT_OFFICE365_TENANT_FILTER` - Comma seperated list of Office365 tenant Ids that are allowed to communicate with your hubot. By default ALL Office365 tenants can communicate with your hubot if they sideload your application manifest.

# Contributing
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comm