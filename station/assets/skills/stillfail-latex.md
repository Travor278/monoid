---
name: stillfail-latex
description: Preview LaTeX papers with live PDF and SyncTeX line-anchored comments via Scholia (MCP and HTTP), served through a station web service and synced with collaborators over Git (.scholia/comments.json).
---

# LaTeX preview and comment review (Scholia)

Use [Scholia](https://github.com/queelius/scholia) to serve a live PDF preview with SyncTeX line-anchored comments,
figure/equation box annotations, and optional `{old, new}` rewrite suggestions, without relying on an external web
service. Comments live in `.scholia/comments.json` and sync with collaborators through Git.

The scripts sit beside this file: from your workspace, `.claude/skills/stillfail-latex/` or
`.agents/skills/stillfail-latex/`:

- `latex-preview.sh` — initializes `.scholia.yaml`, `.mcp.json`, and `.gitignore`, ensures the right `queelius/scholia`
  package is available, and serves the viewer on `127.0.0.1:$PORT`.
- `scholia-ctl.py` — zero-dependency Python 3 client for the running Scholia HTTP API (`127.0.0.1`), so every runtime
  (Claude Code, Codex, Antigravity CLI, Cursor, Pi) can read and resolve comments immediately in the current session.

Warning: **never run `pip install scholia`** — PyPI's `scholia` is an unrelated library. Install from GitHub instead:
`uv tool install "scholia[mcp,image] @ git+https://github.com/queelius/scholia.git"` (the `image` extra adds PyMuPDF
so you can visually inspect boxed figures and equations). `latex-preview.sh` falls back to `uvx` automatically when
`scholia` is not on `PATH`.

## Start the preview service

1. Start Scholia as a station web service (`job_start` with a `port`, skill `stillfail-jobs`):
   ```bash
   bash <this skill>/latex-preview.sh --dir <paper-dir> [--main main.tex]
   ```
   It binds `127.0.0.1:$PORT`, auto-detects the main `.tex` file (by `\documentclass`), writes `.scholia.yaml` and
   `.mcp.json` if missing, and configures `.gitignore` for Git-synced review.
2. Verify it answers with `curl -sf http://127.0.0.1:<port>/paper` and post the returned service link in the chat.
3. Tell reviewers they can:
   - **Select text in the PDF** to anchor a comment (SyncTeX maps it back to `file.tex:line_start-line_end`);
   - **Shift-click-drag** a rectangle around figures, tables, or equations;
   - Fill in the optional **Suggest a rewrite** (`{old, new}`) block for direct replacement;
   - Open the shared service link together in real time (all writes go to the same `.scholia/comments.json`, avoiding
     JSON merge conflicts).

## Review loop (MCP or `scholia-ctl.py`)

If the session loaded the `scholia` MCP server from `.mcp.json` (for example Claude Code started after initialization),
use its 7 MCP tools directly: `scholia_paper`, `scholia_compile`, `scholia_comment`, `scholia_image`,
`scholia_section`, `scholia_audit`, `scholia_goto`.

In an already-running session or runtimes that do not auto-load workspace `.mcp.json`, use `scholia-ctl.py`:

```bash
# Paper outline (sections with line ranges), compile status, and open comments
python3 <this skill>/scholia-ctl.py paper --dir <paper-dir>

# Open comment queue with exact file:line ranges, snippets, and {old, new} suggestions
# (add --offline to read .scholia/comments.json directly after a git pull without starting the daemon)
python3 <this skill>/scholia-ctl.py comments --dir <paper-dir> --status open --format text

# Inspect one comment together with numbered source lines from disk
python3 <this skill>/scholia-ctl.py show --dir <paper-dir> c-1234abcd --context 4

# Render a boxed comment region or source range to PNG for visual inspection (and chat_post files=[...])
python3 <this skill>/scholia-ctl.py image --dir <paper-dir> --comment-id c-1234abcd --out region.png
python3 <this skill>/scholia-ctl.py image --dir <paper-dir> --source sections/method.tex:40-65 --out method.png

# Apply edits to the .tex files, then recompile and verify structured errors
python3 <this skill>/scholia-ctl.py compile --dir <paper-dir>

# Reply, resolve, dismiss, or add agent-initiated review comments
python3 <this skill>/scholia-ctl.py resolve --dir <paper-dir> c-1234abcd "Clarified Eq. 3 notation" --edit sections/method.tex:42
python3 <this skill>/scholia-ctl.py reply --dir <paper-dir> c-1234abcd "Updated caption; check rendered crop."
python3 <this skill>/scholia-ctl.py add --dir <paper-dir> --file sections/method.tex --line-start 42 --line-end 48 --text "Symbol x_t conflicts with Section 2."

# Scroll the live viewer to a section, page, or line
python3 <this skill>/scholia-ctl.py goto --dir <paper-dir> --section "Method"
```

`latex-preview.sh` writes the active runtime port to the gitignored `.scholia/.port`, so `scholia-ctl.py` discovers it
automatically even when `job_start` assigns a port different from `.scholia.yaml` (override with `--port` or
`SCHOLIA_PORT`).

## Git sync with collaborators

Scholia stores comments in plain-text `.scholia/comments.json` and reads/writes it under a file lock on each operation.
When line numbers shift after another author edits earlier paragraphs, Scholia re-anchors open comments using their
captured source snippet (marking a comment `stale` only if the snippet itself was rewritten).

- **Track in Git**: `*.tex`, `*.bib`, figures, `.scholia.yaml`, `.scholia/comments.json`, `.gitattributes`.
- **Ignore in Git**: TeX build artifacts (`*.aux`, `*.log`, `*.fls`, `*.fdb_latexmk`, `*.synctex.gz`, `*.bbl`, `*.blg`,
  `*.out`), lock/runtime files (`.scholia/.port`, `.scholia/.*.lock`), and machine-local `.mcp.json`.
- **Conflict-free concurrent comments**: `python3 <this skill>/scholia-ctl.py git-setup --dir <paper-dir>` configures
  `.gitignore`, adds `.scholia/comments.json merge=scholia-comments` to `.gitattributes`, and installs a local Git
  3-way semantic merge driver (`scholia-ctl.py merge-comments %O %A %B`) that unions concurrent comments and thread
  replies by ID and timestamp instead of leaving JSON merge conflicts.
- **Sync routine**:
  1. Pull before editing or committing: `git pull --rebase`.
  2. Commit `.tex` changes alongside `.scholia/comments.json` after resolving a batch of comments, then `git push`.
  3. Collaborators `git pull` to get both the updated `.tex` source and the updated comment thread, and can view or add
     comments either through the shared station preview link or their own local `scholia` instance.
