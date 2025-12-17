import { createTransport, Transporter } from "nodemailer";
import { readFile } from "fs";
import { join } from "path";
import { logger } from "./logger";
import { SentMessageInfo } from "nodemailer/lib/smtp-transport";

let transporter: Transporter<SentMessageInfo> | undefined = undefined;

export function init() {
	return new Promise<void>((resolve, reject) => {
		if (process.env.MAILER_SERVICE !== undefined ||
			process.env.MAILER_USER !== undefined ||
			process.env.MAILER_PASSWORD !== undefined) {

			try {
				transporter = createTransport({
					service: process.env.MAILER_SERVICE,
					auth: {
						user: process.env.MAILER_USER,
						pass: process.env.MAILER_PASSWORD
					}
				});
				logger.info({ source: "mailer", message: "Mailer successfully initialised!" });
				resolve();
			} catch (error) {
				logger.error({ source: "mailer", message: "Error initialising mailer.", error });
				reject();
			}
		} else {
			logger.warn({ source: "mailer", message: "Mailer environment variable(s) not set, not initialising." });
			reject();
		}
	});
}

export async function sendMailHtml(recipient: string, subject: string, html: string) {
	if (transporter === undefined) {
		logger.warn({ source: "mailer", message: "Transporter not initialized. Attempting initialisation..." });
		try {
			await init();
		}
		catch {
			logger.error({ source: "mailer", message: "Transporter initialisation failed. Cancelling." });
			return;
		}
	}

	return new Promise<void>((resolve, reject) => {
		transporter.sendMail({
			to: recipient,
			subject: subject,
			html: html
		}, (err, _) => {
			if (err) {
				logger.error({ source: "mailer", message: `Sending email to ${recipient} failed!`, error: err });
				reject();
				return;
			}

			logger.info({ source: "mailer", message: `Successfully sent email to ${recipient}!` });
			resolve();
			return;
		});
	});
}
