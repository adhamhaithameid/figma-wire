// Minimal fake "Figma Dev Mode MCP Server" for hermetic tests.
// Usage: node fake-devmode-server.js [port]  — prints the bound port.
const http = require('http');
const port = Number(process.argv[2] || 0);
const body =
  'event: message\ndata: ' +
  JSON.stringify({
    result: {
      protocolVersion: '2025-03-26',
      capabilities: { tools: { listChanged: true } },
      serverInfo: { name: 'Figma Dev Mode MCP Server', version: '1.0.0' },
    },
  }) +
  '\n';
const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'mcp-session-id': 'fake-session-id',
    });
    res.end(body);
  });
});
server.listen(port, '127.0.0.1', () => {
  console.log(server.address().port);
});
