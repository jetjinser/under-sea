"use strict";

// Hermes desktop shell: serve the source-built dashboard static export over a
// loopback HTTP server (the export uses absolute /_next/... URLs) and show it
// in an Electron BrowserWindow.
const { app, BrowserWindow } = require("electron");
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.resolve(process.env.HERMES_DASHBOARD_DIR || path.join(__dirname, "dashboard"));

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".map": "application/json",
};

function send(res, status, body, contentType) {
  res.writeHead(status, { "Content-Type": contentType });
  res.end(body);
}

function serve(request, response) {
  let pathname = decodeURIComponent((request.url || "/").split("?")[0]);
  if (pathname.endsWith("/")) pathname += "index.html";
  const file = path.normalize(path.join(root, pathname));
  if (!file.startsWith(root)) {
    send(response, 403, "Forbidden", "text/plain");
    return;
  }
  fs.readFile(file, (error, data) => {
    if (error) {
      fs.readFile(path.join(root, "404.html"), (fallbackError, fallback) => {
        if (fallbackError) send(response, 404, "Not found", "text/plain");
        else send(response, 404, fallback, "text/html; charset=utf-8");
      });
      return;
    }
    send(response, 200, data, types[path.extname(file).toLowerCase()] || "application/octet-stream");
  });
}

app.whenReady().then(() => {
  const server = http.createServer(serve);
  server.listen(0, "127.0.0.1", () => {
    const { port } = server.address();
    const window = new BrowserWindow({
      width: 1280,
      height: 800,
      title: "Hermes",
    });
    window.loadURL(`http://127.0.0.1:${port}/`);
  });
});

app.on("window-all-closed", () => app.quit());
