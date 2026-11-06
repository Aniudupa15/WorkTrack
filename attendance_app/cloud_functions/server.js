// PunchIn backend as a plain Node web service (Render), for when Cloud
// Functions aren't available. Same code as index.js, served by host.js.
//
//   POST /call/<name>   Firebase callable protocol (the app's httpsCallableFromUrl)
//   POST /tick          the 5-minute job; needs "Authorization: Bearer $CRON_KEY"
//   GET  /health        liveness check
//
// Env: FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY (service account),
// CRON_KEY, optional FIREBASE_PROJECT_ID / FIREBASE_STORAGE_BUCKET, PORT.
const http = require("http");
const { timingSafeEqual } = require("crypto");
const { handleCall, tick } = require("./host");

const MAX_BODY = 1024 * 1024;

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (c) => {
      size += c.length;
      if (size > MAX_BODY) { reject(new Error("too large")); req.destroy(); return; }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function send(res, { status, headers, body }) {
  res.writeHead(status, headers);
  res.end(body);
}

function cronAllowed(header) {
  const key = process.env.CRON_KEY;
  if (!key || key.length < 16) return false;
  const given = Buffer.from(/^Bearer\s+(.+)$/i.exec(header || "")?.[1] || "");
  const want = Buffer.from(key);
  return given.length === want.length && timingSafeEqual(given, want);
}

let ticking = false;

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  try {
    if (url.pathname === "/health") {
      return send(res, { status: 200, headers: { "Content-Type": "text/plain" }, body: "ok" });
    }
    // Same path shape as the functions URL, so only the base changes.
    if (url.pathname === "/call/razorpayWebhook" || url.pathname === "/razorpayWebhook") {
      const raw = req.method === "POST" ? await readBody(req) : "";
      let parsed = {};
      try { parsed = JSON.parse(raw || "{}"); } catch { /* the handler rejects it */ }
      const shim = {
        method: req.method,
        body: parsed,
        rawBody: Buffer.from(raw, "utf8"),
        get: (h) => req.headers[String(h).toLowerCase()],
      };
      let status = 200;
      const out = {
        status(code) { status = code; return out; },
        send(body = "") { send(res, { status, headers: { "Content-Type": "text/plain" }, body: String(body) }); return out; },
        json(body) { send(res, { status, headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }); return out; },
        end(body = "") { return out.send(body); },
      };
      await require("./index").razorpayWebhook(shim, out);
      if (!res.writableEnded) send(res, { status, headers: {}, body: "" });
      return;
    }
    const call = /^\/call\/([A-Za-z]+)$/.exec(url.pathname);
    if (call) {
      const body = req.method === "POST" ? await readBody(req) : "";
      return send(res, await handleCall({ method: req.method, name: call[1], authorization: req.headers.authorization, body }));
    }
    if (url.pathname === "/tick" && req.method === "POST") {
      if (!cronAllowed(req.headers.authorization)) return send(res, { status: 401, headers: {}, body: "" });
      if (ticking) return send(res, { status: 202, headers: { "Content-Type": "application/json" }, body: '{"busy":true}' });
      ticking = true;
      try {
        const report = await tick();
        return send(res, { status: 200, headers: { "Content-Type": "application/json" }, body: JSON.stringify(report) });
      } finally {
        ticking = false;
      }
    }
    send(res, { status: 404, headers: {}, body: "" });
  } catch (error) {
    console.error("request failed", error);
    if (!res.headersSent) send(res, { status: 500, headers: {}, body: "" });
  }
});

const port = Number(process.env.PORT) || 8080;
server.listen(port, () => console.log(`PunchIn backend on :${port}`));
