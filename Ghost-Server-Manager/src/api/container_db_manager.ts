import { join } from "path";
import { Database as sqlite3Database } from "sqlite3";
import { open, Database } from "sqlite";
import { addHours, formatDistance } from "date-fns";
import { scheduleJob } from "node-schedule";
import * as docker from "./docker_helper";
import * as user_db from "../auth/account_manager";
import { logger } from "../util/logger";

const dbPath = join(__dirname, "../../db/containers.db");

var db: Database | undefined;

export class Container {
	id: number;
	containerId: string;
	port: number;
	wsPort: number;
	userId: number;
	name?: string;

	// Used by the website
	relativeRemainingDuration: string;

	constructor(id: number, containerId: string, port: number, wsPort: number, userId: number, expirationDate: number, name?: string) {
		this.id = id;
		this.containerId = containerId;
		this.port = port;
		this.wsPort = wsPort;
		this.userId = userId;
		this.name = name;

		this.relativeRemainingDuration = formatDistance(new Date(expirationDate), Date.now(), { addSuffix: true, includeSeconds: true });
	}

	static fromRow(row: any): Container {
		return new Container(row.id, row.container_id, row.port, row.ws_port, row.user_id, row.expirationDate, row.name);
	}
}

export async function openDatabase() {
	if (db) return;
	db = await open({ filename: dbPath, driver: sqlite3Database });

	// Create tables if necessary
	await db.run(`CREATE TABLE IF NOT EXISTS containers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        container_id TEXT NOT NULL,
        port NUMBER NOT NULL, 
        ws_port NUMBER NOT NULL,
		user_id NUMBER NOT NULL,
		name STRING
    );`);
}

export async function closeDatabase() {
	if (!db) return;
	await db.close();
	db = undefined;
}

export async function removeContainersNotRunning() {
	if (!db) await openDatabase();
	const runningContainerIds = await docker.getRunningContainerIds();
	await db?.run(`DELETE FROM containers WHERE container_id NOT IN (${runningContainerIds.map((_) => '?').join(',')})`, runningContainerIds);
}

export async function createContainer(id: string, port: number, wsPort: number, userId: number, name: string = "") {
	if (!db) await openDatabase();
	const expirationDate = addHours(Date.now(), 5);
	await db.run(`INSERT INTO containers 
		(container_id, port, ws_port, user_id, name, expirationDate) 
		VALUES (?, ?, ?, ?, ?, ?);`,
		[id, port, wsPort, userId, name, expirationDate.getTime()]);

	// Delete container after expiration date
	scheduleJob(expirationDate, async () => {
		if (!db) await openDatabase();
		// check if container already manually stopped
		if (!(await db.get("SELECT * FROM containers WHERE container_id = ?", [id]))) return;
		logger.info({ source: "deleteExpiredContainer", message: `Deleting expired container with ID ${id}` });
		await docker.stopContainer(port);
	});
}

export async function getContainersForUser(userId: number) {
	if (!db) await openDatabase();
	const rows = await db.all("SELECT * FROM containers WHERE user_id = ?", [userId]);
	return rows.map((row) => Container.fromRow(row));
}

export async function getAllContainers(): Promise<Container[]> {
	if (!db) await openDatabase();
	const rows = await db.all("SELECT * FROM containers");
	return rows.map(row => Container.fromRow(row));
}

export async function getContainer(id: number, user: user_db.User): Promise<Container | undefined> {
	if (!db) await openDatabase();
	let row = undefined;
	if (user.role !== user_db.Role.Admin) {
		row = await db.get("SELECT * FROM containers WHERE id = ? AND user_id = ?", [id, user.id]);
	} else {
		row = await db.get("SELECT * FROM containers WHERE id = ?", [id]);
	}
	if (!row) return;

	return Container.fromRow(row);
}

export async function getContainerFromParameter(param: any, user: user_db.User): Promise<Container | undefined> {
	const id = +param;
	if (isNaN(id) || !isFinite(id)) return undefined;
	return await getContainer(id, user)
}

export async function getAllColumnValues<T = any>(column: string): Promise<T[]> {
	if (!db) await openDatabase();
	const rows = await db.all(`SELECT ${column} FROM containers`);
	return rows;
}

export async function deleteContainer(id: number) {
	if (!db) await openDatabase();
	await db.run("DELETE FROM containers WHERE id = ?", [id]);
}
