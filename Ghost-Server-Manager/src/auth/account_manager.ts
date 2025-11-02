import { Database as sqlite3Database } from "sqlite3";
import { open, Database } from "sqlite";
import { join } from "path";
import { randomBytes } from "crypto";
import { addDays, addHours } from "date-fns";
import bcrypt from "bcrypt";
import { logger } from "../util/logger";
import { AuthorizationCode } from "simple-oauth2";
import axios from "axios";

const AUTH_TOKEN_DURATION_DAYS = 300;

const dbPath = join(__dirname, "../../db/users.db");

var db: Database | undefined;

export const SUPPORTS_DISCORD_AUTH = "DISCORD_CLIENT_ID" in process.env;
const DISCORD_OAUTH2_REDIRECT_URI = `${process.env.PROTOCOL}://${process.env.HOST}:${process.env.SERVER_PORT}/finish_discord_login`;

const discordOauth2Client = new AuthorizationCode({
	client: {
		id: process.env.DISCORD_CLIENT_ID || "",
		secret: process.env.DISCORD_CLIENT_SECRET || "",
	},
	auth: {
		tokenHost: "https://discord.com",
		authorizePath: "/oauth2/authorize",
		tokenPath: "/api/oauth2/token",
		revokePath: "/api/oauth2/token/revoke",
	},
});

export function getDiscordOauth2Url() {
	return discordOauth2Client.authorizeURL({
		scope: ["openid", "email"],
		redirect_uri: DISCORD_OAUTH2_REDIRECT_URI,
	});
}

export async function finishDiscordOauth2Login(authCode: string): Promise<[string, Date]> {
	const accessToken = await discordOauth2Client.getToken(
		{
			code: authCode,
			redirect_uri: DISCORD_OAUTH2_REDIRECT_URI,
		},
		// Discord apparently doesn't set the Content-Type header correctly for JSON
		{ json: "force" },
	);

	const discordUser = await axios.get(
		"https://discord.com/api/users/@me",
		{
			headers: { "Authorization": `Bearer ${accessToken.token.access_token}` }
		},
	);

	const email = discordUser.data["email"];

	var user = await getUserByEmail(email);
	if (user === undefined) {
		user = await createUser(email, undefined);
	}

	if (user !== undefined) {
		const existingAccessToken = await getAuthProviderAccessTokenJson(user.id, AuthProvider.Discord);
		if (existingAccessToken === undefined) {
			await registerAuthProvider(user.id, AuthProvider.Discord, JSON.stringify(accessToken));
		} else {
			discordOauth2Client.createToken(JSON.parse(existingAccessToken)).revokeAll();
			await updateAuthProviderAccessTokenJson(user.id, AuthProvider.Discord, JSON.stringify(accessToken));
		}
	}

	return await generateAuthToken(user.id);
}

export enum AuthProvider {
	Discord = "discord",
}

export enum Role {
	User = "user",
	Admin = "admin",
}

export class User {
	id: number;
	email: string;
	role: Role;

	constructor(id: number, email: string, role: Role) {
		this.id = id;
		this.email = email;
		this.role = role;
	}

	static fromRow(row: any): User {
		return new User(row.id, row.email, row.role === Role.Admin.toString() ? Role.Admin : Role.User);
	}
}

export async function openDatabase() {
	if (db) return;
	db = await open({ filename: dbPath, driver: sqlite3Database });

	// Create tables if necessary
	await db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        email TEXT NOT NULL, 
        passwordHash TEXT NOT NULL
    );`);

	try {
		await db.run(`ALTER TABLE users ADD role TEXT NOT NULL DEFAULT 'user'`);
	}
	catch { }

	await db.run(`CREATE TABLE IF NOT EXISTS auth_provider (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        provider TEXT NOT NULL,
		access_token_json TEXT
    );`);

	await db.run(`CREATE TABLE IF NOT EXISTS auth_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        user_id INTEGER NOT NULL, 
        token TEXT NOT NULL, 
        expirationDate NUMBER NOT NULL
    );`);

	await db.run(`CREATE TABLE IF NOT EXISTS password_reset_tokens (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		token TEXT NOT NULL,
		expirationDate NUMBER NOT NULL
	);`);
}

export async function closeDatabase() {
	if (db === undefined) return;
	await db.close();
	db = undefined;
}

export async function createUser(email: string, password: string | undefined): Promise<User | undefined> {
	if (!db) {
		logger.error({ source: "createUser", message: "Database not open!" });
		return undefined;
	}

	const row = await db.get(`SELECT * FROM users WHERE email = ?`, [email]);
	if (row) return undefined;

	const passwordHash = password !== undefined ? await getPasswordHash(password) : "";
	const newUser = await db.get("INSERT INTO users (email, passwordHash) VALUES (?, ?) RETURNING *", [email, passwordHash]);

	return User.fromRow(newUser);
}

export async function getAuthProviderAccessTokenJson(userId: number, provider: AuthProvider): Promise<string | undefined> {
	if (!db) return undefined;

	const row = await db.get("SELECT access_token_json FROM auth_provider WHERE user_id = ? AND provider = ?", [userId, provider.toString()]);
	if (!row) return undefined;

	return row.access_token_json;
}

export async function registerAuthProvider(userId: number, provider: AuthProvider, accessTokenJson: string) {
	if (!db) return;

	const user = await db.get("SELECT id FROM users WHERE id = ?", [userId]);
	if (!user) return;

	await db.run("INSERT INTO auth_provider (user_id, provider, access_token_json) VALUES (?, ?, ?)", [userId, provider.toString(), accessTokenJson]);
}

export async function updateAuthProviderAccessTokenJson(userId: number, provider: AuthProvider, accessTokenJson: string) {
	if (!db) return;
	await db.run("UPDATE auth_provider SET access_token_json = ? WHERE user_id = ? AND provider = ?", [accessTokenJson, userId, provider.toString()]);
}

export async function checkCredentialsAndGenerateAuthToken(email: string, password: string): Promise<[string, Date] | undefined> {
	if (!db) {
		logger.error({ source: "generateAuthToken", message: "Database not open!" });
		return;
	}

	const row = await db.get("SELECT * FROM users WHERE email = ?", [email]);
	if (!row) {
		logger.error({ source: "generateAuthToken", message: `No user matching email ${email} found!` });
		return;
	}

	const match = await bcrypt.compare(password, row.passwordHash);
	if (!match) {
		logger.warn({ source: "generateAuthToken", message: "Passwords don't match" });
		return;
	}

	return generateAuthToken(row.id);
}

/// Returns the auth token and its expiration date.
export async function generateAuthToken(userId: number): Promise<[string, Date] | undefined> {
	if (!db) {
		logger.error({ source: "generateAuthToken", message: "Database not open!" });
		return;
	}

	const authToken = randomBytes(30).toString('hex');
	// Hint: Parse expirationDate with new Date(expirationDate) :^)
	const expirationDate = addDays(Date.now(), AUTH_TOKEN_DURATION_DAYS);
	await db.run("INSERT INTO auth_tokens (user_id, token, expirationDate) VALUES (?, ?, ?);", [userId, authToken, expirationDate.getTime()]);

	return [authToken, expirationDate];
}

export async function getUserByEmail(email: string): Promise<User | undefined> {
	if (!db) {
		logger.error({ source: "getUser", message: "Database not open!" });
		return;
	}

	const user = await db.get("SELECT * FROM users WHERE email = ?", [email]);
	if (!user) return;

	return User.fromRow(user);
}

export async function getUser(authToken: string): Promise<User | undefined> {
	if (!db) {
		logger.error({ source: "getUser", message: "Database not open!" });
		return;
	}

	// Delete expired authTokens
	await db.run("DELETE FROM auth_tokens WHERE expirationDate < ?", [Date.now()]);

	const authTokenRow = await db.get("SELECT * FROM auth_tokens WHERE token = ?", [authToken]);
	if (!authTokenRow) return;

	const userRow = await db.get("SELECT * FROM users WHERE id = ?", [authTokenRow.user_id]);
	if (!userRow) return;
	return User.fromRow(userRow);
}

export async function deleteUser(id: number) {
	await db.run("DELETE FROM auth_tokens WHERE user_id = ?", [id]);
	await db.run("DELETE FROM users WHERE id = ?", [id]);
}

export async function deleteAuthToken(token: string) {
	await db.run("DELETE FROM auth_tokens WHERE token = ?", [token]);
}

export async function generatePasswordResetToken(email: string): Promise<string | undefined> {
	if (!db) {
		logger.error({ source: "generatePasswordResetToken - DB", message: "Database not open!" });
		return;
	}

	await deleteExpiredPasswordResetTokens();

	const userRow = await db.get("SELECT * FROM users WHERE email = ?", [email]);
	if (!userRow) return;

	const row = await db.get("SELECT * FROM password_reset_tokens WHERE user_id = ?", [userRow.id]);
	if (row)
		await db.run("DELETE FROM password_reset_tokens WHERE user_id = ?", [userRow.id]);

	const token = randomBytes(30).toString('hex');
	const expirationDate = addHours(Date.now(), 5).getTime();
	await db.exec(`INSERT INTO password_reset_tokens (user_id, token, expirationDate) VALUES (${userRow.id}, '${token}', ${expirationDate});`);

	return token;
}

export async function validatePasswordResetCredentials(token: string, email: string): Promise<boolean> {
	if (!db) {
		logger.error({ source: "validatePasswordResetCredentials - DB", message: "Database not open!" });
		return false;
	}

	await deleteExpiredPasswordResetTokens();

	const tokenRow = await db.get("SELECT * FROM password_reset_tokens WHERE token = ?", [token]);
	if (!tokenRow) return false;

	const userRow = await db.get("SELECT * FROM users WHERE id = ?", [tokenRow.user_id]);
	if (!userRow) return false;
	if (userRow.email !== email) return false;

	return true;
}

export async function resetPassword(token: string, email: string, newPassword: string): Promise<boolean> {
	if (!db) return false;

	await deleteExpiredPasswordResetTokens();

	const tokenRow = await db.get("SELECT * FROM password_reset_tokens WHERE token = ?", [token]);
	if (!tokenRow) return;

	const newPasswordHash = await getPasswordHash(newPassword);
	await db.run(`UPDATE users SET passwordHash = '${newPasswordHash}' WHERE id = ?`, [tokenRow.user_id]);
	await db.run("DELETE FROM password_reset_tokens WHERE id = ?", [tokenRow.id]);

	return true;
}

function deleteExpiredPasswordResetTokens() {
	return db.run("DELETE FROM password_reset_tokens WHERE expirationDate < ?", [Date.now()]);
}

function getPasswordHash(password: string): Promise<string> {
	return bcrypt.hash(password, 10); // Last parameter is the number of salt rounds, 10 is fine
}