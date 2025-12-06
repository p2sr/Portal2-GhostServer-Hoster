import { logger } from "./logger";
import { Request, Response, NextFunction } from "express";
import * as user_db from "../auth/account_manager";

/// Validates the provided auth token (cookie or Authorization header) and places the user object
/// from the database into the request's body.
export async function authMiddleware(req: Request, res: Response, next: NextFunction) {
	const authToken = req.header("Authorization")?.substring("Bearer ".length);
	if (!authToken) {
		logger.info({ source: "authMiddleware", message: `Validation failed: authToken not given to '${req.url}'` });
		res.status(400).send("Please provide an auth token");
		return;
	}

	await user_db.openDatabase();
	const user = await user_db.getUser(authToken);
	if (!user) {
		logger.info({ source: "authMiddleware", message: `Validation failed: authToken not valid to '${req.url}'` });
		res.status(401).send("Invalid auth token");
		return;
	}
	logger.info({ source: "authMiddleware", message: `Validation succeeded to '${req.url}'` });

	req.body.user = user;
	res.locals.authToken = authToken;
	next();
}
