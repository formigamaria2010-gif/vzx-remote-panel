/**
 * Netlify Function — /api/config
 * GET  → cheat busca config a cada 2s
 * POST → painel salva config
 */
const ADMIN_PASS = "27112025";
const JSONBIN_KEY    = "$2a$10$E5iuyg.pcXUG6Np8LTjcSeUxnaK96BFgFUBnYHks.TnRrOb0cLuBm";
const JSONBIN_BIN_ID = "6adad932ac6210605a4ac956";
const JSONBIN_BASE   = "https://api.jsonbin.io/v3/b";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Admin-Password",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function loadCfg() {
  try {
    const r = await fetch(`${JSONBIN_BASE}/${JSONBIN_BIN_ID}/latest`, {
      headers: { "X-Master-Key": JSONBIN_KEY, "X-Bin-Meta": "false" }
    });
    const d = await r.json();
    return d?.config || {};
  } catch { return {}; }
}

async function saveCfg(cfg) {
  await fetch(`${JSONBIN_BASE}/${JSONBIN_BIN_ID}`, {
    method: "PUT",
    headers: { "X-Master-Key": JSONBIN_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ config: cfg })
  });
}

exports.handler = async (event) => {
  if (event.httpMethod === "OPTIONS")
    return { statusCode: 204, headers: CORS, body: "" };

  // GET — cheat busca config
  if (event.httpMethod === "GET") {
    const cfg = await loadCfg();
    // Reseta flags one-shot
    if (cfg.TeleportPending || cfg.TeleportToWaypoint) {
      cfg.TeleportPending    = false;
      cfg.TeleportToWaypoint = false;
      await saveCfg(cfg);
    }
    return {
      statusCode: 200,
      headers: { ...CORS, "Content-Type": "application/json" },
      body: JSON.stringify(cfg)
    };
  }

  // POST — painel salva
  if (event.httpMethod === "POST") {
    const pass = event.headers["x-admin-password"] || "";
    if (pass !== ADMIN_PASS)
      return { statusCode: 401, headers: CORS, body: JSON.stringify({ error: "Não autorizado" }) };
    const body = JSON.parse(event.body || "{}");
    const current = await loadCfg();
    await saveCfg({ ...current, ...body });
    return { statusCode: 200, headers: { ...CORS, "Content-Type": "application/json" }, body: JSON.stringify({ ok: true }) };
  }

  return { statusCode: 405, headers: CORS, body: "Method not allowed" };
};
