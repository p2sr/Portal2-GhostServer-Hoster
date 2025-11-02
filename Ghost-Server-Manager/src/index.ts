import express from "express";
import cors from "cors";
import { router as authRouter } from "./auth/auth_router";
import { router as serverRouter } from "./api/server_router";
import path from "path";
import bodyParser from "body-parser";
import cookieParser from "cookie-parser";
import { init } from "./util/mailer";

const app = express();

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

app.listen(+process.env.SERVER_PORT || 8080, () => { console.log("Server listening on port 8080"); });
