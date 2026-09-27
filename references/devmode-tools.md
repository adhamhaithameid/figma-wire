# Figma Dev Mode MCP — tool catalog

Verified live on this machine (port 3845, server "Figma Dev Mode MCP Server" v1.0.0).
All tools take the file currently **open in the Figma desktop app**; with no `nodeId`
most tools act on the **current selection**. In ZCode these appear as
`mcp__figma-local__<name>` (or `mcp__figma__<name>` for the remote server).

| Tool | Args | Purpose |
|---|---|---|
| `get_design_context` | `nodeId`, `artifactType`, `clientFrameworks`, `clientLanguages`, `excludeScreenshot`, `forceCode`, `taskType` | **Primary tool, call first.** Structured design + reference code + screenshot + metadata for one node. |
| `get_metadata` | `nodeId`, `clientFrameworks`, `clientLanguages` | XML node map. Use only when `get_design_context` is too large — then re-fetch just the child nodes you need. |
| `get_screenshot` | `nodeId`, `contentsOnly` | Visual ground truth for a node or the current selection. Works on `/design/` files and FigJam boards. |
| `get_variable_defs` | `nodeId`, `clientFrameworks`, `clientLanguages` | Design tokens/variables, e.g. `{'icon/default/secondary': '#949494'}`. |
| `get_motion_context` | `nodeId`, `recursive`, `clientFrameworks`, `clientLanguages` | Keyframe tracks, easing curves, pre-computed CSS/`@keyframes` for animation work. |
| `get_figjam` | `nodeId`, `includeImagesOfNodes` | UI code from FigJam nodes. |

## Required implementation flow

1. `get_design_context` for the exact node.
2. Too large / truncated → `get_metadata`, then re-fetch only needed nodes with `get_design_context`.
3. `get_screenshot` for the variant being implemented.
4. Only then implement. `get_variable_defs` for tokens; `get_motion_context` for motion.

## nodeId format

Share links carry `node-id=123-456` (dash). The tools accept the colon form
(`123:456`) — try that first, fall back to the dash form if a tool returns
not-found. `figma-wire link <url>` prints both.

## Assets

If any tool returns a `localhost` URL for an image/SVG, use it directly. Do not
create placeholders and do not add icon packages — all assets come in the payload.
