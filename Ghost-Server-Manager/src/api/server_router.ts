import { logger } from "../util/logger";
import express, { Request, Response } from "express";
import { authMiddleware } from "../util/middleware";
import * as db from "./container_db_manager";
import axios, { AxiosResponse, Method } from "axios";
import * as user_db from "../auth/account_manager";
import * as docker from "./docker_helper";

const MAX_NUMBER_OF_GHOST_SERVERS = parseInt(process.env.MAX_NUMBER_OF_GHOST_SERVERS || "10", 10);

export const router = express.Router();

router.use(authMiddleware);

router.post("/create", async (req, res) => {
	try {
		await db.openDatabase();

		logger.info({ source: "createServer", message: "Route called" });

		const ports = await db.getAllColumnValues<number>("port");
		if (ports.length >= MAX_NUMBER_OF_GHOST_SERVERS) {
			logger.error({ source: "createServer", message: "Max number of concurrent ghost servers" });
			res.status(507).send("Max number of concurrent ghost servers");
			return;
		}

		const wsPorts = await db.getAllColumnValues<number>("ws_port");

		const port = randomRangeNotIn(5000, 10000, ports);
		const wsPort = randomRangeNotIn(45000, 50000, wsPorts);
		if (port === undefined || wsPort === undefined) {
			logger.error({ source: "createServer", message: "No available ports" });
			res.status(507).send("No available ports");
			return;
		}

		try {
			const containerId = await docker.createContainer(port, wsPort);

			const name = "name" in req.query ? req.query.name.toString() : "Ghost Server"
			db.createContainer(containerId, port, wsPort, req.body.user.id, name);
		} catch (error) {
			logger.error({ source: "createServer", message: `Failed to create container: ${error}` });
			res.status(500).send("Failed to create container");
			return;
		}

		res.status(201).send();
	} catch (error) {
		logger.error({ source: "createServer", message: `Error in create server route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/list", async (req, res) => {
	try {
		await db.openDatabase();
		await db.removeContainersNotRunning();

		if (req.body.user.role === user_db.Role.Admin && "showAll" in req.query) {
			if (req.query.showAll === "1") {
				res.status(200).json(await db.getAllContainers());
				return;
			}
		}

		const containers = await db.getContainersForUser(req.body.user.id);
		res.status(200).json(containers);
	} catch (error) {
		logger.error({ source: "listServers", message: `Error in list servers route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/:id", async (req, res) => {
	try {
		await db.openDatabase();
		const container = await db.getContainerFromParameter(req.params["id"], req.body.user);
		if (container === undefined) {
			res.status(400).send("Invalid container ID");
			return;
		}

		res.status(200).json(container);
	} catch (error) {
		logger.error({ source: "getServer", message: `Error in get server route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.delete("/:id", async (req, res) => {
	try {
		await db.openDatabase();
		logger.info({ source: "delete", message: "Route called" });

		const container = await db.getContainerFromParameter(req.params["id"], req.body.user);
		if (container === undefined) {
			res.status(400).send("Invalid container ID");
			return;
		}

		await db.deleteContainer(container.id);
		await docker.stopContainer(container.port, true);

		logger.info({ source: "delete", message: "Successfully stopped and deleted the container" });
		res.status(200).send();
	} catch (error) {
		logger.error({ source: "delete", message: `Error in delete server route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/:id/listPlayers", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/listPlayers", "GET");
	} catch (error) {
		logger.error({ source: "listPlayers", message: `Error in list players route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/:id/listPlayers/stream", async (req, res) => {
	try {
		await db.openDatabase();
		const container = await db.getContainerFromParameter(req.params["id"], req.body.user);
		if (container === undefined) {
			res.status(400).send("Invalid container ID");
			return;
		}

		res.setHeader('Cache-Control', 'no-cache');
		res.setHeader('Content-Type', 'text/event-stream');
		res.setHeader('Access-Control-Allow-Origin', '*');
		res.setHeader('Connection', 'keep-alive');
		res.flushHeaders(); // flush the headers to establish SSE with client

		const cancelToken = axios.CancelToken.source();
		const containerResponse = await axios({
			url: `http://localhost:${container.port}/listPlayers/stream`,
			method: "GET",
			validateStatus: () => true,
			responseType: "stream",
			cancelToken: cancelToken.token,
		});

		// forward stream to client
		containerResponse.data.pipe(res);
		containerResponse.data.on('close', () => res.end());

		// if client closes connection, stop sending events
		res.on('close', () => {
			cancelToken.cancel();
			res.end();
		});
	} catch (error) {
		logger.error({ source: "listPlayersStream", message: `Error in list players stream route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/:id/settings", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/settings", "GET");
	} catch (error) {
		logger.error({ source: "getSettings", message: `Error in get settings route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.put("/:id/settings", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/settings", "PUT");
	} catch (error) {
		logger.error({ source: "updateSettings", message: `Error in update settings route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.post("/:id/startCountdown", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/startCountdown", "PUT");
	} catch (error) {
		logger.error({ source: "startCountdown", message: `Error in start countdown route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.post("/:id/serverMessage", async (req, res) => {
	try {
		await db.openDatabase();
		if (!("message" in req.query)) {
			res.status(400).send();
			return;
		}

		const container = await db.getContainerFromParameter(req.params["id"], req.body.user);
		if (container === undefined) {
			res.status(400).send("Invalid container ID");
			return;
		}

		await sendToContainer(container, `/serverMessage?message=${req.query.message.toString()}`, "PUT");
		res.status(200).send();
	} catch (error) {
		logger.error({ source: "serverMessage", message: `Error in server message route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.put("/:id/banPlayer", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/banPlayer", "PUT");
	} catch (error) {
		logger.error({ source: "banPlayer", message: `Error in ban player route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.put("/:id/disconnectPlayer", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/disconnectPlayer", "PUT");
	} catch (error) {
		logger.error({ source: "disconnectPlayer", message: `Error in disconnect player route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.get("/:id/whitelist", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/whitelist", "GET");
	} catch (error) {
		logger.error({ source: "getWhitelist", message: `Error in get whitelist route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.put("/:id/whitelist/status", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/whitelist/status", "PUT");
	} catch (error) {
		logger.error({ source: "updateWhitelistStatus", message: `Error in update whitelist status route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.put("/:id/whitelist", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/whitelist", "PUT");
	} catch (error) {
		logger.error({ source: "updateWhitelist", message: `Error in update whitelist route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

router.delete("/:id/whitelist", async (req, res) => {
	try {
		await passthroughToContainer(req, res, "/whitelist", "DELETE");
	} catch (error) {
		logger.error({ source: "deleteWhitelist", message: `Error in delete whitelist route: ${error}` });
		res.status(500).send("Internal server error");
	}
});

async function passthroughToContainer(req: Request, res: Response, route: string, method: Method) {
	try {
		await db.openDatabase();
		const container = await db.getContainerFromParameter(req.params["id"], req.body.user);
		if (container === undefined) {
			res.status(400).send("Invalid container ID");
			return;
		}

		const response = await sendToContainer(container, route, method, req.body);
		res.status(response.status).json(response.data);
	} catch (error) {
		logger.error({ source: "passthrough", message: `Error in passthrough to container: ${error}` });
		throw error;
	}
}

function sendToContainer(container: db.Container, route: string, method: Method, data: any = undefined) {
	return axios({
		url: `http://localhost:${container.port}${route}`,
		method: method,
		headers: { "Content-Type": "application/json" },
		data: data,
		validateStatus: () => true,
	});
}

router.use(db.closeDatabase, user_db.closeDatabase);

function randomRangeNotIn(min: number, max: number, numbers: number[]): number | undefined {
	if (numbers.length >= (max - min)) return undefined;

	let number: number;
	do {
		number = Math.floor(Math.random() * (max - min) + min);
	}
	while (numbers.indexOf(number) !== -1);

	return number;
}
