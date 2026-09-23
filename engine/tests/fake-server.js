// Minimal fake MCP server for mcp-call tests. Responds per JSON-RPC method.
const http = require('http');
const port = Number(process.argv[2] || 0);
const sse = (res, obj) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'mcp-session-id': 'fake-session',
  });
  res.end('event: message\ndata: ' + JSON.stringify(obj) + '\n');
};
const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    let m = {};
    try { m = JSON.parse(Buffer.concat(chunks).toString()); } catch {}
    if (m.method === 'initialize')
      return sse(res, { id: 1, result: { protocolVersion: '2025-03-26', serverInfo: { name: 'fake-mcp', version: '0.1.0' } } });
    if (m.method === 'tools/list')
      return sse(res, { id: 2, result: { tools: [
        { name: 'echo', description: 'echoes text back', inputSchema: { type: 'object', properties: { text: { type: 'string' } } } },
      ] } });
    if (m.method === 'tools/call')
      return sse(res, { id: 3, result: { content: [{ type: 'text', text: 'hello from fake tool: ' + JSON.stringify(m.params.arguments) }] } });
    return sse(res, { id: m.id ?? null, error: { code: -32601, message: 'method not found: ' + (m.method || '?') } });
  });
});
server.listen(port, '127.0.0.1', () => console.log(server.address().port));
