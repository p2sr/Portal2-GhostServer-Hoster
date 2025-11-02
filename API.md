# Portal2-GhostServer-Hoster API

The following are the API routes exposed by the Ghost-Server-Manager.

## Authentication

Authentication of the client is handled through the `Authorization` header. The expected format is `Bearer <auth token>`.
See `/api/auth/login` route for how to obtain an auth token.

## Authentication routes

- Prefix: `/api/auth`

### `/register`

- Creating a new user.
- Authentication: No
- Method: POST

#### Request body:

```json
{
    "email": "<email>",
    "password": "<password",
}
```

#### Response

Status code `201` on success, a different error code otherwise. No response body. After registering, it is necessary
to call `/login` to receive an auth token.

### `/login`

- Exchanging user credentials for an auth token.
- Authentication: No
- Method: POST

#### Request body

```json
{
    "email": "<email>",
    "password": "<password"
}
```

#### Response

Status code `200` on success.

Response body:
```json
{
    "token": "<auth token>",
    "expires": <unix timestamp in milliseconds indicating when the token expires>
}
```

### `/discordOauth2Url`

- Returns the URL to redirect the user to for authentication with Discord OAuth2.
- Authentication: No
- Method: GET

#### Response

Status code 200 on success. The request body contains the URL to redirect the user to.

### `/finishDiscordOauth2Login`

- Finishes logging a user in with Discord OAuth2.
- Authentication: No
- Method: GET

#### Request body

```json
{
    "code": "<auth code returned by Discord>"
}
```

#### Response

Status code `200` on success.

Response body:
```json
{
    "token": "<auth token>",
    "expires": <unix timestamp in milliseconds indicating when the token expires>
}
```

### `/user`

- Returns the currently logged in user.
- Authentication: Yes
- Method: GET

#### Response

Status code 200.

Response body:
```json
{
    "id": "<user id>",
    "email": "<user email>",
    "role": "<user role, either 'user' or 'admin'>"
}
```

## General server routes

- Prefix: `/api/server`

### `/create`

- Creates a new Ghost Server.
- Authentication: Yes
- Method: POST

#### Request

No request body. Optionally provide a name for the server with the `name` query parameter (i.e. `/login?name=<name>`).

#### Response

Status code 201 on success.

### `/list`

- Lists all Ghost Servers owned by the user (optionally all Ghost Servers if the logged in user is an admin)
- Authentication: Yes
- Method: GET

#### Request

No request body. Optionally provide the `showAll=<0|1>` query parameter to return all running ghost servers,
regardless of the owner. This only has an effect for admin users.

#### Response

Status code 200 on success.

Response body:
```json
[
    {
        "id": "<container ID to be used in other requests>",
        "containerId": "<docker ID of the container>",
        "port": <port of the management interface>,
        "wsPort": <port that players should connect to>,
        "userId": <ID of the user owning the server>,
        "name": "<name of the server>",
        "relativeRemainingDuration": "<string indicating how long until the server expires in a human readable form (e.g. 'in about 5 hours')>"
    },
    ...
]
```

## Individual server routes

- Prefix: `/api/server/<id>`

### `/`

- Retrieve information about a specific server.
- Authentication: Yes
- Method: GET

#### Response

Status code 200 on success.

Response body:
```json
{
    "id": "<container ID to be used in other requests>",
    "containerId": "<docker ID of the container>",
    "port": <port of the management interface>,
    "wsPort": <port that players should connect to>,
    "userId": <ID of the user owning the server>,
    "name": "<name of the server>",
    "relativeRemainingDuration": "<string indicating how long until the server expires in a human readable form (e.g. 'in about 5 hours')>"
}
```

### `/`

- Delete the Ghost Server.
- Authentication: Yes
- Method: DELETE

#### Response

Status code 200 on success.

### `/listPlayers`

- Get the players currently connected to the Ghost Server.
- Authentication: Yes
- Method: GET

#### Response

Status code 200 on success.

Response body:
```json
[
    {
        "id": "<ID of the player, assigned by the Ghost Server>",
        "name": "<player name>",
        "isSpectator": <true if the player is a spectator, false otherwise>
    },
    ...
]
```

### `/settings`

- Get the current Ghost Server settings.
- Authentication: Yes
- Method: GET

#### Response

Status code 200 on success.

Response body:
```json
{
    "countdownDuration": <duration of the countdown in seconds>,
    "preCountdownCommands": "<commands to be executed on the client before the countdown>",
    "postCountdownCommands": "<commands to be executed on the client after the countdown>",
    "acceptingPlayers": <true if the Ghost Server is accepting new players, false otherwise>
    "acceptingSpectators": <true if the Ghost Server is accepting new spectators, false otherwise>
}
```

### `/settings`

- Update the Ghost Server settings.
- Authentication: Yes
- Method: PUT

#### Request body

```json
{
    "countdownDuration": <duration of the countdown in seconds>,
    "preCountdownCommands": "<commands to be executed on the client before the countdown>",
    "postCountdownCommands": "<commands to be executed on the client after the countdown>",
    "acceptingPlayers": <true if the Ghost Server should accept new players, false otherwise>
    "acceptingSpectators": <true if the Ghost Server should accept new spectators, false otherwise>
}
```

It is possible to leave out these fields, in which case the value remains unchanged for the unspecified keys.

#### Response

Status code 200 on success.

### `/startCountdown`

- Starts the countdown of the Ghost Server.
- Authentication: Yes
- Method: POST

#### Response

Status code 200 on success.

### `/serverMessage`

- Send a message to connected players as the server.
- Authentication: Yes
- Method: POST

#### Request

Provide the message using the `message` query parameter.

#### Response

Status code 200 on success.

### `/banPlayer`

- Permanently bans a player from connecting to the Ghost Server.
- Authentication: Yes
- Method: PUT

#### Request body

Either:
```json
{
    "id": <ID of the player to be banned>
}
```

or
```json
{
    "name": "<name of the player to be banned>"
}
```

#### Response

status code 200 on success.

### `/disconnectPlayer`

- Kick/disconnect a player from the Ghost Server. This allows them to reconnect.
- Authentication: Yes
- Method: PUT

#### Request body

Either:
```json
{
    "id": <ID of the player to be disconnected>
}
```

or
```json
{
    "name": "<name of the player to be disconnected>"
}
```

#### Response

Status code 200 on success.