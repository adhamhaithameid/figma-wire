---
name: mcp-wire
description: Call any MCP (Model Context Protocol) server from plain bash — list tools, invoke tools, parse results — when no MCP client, SDK, or harness support is available. Use when the user gives an MCP server URL, asks to test or use an MCP server from the CLI or CI, or needs tool results from a server the agent cannot reach natively.
---

# mcp-wire

Speak MCP (Model Context Protocol) from plain bash: full handshake, JSON-RPC, SSE
parsing. Text results go to stdout; image results are saved as PNG files.
Requires bash, curl, jq.

## Install (once per machine)

```bash
curl -fsSL https://raw.githubusercontent.com/adhamhaithameid/mcp-wire/main/engine/mcp-wire.sh -o /usr/local/bin/mcp-wire
chmod +x /usr/local/bin/mcp-wire
```

Working inside the mcp-wire monorepo? Use the repo-local engine instead:
`engine/mcp-wire.sh` — same interface.

## Commands

```bash
mcp-wire <server-url> list                    # list the server's tools
mcp-wire <server-url> call <tool> '<json>'    # invoke a tool
mcp-wire <server-url> raw '<jsonrpc-body>'    # raw JSON-RPC after handshake
```

| Flag | Purpose |
|---|---|
| `--header 'Name: value'` | extra request header, repeatable (e.g. `Authorization: Bearer $T`) |
| `--timeout N` | seconds per request (default 90) |
| `-o PREFIX` | text → `PREFIX.txt`, images → `PREFIX-N.png` |
| `--allow-http` | permit plain-http targets (localhost dev servers) — refused by default |

## Rules

- Credentials go in `--header` flags only — never write tokens to files or state.
- `--allow-http` is for localhost/dev servers; keep it off for anything remote.
- Read the result before acting on it: text prints to stdout, saved file paths appear
  on the `saved:` line. A tool-level error exits nonzero with the message on stderr.

## Examples

```bash
# discover what a Figma MCP server offers
mcp-wire https://mcp.figma.com/mcp list --header "Authorization: Bearer $T"

# pull a design screenshot from a local Dev Mode server
mcp-wire http://127.0.0.1:3845/mcp call get_screenshot '{"nodeId":"1:2"}' -o shot --allow-http

# raw ping when debugging connectivity
mcp-wire "$URL" raw '{"jsonrpc":"2.0","id":9,"method":"ping"}'
```

Full engine docs: `engine/README.md` in the [mcp-wire monorepo](https://github.com/adhamhaithameid/mcp-wire).
