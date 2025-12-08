import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import { router as authRouter } from "./auth/auth_router";
import { router as serverRouter } from "./api/server_router";
import path from "path";
import bodyParser from "body-parser";
import cookieParser from "cookie-parser";
import { init } from "./util/mailer";
import https from "https";
import fs from "fs";

const app = express();

const urlDecodeCheck = (req: Request, res: Response, next: NextFunction) => {
    const raw = req.url || '';
    const pathOnly = raw.split('?')[0];
    try {
        decodeURIComponent(pathOnly);
        next();
    } catch (err: any) {
        if (err instanceof URIError) {
            return res.status(400).send('Bad Request');
        }
        next(err);
    }
};

app.use(urlDecodeCheck);

app.use(cors());

app.use(express.static(path.join(__dirname, '../frontend/build/web')));

app.use(cookieParser());
app.use(bodyParser.json({ limit: '20mb' }))

app.use("/api/auth", authRouter);
app.use("/api/server", serverRouter);

// We need to serve the Flutter app as a Single Page App which handles its own routing.
app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend/build/web/index.html"));
});

init().catch((_) => {});

const port = +process.env.SERVER_PORT || 8080;
if (process.env.PROTOCOL === "https") {
    const ssl_key = process.env.SSL_KEY || "key.pem";
    const ssl_cert = process.env.SSL_CERT || "cert.pem";
    const host = process.env.HOST || "localhost";
    if (!fs.existsSync(ssl_key) || !fs.existsSync(ssl_cert)) {
        console.error("SSL key or certificate file not found! Cannot start HTTPS server.");
        process.exit(1);
    }
    https.createServer({
        key: fs.readFileSync(ssl_key),
        cert: fs.readFileSync(ssl_cert),
    }, app).listen(port, () => { console.log(`HTTPS Server listening on port ${port}`); });

    // HTTP upgrade
    if (port !== 80) {
        var http = express();
        http.use(urlDecodeCheck);
        http.get('*', function(req, res) {
            res.redirect(`https://${host}:${port}${req.url}`);
        });
        http.listen(80, () => { console.log('HTTP Server listening on port 80 for upgrade to HTTPS'); });
    }
} else {
    app.listen(port, () => { console.log(`HTTP Server listening on port ${port}`); });
}
