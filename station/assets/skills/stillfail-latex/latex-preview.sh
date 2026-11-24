#!/usr/bin/env bash
# Initializes and launches Scholia (queelius/scholia) for a LaTeX paper on 127.0.0.1:$PORT,
# suitable for `job_start` web service previews and Git-synced review (.scholia/comments.json).
# Usage: bash latex-preview.sh [--dir <paper-dir>] [--main <file.tex>] [--port <port>] [--init-only] [--no-mcp] [--no-gitignore]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DIR="."
MAIN=""
PORT_ARG=""
INIT_ONLY=0
WRITE_MCP=1
WRITE_GITIGNORE=1
SCHOLIA_SPEC=${SCHOLIA_SPEC:-"scholia[mcp,image] @ git+https://github.com/queelius/scholia.git"}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR=${2:?missing value for --dir}; shift 2 ;;
    --main) MAIN=${2:?missing value for --main}; shift 2 ;;
    --port) PORT_ARG=${2:?missing value for --port}; shift 2 ;;
    --init-only) INIT_ONLY=1; shift ;;
    --no-mcp) WRITE_MCP=0; shift ;;
    --no-gitignore) WRITE_GITIGNORE=0; shift ;;
    -h|--help)
      sed -n '2,4p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

DIR=$(cd "$DIR" && pwd)
PORT=${PORT_ARG:-${PORT:-${SCHOLIA_PORT:-8765}}}

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "invalid port: $PORT" >&2
  exit 2
fi

# Verify that a candidate scholia executable is queelius/scholia (not PyPI's unrelated scholia 0.3.1).
is_queelius_scholia() {
  local bin=$1
  local help
  help=$("$bin" --help 2>&1 || true)
  [[ "$help" == *"serve"* && "$help" == *"mcp"* ]]
}

detect_main_tex() {
  python3 - "$DIR" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
candidates = sorted(p for p in root.glob("*.tex") if p.is_file())
if not candidates:
    candidates = sorted(p for p in root.rglob("*.tex") if p.is_file() and ".git" not in p.parts)

def has_documentclass(path: pathlib.Path) -> bool:
    try:
        text = path.read_text("utf-8", errors="ignore")[:8192]
    except OSError:
        return False
    return bool(re.search(r"^\s*\\documentclass\b", text, re.MULTILINE))

with_doc = [p for p in candidates if has_documentclass(p)]
pool = with_doc or candidates
for preferred in ("main.tex", "paper.tex", "manuscript.tex"):
    for p in pool:
        if p.name == preferred:
            print(p.relative_to(root).as_posix())
            sys.exit(0)
if pool:
    print(pool[0].relative_to(root).as_posix())
    sys.exit(0)
sys.exit(1)
PY
}

SCHOLIA_CMD=()
MCP_COMMAND=""
MCP_ARGS_JSON='["mcp"]'

if [ -n "${SCHOLIA_BIN:-}" ]; then
  if [ -x "$SCHOLIA_BIN" ] && is_queelius_scholia "$SCHOLIA_BIN"; then
    SCHOLIA_CMD=("$SCHOLIA_BIN")
    MCP_COMMAND="$SCHOLIA_BIN"
  else
    echo "SCHOLIA_BIN ($SCHOLIA_BIN) is not a valid queelius/scholia executable" >&2
    exit 1
  fi
elif command -v scholia >/dev/null 2>&1 && is_queelius_scholia "$(command -v scholia)"; then
  BIN=$(command -v scholia)
  SCHOLIA_CMD=("$BIN")
  MCP_COMMAND="$BIN"
elif [ "$INIT_ONLY" -eq 0 ]; then
  if command -v uvx >/dev/null 2>&1; then
    SCHOLIA_CMD=(uvx --from "$SCHOLIA_SPEC" scholia)
    MCP_COMMAND="uvx"
    MCP_ARGS_JSON=$(python3 -c 'import json,sys; print(json.dumps(["--from", sys.argv[1], "scholia", "mcp"]))' "$SCHOLIA_SPEC")
  else
    echo "queelius/scholia is not installed and uvx is unavailable." >&2
    echo "Note: do NOT run 'pip install scholia' (PyPI's package is unrelated)." >&2
    echo "Install with: uv tool install \"$SCHOLIA_SPEC\"  (or pip install \"$SCHOLIA_SPEC\")" >&2
    exit 1
  fi
else
  if command -v uvx >/dev/null 2>&1; then
    MCP_COMMAND="uvx"
    MCP_ARGS_JSON=$(python3 -c 'import json,sys; print(json.dumps(["--from", sys.argv[1], "scholia", "mcp"]))' "$SCHOLIA_SPEC")
  else
    MCP_COMMAND="scholia"
  fi
fi

# Ensure .scholia.yaml exists.
CONFIG_PATH="$DIR/.scholia.yaml"
if [ ! -f "$CONFIG_PATH" ]; then
  if [ -z "$MAIN" ]; then
    if ! MAIN=$(detect_main_tex); then
      echo "no .tex file found in $DIR; pass --main <file.tex>" >&2
      exit 1
    fi
  fi
  cat > "$CONFIG_PATH" <<EOF
main: $MAIN
watch:
  - "*.tex"
  - "*.bib"
ignore:
  - "*_backup.tex"
compiler: auto
port: $PORT
EOF
fi

# Register scholia MCP server in .mcp.json (preserving any existing entries).
if [ "$WRITE_MCP" -eq 1 ]; then
  python3 - "$DIR/.mcp.json" "$MCP_COMMAND" "$MCP_ARGS_JSON" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
command = sys.argv[2]
args = json.loads(sys.argv[3])

data = {}
if path.exists():
    try:
        parsed = json.loads(path.read_text("utf-8"))
        if isinstance(parsed, dict):
            data = parsed
    except Exception:
        data = {}

servers = data.get("mcpServers")
if not isinstance(servers, dict):
    servers = {}
servers["scholia"] = {"command": command, "args": args}
data["mcpServers"] = servers
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
fi

# Ensure .gitignore ignores TeX build outputs and .mcp.json while keeping .scholia/comments.json tracked.
if [ "$WRITE_GITIGNORE" -eq 1 ] && [ -f "$SCRIPT_DIR/scholia-ctl.py" ]; then
  python3 "$SCRIPT_DIR/scholia-ctl.py" git-setup --dir "$DIR" >/dev/null
fi

if [ "$INIT_ONLY" -eq 1 ]; then
  echo "Initialized Scholia in $DIR (config: .scholia.yaml, port: $PORT)"
  exit 0
fi

# Verify a TeX compiler is present before launching the daemon.
if ! command -v latexmk >/dev/null 2>&1 \
   && ! command -v pdflatex >/dev/null 2>&1 \
   && ! command -v xelatex >/dev/null 2>&1 \
   && ! command -v lualatex >/dev/null 2>&1; then
  echo "no LaTeX compiler found on PATH (need latexmk, pdflatex, xelatex, or lualatex)" >&2
  exit 1
fi

# Record active runtime port in gitignored .scholia/.port so scholia-ctl.py finds it automatically.
mkdir -p "$DIR/.scholia"
printf '%s\n' "$PORT" > "$DIR/.scholia/.port"

cd "$DIR"
CMD=("${SCHOLIA_CMD[@]}" --port "$PORT" serve)
if [ -n "$MAIN" ]; then
  CMD+=(--main "$MAIN")
fi
exec "${CMD[@]}"
