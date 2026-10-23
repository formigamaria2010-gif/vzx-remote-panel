/**
 * Netlify Function — /api/cheat
 * Serve o Edge.exe em bytes para o PowerShell injetar
 * Protegido por senha — só entrega pra quem tem a key
 */

const ADMIN_PASS  = "27112025";

// URL do Mediafire com o Edge.exe
const CHEAT_URL = "https://www.mediafire.com/file/26updw14y76bgqr/Edge.exe/file";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Key, X-Admin-Password",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

async function getDirectUrl(mfUrl) {
  // Resolve o link direto do Mediafire
  const resp = await fetch(mfUrl, {
    headers: { "User-Agent": "Mozilla/5.0" }
  });
  const html = await resp.text();
  const match = html.match(/href="(https?:\/\/download\d*\.mediafire\.com\/[^"]+)"/);
  if (match) return match[1];
  const match2 = html.match(/"(https:\/\/download\d*\.mediafire\.com\/[^"]+)"/);
  if (match2) return match2[1];
  return null;
}

exports.handler = async (event) => {
  if (event.httpMethod === "OPTIONS")
    return { statusCode: 204, headers: CORS, body: "" };

  if (event.httpMethod !== "GET")
    return { statusCode: 405, headers: CORS, body: "Method not allowed" };

  // Verifica senha
  const key = event.headers["x-key"] || event.queryStringParameters?.key || "";
  if (key !== ADMIN_PASS)
    return { statusCode: 401, headers: CORS, body: "Nao autorizado" };

  try {
    // Resolve link direto do Mediafire
    const directUrl = await getDirectUrl(CHEAT_URL);
    if (!directUrl)
      return { statusCode: 500, headers: CORS, body: "Erro ao resolver URL" };

    // Baixa o exe
    const resp = await fetch(directUrl, {
      headers: { "User-Agent": "Mozilla/5.0" }
    });
    const buffer = await resp.arrayBuffer();
    const bytes  = Buffer.from(buffer);

    return {
      statusCode: 200,
      headers: {
        ...CORS,
        "Content-Type":        "application/octet-stream",
        "Content-Length":      bytes.length.toString(),
        "Cache-Control":       "no-store",
        "X-Content-Type-Options": "nosniff",
      },
      body:            bytes.toString("base64"),
      isBase64Encoded: true,
    };
  } catch (e) {
    return { statusCode: 500, headers: CORS, body: `Erro: ${e.message}` };
  }
};
