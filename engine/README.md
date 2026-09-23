# mcp-wire engine

A full MCP (Model Context Protocol) client in one bash script: handshake →
JSON-RPC → SSE parsing → results. Text to stdout, images straight to PNG.
No SDK, no node app, no MCP harness required — bash, curl, jq.

This is the engine that powers the [mcp-wire skill family](../README.md); figma-wire's
`call` command was its first proof.

## Use

```bash
# install the CLI (bin: `mcp-wire`) — single file, no npm required
curl -fsSL https://raw.githubusercontent.com/adhamhaithameid/mcp-wire/main/engine/mcp-wire.sh -o /usr/local/bin/mcp-wire
chmod +x /usr/local/bin/mcp-wire

engine/mcp-wire.sh <server-url> list                   # list the server's tools
engine/mcp-wire.sh <server-url> call <tool> ['{json}'] # invoke a tool
engine/mcp-wire.sh <server-url> raw '<jsonrpc-body>'   # raw JSON-RPC after handshake
```

> An npm package (`@adhamhaithameid/mcp-wire`) is prepared but pending — npm's
> new-package policy requires a TOTP-style authenticator on the account at first
> publish, which this passkey-only account intentionally doesn't use. The GitHub
> install above is fully supported and always current.

| Flag | Purpose |
|---|---|
| `--header 'Name: value'` | extra request header, repeatable (e.g. `Authorization`) |
| `--timeout N` | seconds per request (default 90) |
| `-o PREFIX` | text → `PREFIX.txt`, images → `PREFIX-N.png` |
| `--allow-http` | permit plain-http targets (localhost dev servers) — refused by default |

## Tests

```bash
bash tests/run-tests.sh   # hermetic — spins up a local fake MCP server
```

## Roadmap

- stdio transport (spawn a local command server, speak JSON-RPC over pipes)
- named auth profiles (`mcp-wire auth add figma` → `--profile figma`)
- SSE streaming output for long-running tools
- resources/prompts surface (`resources list`, `prompts get`)
- `--jq` filter flag for shaping JSON results inline
