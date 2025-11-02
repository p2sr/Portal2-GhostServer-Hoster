# Portal2-GhostServer-Hoster

A website for hosting [Ghost Servers](https://github.com/p2sr/GhostServer).

An official version of the website can be found at [ghost.portal2.sr](https://ghost.portal2.sr/), which is free to use for anyone!

## Building

### Prerequisites
- [Nodejs](https://nodejs.org/), [Docker](https://www.docker.com/) and [Flutter](https://flutter.dev) installed on your machine
- The repository cloned in a directory of your choice

### Ghost-Server-Host Module

1. Go into `/Ghost-Server-Host/root_image`
2. Run `docker build . -t ghost-server-hoster_base`
3. Go one directory up
4. Run `docker build . -t ghost-server-hoster`

### Ghost-Server-Manager

1. Go into `/Ghost-Server-Manager`
2. Create the files `users.db` and `containers.db` in `./db/`
3. Go into `./frontend/backend/backend.dart` and change the `_host` and optionally the `_baseUri` constants to reflect your server's host and protocol.
4. Run `npm install`
5. Run `npm start`. This will build the Flutter app and run the server.

Leave the Ghost-Server-Manager running in the background. It will serve the website and provide the API backend for it.

After a few seconds the server will start on port 8080 ("Server listening on port 8080" in console).
If you want to change that port, go into `/Ghost-Server-Manager/src/index.ts` and change the port in the last line of the file.

That's it! You can now access the website at \<hostname\>:<port (default 8080)>

#### Discord OAuth2

The Ghost-Server-Manager supports using Discord OAuth2 for user authentication. To configure Discord OAuth2, create an application on the 
[Discord Developer Portal](https://discord.com/developers/applications) and populate the `/Ghost-Server-Manager/.env` file with the following
content:

```sh
DISCORD_CLIENT_ID="<client ID>"
DISCORD_CLIENT_SECRET="<client secret>"
DISCORD_REDIRECT_URI="<host>/finish_discord_login" # (e.g. 'https://example.com/finish_discord_login)
```

The redirect URI needs to be registered in the applications settings!

Then, go into `/Ghost-Server-Manager/frontend/backend/backend.dart` and set the variable `kSupportsDiscordAuth` to `true`.

## Contributing

You can contribute to the project in different ways. You can use the official host of the website ([ghost.portal2.sr](https://ghost.portal2.sr/))
and report bugs either here under issues or on Discord on the [Portal 2 Speedrun Server](https://discord.gg/2PwGP73t).

Pull requests are also very welcome!

## Architecture

These are general notes on the architecture that makes the GhostServer-Hoster possible.

### Ghost-Server-Host

The Ghost-Server-Host package provides a wrapper around the C++ Ghost Server program.

Ghost Servers are managed using Docker, which allows us to dynamically create and destroy instances of the server program. To interact with the
server written in C++, we use a [Nodejs C++ Addon](https://nodejs.org/api/addons.html), which allows a Nodejs package to talk to C++ in a nice way.

Each Docker container exposes two ports: one port offering a management API and another that the Ghost Server listens for player connections on.
These ports are randomly selected when creating a server. The latter needs to be forwarded so that the players can properly connect to the Ghost
Server. The former allows the Ghost-Server-Manager to talk to the Ghost Server and relay the user settings from the webinterface, or start/stop 
the Ghost Server.

### Ghost-Server-Manager

The Ghost-Server-Manager manages Ghost Servers as well as user authentication and provides an API along with a webinterface to manage the servers.

The Ghost-Server-Manager uses SQLite to manage users and servers. It manages who owns a server and makes sure only the owner of the Ghost Server
(and selected admin users) can access the Ghost Server. When a user wants to create a Ghost Server, it randomly selects the ports the server
should be running on and instructs Docker to create a new container. Finally, it serves the webinterface written in Flutter and provides an
API for the webinterface to manage the Ghost Server.

The webinterface is written in Flutter for the web and provides an easy way for the user to manage and configure their Ghost Servers.

See [API.md](API.md) for a list of the API routes exposed by the Ghost-Server-Manager.