import { createTransport, Transporter } from "nodemailer";
import { readFile } from "fs";
import { join } from "path";
import { logger } from "./logger";
import { SentMessageInfo } from "nodemailer/lib/smtp-transport";

let transporter: Transporter<SentMessageInfo> | undefined = undefined;

const configFile = join(__dirname, "../../res/mail-account.json");

export function init() {
	return new Promise<void>((resolve, reject) => {
		readFile(configFile, (err, data) => {
			if (err) {
				logger.error({ source: "mailer", message: `Error reading config file at: ${configFile}`, error: err });
				reject();
				return;
			}

			const json = JSON.parse(data.toString());

			transporter = createTransport({
				service: json.service,
				auth: {
					user: json.user,
					pass: json.password
				}
			});

			logger.info({ source: "mailer", message: "Mailer successfully initialized!" });
			resolve();
		});
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
