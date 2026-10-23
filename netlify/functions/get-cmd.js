/**
 * Netlify Function — /api/get-cmd
 * GET  → PowerShell busca e limpa o comando (one-shot)
 * POST → painel web envia novo comando
 */

const ADMIN_PASS     = "27112025";
const JSONBIN_KEY    = "$2a$10$E5iuyg.pcXUG6Np8LTjcSeUxnaK96BFgFUBnYHks.TnRrOb0cLuBm";
const JSONBIN_BIN_ID = "6ad80d10ffd5d160537db66a";
const JSONBIN_BASE   = "https://api.jsonbin.io/v3/b";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Admin-Password",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function loadData() {
  try {
    const r = await fetch(`${JSONBIN_BASE}/${JSONBIN_BIN_ID}/latest`, {
      headers: { "X-Master-Key": JSONBIN_KEY, "X-Bin-Meta": "false" }
    });
    const d = await r.json();
    return d || {};
  } catch { return {}; }
}

async function saveData(data) {
  await fetch(`${JSONBIN_BASE}/${JSONBIN_BIN_ID}`, {
    method: "PUT",
    headers: { "X-Master-Key": JSONBIN_KEY, "Content-Type": "application/json" },
    body: JSON.stringify(data)
  });
}

exports.handler = async (event) => {
  if (event.httpMethod === "OPTIONS")
    return { statusCode: 204, headers: CORS, body: "" };

  // GET — PowerShell busca o comando atual
  if (event.httpMethod === "GET") {
    const data = await loadData();
    const cmd  = data.command || "";

    // Limpa após leitura (one-shot)
    if (cmd) {
      data.command = "";
      await saveData(data);
    }

    return {
      statusCode: 200,
      headers: { ...CORS, "Content-Type": "text/plain" },
      body: cmd
    };
  }

  // POST — painel envia comando
  if (event.httpMethod === "POST") {
    const pass = event.headers["x-admin-password"] || "";
    if (pass !== ADMIN_PASS)
      return { statusCode: 401, headers: CORS, body: JSON.stringify({ error: "Não autorizado" }) };

    const body = JSON.parse(event.body || "{}");
    const data = await loadData();
    data.command = body.command || "";
    await saveData(data);

    return {
      statusCode: 200,
      headers: { ...CORS, "Content-Type": "application/json" },
      body: JSON.stringify({ ok: true, command: data.command })
    };
  }

  return { statusCode: 405, headers: CORS, body: "Method not allowed" };
};
