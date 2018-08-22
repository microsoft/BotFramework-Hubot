# A data structure used for constructing follow up commands in cards
# created for hubot repsonses sent to Microsoft Teams. Separates hubot
# queries into text parts and user provided input parts. The '/'
# character is used to indicate inputs with finite choices rather than
# accepting the input as a text field.
# Only queries used as a follow up query in the HubotResponseCards data
# structure are included, not all hubot commands.

HubotQueryParts = {
    "gho":
        "textParts": [
            "hubot gho"
        ]
    "gho list (teams|repos|members)":
        "textParts": [
            "hubot gho list "
        ]
        "inputParts": [
            "List what?/teams or repos or members"
        ]
    "gho list public repos":
        "textParts": [
            "hubot gho list public repos"
        ]
    "gho create team <team name>":
        "textParts": [
            "hubot gho create team "
        ]
        "inputParts": [
            "What is the name of the team to create? (Max 1024 characters)"
        ]
    "gho create repo <repo name>/<private|public>":
        "textParts": [
            "hubot gho create repo ",
            "/"
        ]
        "inputParts": [
            "What is the name of the repo to create? (Max 1024 characters)",
            "Public or private?/public or private"
        ]
    "gho add (members|repos) <members|repos> to team <team name>":
        "textParts": [
            "hubot gho add ",
            " ",
            " to team "
        ]
        "inputParts": [
            "Add members or repos?/members or repos",
            "Input a comma separated list to add",
            "What is the name of the team to add to?"
        ]
    "gho remove (repos|members) <members|repos> from team <team name>":
        "textParts": [
            "hubot gho remove ",
            " ",
            " from team "
        ]
        "inputParts": [
            "Remove members or repos?/members or repos",
            "Input a comma separated list to remove",
            "What is the name of the team to remove from?"
        ]
    "gho delete team <team name>":
        "textParts": [
            "hubot gho delete team "
        ]
        "inputParts": [
            "What is the name of the team to delete? (Max 1024 characters)"
        ]
}

module.exports = HubotQueryParts
