import express from "express";
import { logger } from "../util/logger";
import * as db from "../auth/account_manager";
import { authMiddleware } from "../util/middleware";
import { readFileSync } from "fs";
import { join } from "path";
import { sendMailHtml } from "../util/mailer";
import { deleteAllContainersFromUser } from "../api/docker_helper";
import * as container_db from "../api/container_db_manager";

export const router = express.Router();

router.use(async (req, res, next) => {
	await db.openDatabase();
	next();
});

router.post("/register", async (req, res) => {
	logger.info({ source: "register", message: "Route called" });

	if (!("email" in req.body)) {
		logger.warn({ source: "register", message: "No email in query. Exiting." });
		res.status(400).send("Expected email address");
		return;
	}
	else if (!("password" in req.body)) {
		logger.warn({ source: "register", message: "No password in query. Exiting." });
		res.status(400).send("Expected password");
		return;
	}

	const email = req.body.email.toString();
	const password = req.body.password.toString();

	const user = await db.createUser(email, password);
	if (!user) {
		logger.warn({ source: "register", message: "The user already exists" });
		res.status(409).send();
		return;
	}

	res.status(201).send();
});

router.post("/login", async (req, res) => {
	logger.info({ source: "login", message: "Route called" });

	if (!("email" in req.body)) {
		logger.warn({ source: "login", message: "No email in query. Exiting." });
		res.status(400).send("Expected email address");
		return;
	}
	else if (!("password" in req.body)) {
		logger.warn({ source: "login", message: "No password in query. Exiting." });
		res.status(400).send("Expected password");
		return;
	}

	const email = req.body.email.toString();
	const password = req.body.password.toString();

	const result = await db.checkCredentialsAndGenerateAuthToken(email, password);
	if (!result) {
		logger.warn({ source: "login", message: "User not found." });
		res.status(404).send("User not found");
		return;
	}

	const [authToken, expirationDate] = result;
	res.status(200).json({ "token": authToken, "expires": expirationDate.getTime() })
});

if (db.SUPPORTS_DISCORD_AUTH) {
	router.get("/discordOauth2Url", (req, res) => {
		res.status(200).send(db.getDiscordOauth2Url());
	});

	router.post("/finishDiscordOauth2Login", async (req, res) => {
		if (!("code" in req.body)) {
			res.status(400).send("Expected auth code");
			return;
		}

		try {
			const [authToken, expirationDate] = await db.finishDiscordOauth2Login(req.body.code);
			res.status(200).json({ "token": authToken, "expires": expirationDate.getTime() });
		} catch (error) {
			logger.error({ source: "finishDiscordOauth2Login", message: `Failed getting access token: ${error.message}` });
			res.status(500).send("Failed logging in with Discord");
		}
	});
}

router.get("/user", authMiddleware, (req, res) => {
	res.status(200).json(req.body.user);
});

router.delete("/user", authMiddleware, async (req, res) => {
	await container_db.openDatabase();
	await deleteAllContainersFromUser(req.body.user.id);
	await db.deleteUser(req.body.user.id);

	res.status(200).send();
});

router.post("/revokeToken", authMiddleware, async (req, res) => {
	await db.deleteAuthToken(res.locals.authToken);
	res.status(200).send();
});

router.get("/sendResetPassword", async (req, res) => {
	if (!("email" in req.query)) {
		res.status(400).send();
		return;
	}

	const email = req.query.email.toString();
	const token = await db.generatePasswordResetToken(email);
	if (token === undefined) {
		logger.warn({ source: "sendResetPassword", message: "Could not find the user." });
		res.status(400).send();
		return;
	}

	try {
		const html = readFileSync(join(__dirname, "../../res/reset-password_email.html"))
			.toString()
			.replace(/({host})/g, `${req.protocol}://${req.hostname}:8080`) // aka replaceAll
			.replace("{token}", token)
			.replace("{email}", email);

		await sendMailHtml(email, "Password reset", html);
	}
	catch {
		res.status(500).send();
		return;
	}

	res.status(200).send();
});

router.post("/validatePasswordResetCredentials", async (req, res) => {
	logger.info({ source: "validatePasswordResetCredentials", message: "Route called" });

	if (!("token" in req.body)) {
		logger.warn({ source: "validatePasswordResetCredentials", message: "No token given" });
		res.status(400).send();
		return;
	}

	if (!("email" in req.body)) {
		logger.warn({ source: "validatePasswordResetCredentials", message: "No email given" });
		res.status(400).send();
		return;
	}

	if (!await db.validatePasswordResetCredentials(req.body.token, req.body.email)) {
		logger.warn({ source: "validatePasswordResetCredentials", message: "Validation failed!" });
		res.status(401).send();
		return;
	}

	logger.info({ source: "validatePasswordResetCredentials", message: "Validation succeeded!" });
	res.status(200).send();
});

router.post("/resetPassword", async (req, res) => {
	logger.info({ source: "resetPassword", message: "Route called" });

	if (!("token" in req.body)) {
		logger.warn({ source: "resetPassword", message: "No token given" });
		res.status(400).send();
		return;
	}
	else if (!("email" in req.body)) {
		logger.warn({ source: "resetPassword", message: "No email given" });
		res.status(400).send();
		return;
	}
	else if (!("newPassword" in req.body)) {
		logger.warn({ source: "resetPassword", message: "No new password given" });
		res.status(400).send();
		return;
	}

	if (!await db.resetPassword(req.body.token, req.body.email, req.body.newPassword)) {
		logger.warn({ source: "resetPassword", message: "Password reset failed!" });
		res.status(500).send();
	}

	logger.info({ source: "resetPassword", message: "Reset password succeeded!" });
	res.status(200).send();
});

router.use(db.closeDatabase);
