#!/usr/bin/env bash
# mcp-wire — call any MCP (Model Context Protocol) server from plain bash.
# No SDK, no MCP client, no node app required. Just bash + curl + jq.
#
#   mcp-wire <server-url> list
#   mcp-wire <server-url> call <tool> ['{"arg":"value"}'] [-o out-prefix]
#   mcp-wire <server-url> raw '<full-jsonrpc-body>'
#
# Flags: --header 'Name: value' (repeatable) · --timeout N (default 90)
#        --allow-http (required for non-https targets, e.g. localhost dev servers)
#
# Origin: extracted from figma-wire (https://github.com/adhamhaithameid/mcp-wire).
set -u -o pipefail

VERSION="0.1.0"
INIT_BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"mcp-wire","version":"1.0"}}}'

bad()  { printf '%s[FAIL]%s %s\n' "\033[31m" "\033[0m" "$*" >&2; }
ok()   { printf '%s[ ok ]%s %s\n' "\033[32m" "\033[0m" "$*"; }
info() { printf '%s[ .. ]%s %s\n' "\033[2m"  "\033[0m" "$*"; }

b64decode() { case "$(uname -s)" in Darwin) base64 -D ;; *) base64 -d ;; esac; }

usage() {
  cat <<'EOF'
mcp-wire — call any MCP server from plain bash

  mcp-wire <server-url> list                   list the server's tools
  mcp-wire <server-url> call <tool> [json]     invoke a tool; text → stdout, images → PNG
  mcp-wire <server-url> raw <body>             send a raw JSON-RPC body (after handshake)

  --header 'Name: value'    extra request header, repeatable (e.g. Authorization)
  --timeout N               seconds per request (default 90)
  -o PREFIX                 write text to PREFIX.txt and images to PREFIX-N.png
  --allow-http              permit non-https servers (localhost dev servers etc.)

Examples:
  mcp-wire https://mcp.figma.com/mcp list --header "Authorization: Bearer $T"
  mcp-wire http://127.0.0.1:3845/mcp call get_screenshot '{"nodeId":"1:2"}' -o shot --allow-http
EOF
}

# --- request: perform full handshake, send body, echo last SSE data line ----------
request() { # request <url> <body-json> <timeout> [header...]
  local url="$1" body="$2" timeout="$3"; shift 3
  local hdr tf sess
  hdr="$(mktemp)"; tf="$(mktemp)"
  curl -sS -D "$hdr" -o /dev/null --max-time 15 -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "$INIT_BODY" "$@" 2>/dev/null || { bad "initialize request failed"; rm -f "$hdr" "$tf"; return 1; }
  sess="$(grep -i '^mcp-session-id:' "$hdr" | tr -d '\r' | awk '{print $2}')"
  if [ -z "$sess" ]; then bad "server returned no mcp-session-id (is it a streamable-HTTP MCP server?)"; rm -f "$hdr" "$tf"; return 1; fi
  curl -sS --max-time 15 -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -H "mcp-session-id: $sess" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null 2>&1
  curl -sS --max-time "$timeout" -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -H "mcp-session-id: $sess" -d "$body" "$@" > "$tf" 2>/dev/null || { bad "request failed"; rm -f "$hdr" "$tf"; return 1; }
  rm -f "$hdr"
  grep '^data:' "$tf" | tail -1 | sed 's/^data: //'
  rm -f "$tf"
}

emit_result() { # emit_result <data-line> <out-prefix>
  local data="$1" prefix="$2" img_n=0 saved="" is_err
  is_err=$(jq -r '.result.isError // "false"' <<<"$data" 2>/dev/null)
  if jq -e '.error' <<<"$data" > /dev/null 2>&1; then
    bad "MCP error: $(jq -c '.error' <<<"$data")"; return 1
  fi
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    local itype itext
    itype=$(jq -r '.type // empty' <<<"$item" 2>/dev/null)
    case "$itype" in
      text|resource)
        itext=$(jq -r '.text // .uri // empty' <<<"$item" 2>/dev/null)
        if [ -n "$prefix" ]; then printf '%s\n' "$itext" >> "${prefix}.txt"; saved="$saved ${prefix}.txt"
        else printf '%s\n' "$itext"; fi
        ;;
      image)
        img_n=$((img_n+1))
        local mime ext imgfile
        mime=$(jq -r '.mimeType // "image/png"' <<<"$item")
        ext="${mime##*/}"; [ "$ext" = "jpeg" ] && ext="jpg"
        imgfile="${prefix:+${prefix}-}${img_n}.${ext}"
        [ -n "$prefix" ] || imgfile="mcp-wire-${img_n}.${ext}"
        jq -r '.data // empty' <<<"$item" | b64decode > "$imgfile" 2>/dev/null
        saved="$saved ${imgfile}"
        ;;
    esac
  done < <(jq -c '.result.content[]?' <<<"$data" 2>/dev/null)
  [ -n "$saved" ] && ok "saved:$saved"
  if [ -z "$saved" ] && [ -z "$prefix" ] && ! jq -e 'has("result") and (.result | has("content"))' <<<"$data" > /dev/null 2>&1; then
    jq '.result // .' <<<"$data"
  fi
  [ "$is_err" = "true" ] && { bad "tool reported an error"; return 1; }
  return 0
}

main() {
  local url="" headers=() timeout=90 prefix="" allow_http=0
  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --header) headers+=("-H" "${2:-}"); shift 2 || true ;;
      --header=*) headers+=("-H" "${1#--header=}"); shift ;;
      --timeout) timeout="${2:-90}"; shift 2 || true ;;
      --timeout=*) timeout="${1#--timeout=}"; shift ;;
      -o) prefix="${2:-}"; shift 2 || true ;;
      -o=*) prefix="${1#-o=}"; shift ;;
      --allow-http) allow_http=1; shift ;;
      -h|--help) usage; return 0 ;;
      --version|-V) echo "mcp-wire ${VERSION}"; return 0 ;;
      -*) bad "unknown flag: $1"; usage; return 1 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}

  [ $# -ge 1 ] || { usage; return 1; }
  url="$1"; shift

  case "$url" in
    https://*) : ;;
    http://*) [ $allow_http -eq 1 ] || { bad "refusing plain http:// — pass --allow-http for localhost/dev servers"; return 1; } ;;
    *) bad "server-url must start with http:// or https://"; return 1 ;;
  esac

  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  local body data
  case "$cmd" in
    list)
      body='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
      data=$(request "$url" "$body" "$timeout" ${headers[@]+"${headers[@]}"}) || return 1
      [ -z "$data" ] && { bad "empty response"; return 1; }
      local tools
      tools=$(jq -r '.result.tools[]? | .name + " :: " + ((.description // "")[0:120])' <<<"$data" 2>/dev/null)
      if [ -n "$tools" ]; then printf '%s\n' "$tools"; else jq '.result // .error // .' <<<"$data"; fi
      ;;
    call)
      local tool="${1:-}"; [ $# -gt 0 ] && shift
      [ -n "$tool" ] || { bad "usage: mcp-wire <url> call <tool> ['{json-args}']"; return 1; }
      local tool_args="{}"
      [ $# -ge 1 ] && tool_args="$1"
      body=$(jq -n --arg tool "$tool" --argjson args "$tool_args" \
        '{jsonrpc:"2.0", id:3, method:"tools/call", params:{name:$tool, arguments:$args}}') || { bad "args must be valid JSON (got: $tool_args)"; return 1; }
      data=$(request "$url" "$body" "$timeout" ${headers[@]+"${headers[@]}"}) || return 1
      [ -z "$data" ] && { bad "empty response"; return 1; }
      emit_result "$data" "$prefix"
      ;;
    raw)
      body="${1:-}"
      [ -n "$body" ] || { bad "usage: mcp-wire <url> raw '<jsonrpc-body>'"; return 1; }
      data=$(request "$url" "$body" "$timeout" ${headers[@]+"${headers[@]}"}) || return 1
      [ -z "$data" ] && { bad "empty response"; return 1; }
      emit_result "$data" "$prefix"
      ;;
    *) bad "unknown command: ${cmd}"; usage; return 1 ;;
  esac
}

main "$@"
