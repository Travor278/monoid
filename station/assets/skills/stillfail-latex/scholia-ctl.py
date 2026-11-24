#!/usr/bin/env python3
"""Zero-dependency HTTP/Git helper for Scholia (queelius/scholia) on 127.0.0.1.

Lets any still.fail agent runtime (Claude Code, Codex, Antigravity CLI, Cursor, Pi)
inspect SyncTeX-anchored comments, render PDF regions, compile, reply/resolve, and
configure conflict-free Git-synced review (.scholia/comments.json) without restarting.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

GITIGNORE_HEADER = "# stillfail-latex / scholia (keep .scholia/comments.json tracked in Git)"
GITIGNORE_RULES = [
    "*.aux",
    "*.bbl",
    "*.blg",
    "*.fdb_latexmk",
    "*.fls",
    "*.log",
    "*.nav",
    "*.out",
    "*.snm",
    "*.synctex.gz",
    "*.toc",
    "*.vrb",
    ".mcp.json",
    ".scholia/.port",
    ".scholia/*.lock",
    ".scholia/.*.lock",
    ".scholia/.*.tmp",
    "!.scholia/",
    "!.scholia/comments.json",
    "!.scholia.yaml",
]
GITATTRIBUTES_LINE = ".scholia/comments.json merge=scholia-comments"


def discover_port(directory: pathlib.Path, explicit: int | None) -> int:
    if explicit is not None:
        return explicit
    for env_key in ("SCHOLIA_PORT", "PORT"):
        raw = os.environ.get(env_key, "").strip()
        if raw.isdigit():
            val = int(raw)
            if 1 <= val <= 65535:
                return val
    port_file = directory / ".scholia" / ".port"
    if port_file.is_file():
        raw = port_file.read_text("utf-8", errors="ignore").strip()
        if raw.isdigit():
            val = int(raw)
            if 1 <= val <= 65535:
                return val
    cfg = directory / ".scholia.yaml"
    if cfg.is_file():
        for line in cfg.read_text("utf-8", errors="ignore").splitlines():
            m = re.match(r"^\s*port\s*:\s*(\d+)\s*(?:#.*)?$", line)
            if m:
                val = int(m.group(1))
                if 1 <= val <= 65535:
                    return val
    return 8765


def request_raw(
    port: int,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    timeout: float = 120.0,
) -> tuple[int, bytes, str]:
    url = f"http://127.0.0.1:{port}{path}"
    data = None
    headers = {"Accept": "application/json, image/png, */*"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    # Never route loopback 127.0.0.1 traffic through HTTP_PROXY/ALL_PROXY.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=timeout) as resp:
            ctype = resp.headers.get("Content-Type", "")
            return resp.status, resp.read(), ctype
    except urllib.error.HTTPError as exc:
        body = exc.read()
        detail = body.decode("utf-8", errors="replace").strip()
        raise SystemExit(f"HTTP {exc.code} {method} {path}: {detail}") from None
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"Cannot reach Scholia on http://127.0.0.1:{port} ({exc.reason}). "
            "Start it with latex-preview.sh, pass --port, or use --offline for local .scholia/comments.json."
        ) from None


def request_json(port: int, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
    _, body, _ = request_raw(port, method, path, payload)
    if not body:
        return {}
    return json.loads(body.decode("utf-8"))


def read_local_comments(directory: pathlib.Path, status: str = "all") -> list[dict[str, Any]]:
    path = directory / ".scholia" / "comments.json"
    if not path.is_file():
        return []
    raw = json.loads(path.read_text("utf-8"))
    comments = raw.get("comments", []) if isinstance(raw, dict) else (raw if isinstance(raw, list) else [])
    if status != "all":
        comments = [c for c in comments if isinstance(c, dict) and c.get("status") == status]
    return [c for c in comments if isinstance(c, dict)]


def format_comment_location(c: dict[str, Any]) -> str:
    parts: list[str] = []
    rs = c.get("resolved_source")
    if isinstance(rs, dict) and rs.get("file"):
        ls = rs.get("line_start")
        le = rs.get("line_end")
        if ls is not None and le is not None and le != ls:
            parts.append(f"{rs['file']}:{ls}-{le}")
        elif ls is not None:
            parts.append(f"{rs['file']}:{ls}")
        else:
            parts.append(str(rs["file"]))
    anchor = c.get("anchor")
    if isinstance(anchor, dict):
        kind = anchor.get("kind")
        if kind == "pdf_region" and anchor.get("page") is not None:
            parts.append(f"p.{anchor['page']}")
        elif kind == "section" and anchor.get("title"):
            parts.append(f"section:{anchor['title']}")
        elif kind == "paper":
            parts.append("paper")
    return " ".join(parts) if parts else "unknown"


def print_comments_text(comments: list[dict[str, Any]]) -> None:
    if not comments:
        print("No matching comments.")
        return
    for c in comments:
        cid = c.get("id", "?")
        status = c.get("status", "open")
        stale = " [STALE]" if c.get("stale") else ""
        loc = format_comment_location(c)
        print(f"[{cid}] ({status}{stale}) {loc}")
        snippet = c.get("snippet")
        if isinstance(snippet, str) and snippet.strip():
            first = snippet.strip().splitlines()[0][:120]
            print(f"  snippet: {first}")
        suggestion = c.get("suggestion")
        if isinstance(suggestion, dict) and (suggestion.get("old") or suggestion.get("new")):
            print(f"  suggest: {suggestion.get('old', '')!r} -> {suggestion.get('new', '')!r}")
        for entry in c.get("thread") or []:
            author = entry.get("author", "?")
            text = (entry.get("text") or "").strip().replace("\n", "\n    ")
            print(f"  - {author}: {text}")


def print_comment_detail(directory: pathlib.Path, c: dict[str, Any], context: int) -> None:
    print_comments_text([c])
    rs = c.get("resolved_source")
    if not isinstance(rs, dict) or not rs.get("file") or rs.get("line_start") is None:
        return
    src = (directory / str(rs["file"])).resolve()
    try:
        src.relative_to(directory.resolve())
    except ValueError:
        return
    if not src.is_file():
        return
    lines = src.read_text("utf-8", errors="replace").splitlines()
    start = max(1, int(rs["line_start"]) - max(0, context))
    end = min(len(lines), int(rs.get("line_end") or rs["line_start"]) + max(0, context))
    ls = int(rs["line_start"])
    le = int(rs.get("line_end") or ls)
    print(f"  source ({rs['file']}):")
    for lineno in range(start, end + 1):
        marker = ">" if ls <= lineno <= le else " "
        print(f"  {marker} {lineno:4d} | {lines[lineno - 1]}")


def _load_store(path: pathlib.Path) -> tuple[int, list[dict[str, Any]]]:
    if not path.is_file():
        return 1, []
    text = path.read_text("utf-8").strip()
    if not text:
        return 1, []
    raw = json.loads(text)
    if isinstance(raw, dict):
        ver = raw.get("version", 1)
        items = raw.get("comments", [])
        return (ver if isinstance(ver, int) else 1), [c for c in items if isinstance(c, dict)]
    if isinstance(raw, list):
        return 1, [c for c in raw if isinstance(c, dict)]
    return 1, []


def _merge_threads(a: list[dict[str, Any]], b: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()
    for entry in list(a) + list(b):
        if not isinstance(entry, dict):
            continue
        key = (str(entry.get("author", "")), str(entry.get("at", "")), str(entry.get("text", "")))
        if key in seen:
            continue
        seen.add(key)
        merged.append(entry)
    merged.sort(key=lambda e: str(e.get("at", "")))
    return merged


def _merge_one_comment(
    base: dict[str, Any] | None,
    ours: dict[str, Any],
    theirs: dict[str, Any],
) -> dict[str, Any]:
    if ours == theirs:
        return ours
    if base is not None:
        if ours == base:
            return theirs
        if theirs == base:
            return ours
    ours_ts = str(ours.get("updated") or ours.get("created") or "")
    theirs_ts = str(theirs.get("updated") or theirs.get("created") or "")
    newer, older = (theirs, ours) if theirs_ts > ours_ts else (ours, theirs)
    out = dict(older)
    out.update(newer)
    out["thread"] = _merge_threads(ours.get("thread") or [], theirs.get("thread") or [])
    if not out.get("suggestion") and older.get("suggestion"):
        out["suggestion"] = older["suggestion"]
    if not out.get("snippet") and older.get("snippet"):
        out["snippet"] = older["snippet"]
    if not out.get("resolved_source") and older.get("resolved_source"):
        out["resolved_source"] = older["resolved_source"]
    return out


def merge_comment_files(
    base_path: pathlib.Path,
    ours_path: pathlib.Path,
    theirs_path: pathlib.Path,
    out_path: pathlib.Path | None = None,
) -> dict[str, Any]:
    v_base, base_list = _load_store(base_path)
    v_ours, ours_list = _load_store(ours_path)
    v_theirs, theirs_list = _load_store(theirs_path)

    base_map = {str(c["id"]): c for c in base_list if "id" in c}
    ours_map = {str(c["id"]): c for c in ours_list if "id" in c}
    theirs_map = {str(c["id"]): c for c in theirs_list if "id" in c}

    order: list[str] = []
    for lst in (ours_list, theirs_list):
        for c in lst:
            cid = c.get("id")
            if cid is not None and str(cid) not in order:
                order.append(str(cid))

    merged_comments: list[dict[str, Any]] = []
    for cid in order:
        in_base = base_map.get(cid)
        in_ours = ours_map.get(cid)
        in_theirs = theirs_map.get(cid)
        if in_ours is not None and in_theirs is not None:
            merged_comments.append(_merge_one_comment(in_base, in_ours, in_theirs))
        elif in_ours is not None:
            # Deleted in theirs? Honor deletion only if ours did not modify it since base.
            if in_base is None or in_ours != in_base:
                merged_comments.append(in_ours)
        elif in_theirs is not None:
            # Deleted in ours? Honor deletion only if theirs did not modify it since base.
            if in_base is None or in_theirs != in_base:
                merged_comments.append(in_theirs)

    result = {"version": max(v_base, v_ours, v_theirs), "comments": merged_comments}
    target = out_path or ours_path
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return result


def cmd_git_setup(directory: pathlib.Path, install_driver: bool = True) -> int:
    gitignore = directory / ".gitignore"
    existing = gitignore.read_text("utf-8") if gitignore.exists() else ""
    existing_lines = set(line.strip() for line in existing.splitlines())
    missing = [rule for rule in GITIGNORE_RULES if rule not in existing_lines]
    gitignore_changed = False
    if missing:
        prefix = ""
        if existing and not existing.endswith("\n"):
            prefix = "\n"
        if existing.strip():
            prefix += "\n"
        block_lines = ([GITIGNORE_HEADER] if GITIGNORE_HEADER not in existing_lines else []) + missing
        updated = existing + prefix + "\n".join(block_lines) + "\n"
        gitignore.write_text(updated, encoding="utf-8")
        gitignore_changed = True

    gitattributes = directory / ".gitattributes"
    attr_existing = gitattributes.read_text("utf-8") if gitattributes.exists() else ""
    attr_lines = set(line.strip() for line in attr_existing.splitlines())
    attr_changed = False
    if GITATTRIBUTES_LINE not in attr_lines:
        prefix = "\n" if attr_existing and not attr_existing.endswith("\n") else ""
        gitattributes.write_text(attr_existing + prefix + GITATTRIBUTES_LINE + "\n", encoding="utf-8")
        attr_changed = True

    driver_configured = False
    if install_driver:
        probe = subprocess.run(
            ["git", "-C", str(directory), "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            check=False,
        )
        if probe.returncode == 0:
            script_path = str(pathlib.Path(__file__).resolve())
            driver_cmd = f"python3 {shlex.quote(script_path)} merge-comments %O %A %B"
            subprocess.run(
                ["git", "-C", str(directory), "config", "merge.scholia-comments.name", "Semantic 3-way merge for Scholia comments.json"],
                check=False,
            )
            res = subprocess.run(
                ["git", "-C", str(directory), "config", "merge.scholia-comments.driver", driver_cmd],
                check=False,
            )
            driver_configured = res.returncode == 0

    print(
        json.dumps(
            {
                "path": str(gitignore),
                "changed": gitignore_changed or attr_changed,
                "added": missing,
                "gitattributes_changed": attr_changed,
                "merge_driver_configured": driver_configured,
            }
        )
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--dir", default=".", help="Paper directory (for .scholia.yaml / .gitignore)")
    common.add_argument("--port", type=int, default=None, help="Scholia HTTP port on 127.0.0.1")

    parser = argparse.ArgumentParser(description="Scholia HTTP and Git-sync helper for still.fail")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("paper", parents=[common], help="Get paper sections, compile status, and comment summary")

    p_comments = sub.add_parser("comments", parents=[common], help="List review comments")
    p_comments.add_argument("--status", default="open", choices=["open", "resolved", "dismissed", "all"])
    p_comments.add_argument("--format", default="json", choices=["json", "text"])
    p_comments.add_argument("--offline", action="store_true", help="Read .scholia/comments.json directly without a running daemon")

    p_show = sub.add_parser("show", parents=[common], help="Show one comment with numbered source context lines")
    p_show.add_argument("id", help="Comment ID (e.g. c-1234abcd)")
    p_show.add_argument("--context", type=int, default=3, help="Source context lines around the anchored range")
    p_show.add_argument("--offline", action="store_true", help="Read .scholia/comments.json directly without a running daemon")

    p_add = sub.add_parser("add", parents=[common], help="Add a review comment")
    p_add.add_argument("--text", required=True, help="Comment body")
    p_add.add_argument("--author", default="claude", help="Author label (default: claude)")
    p_add.add_argument("--file", default=None, help="Source file for source_range anchor")
    p_add.add_argument("--line-start", type=int, default=None, help="Start line (1-based)")
    p_add.add_argument("--line-end", type=int, default=None, help="End line (1-based, defaults to --line-start)")
    p_add.add_argument("--section", default=None, help="Section title for section anchor")
    p_add.add_argument("--paper", action="store_true", help="Paper-level anchor")
    p_add.add_argument("--old", default=None, help="Original text for optional rewrite suggestion")
    p_add.add_argument("--new", default=None, help="Replacement text for optional rewrite suggestion")

    p_reply = sub.add_parser("reply", parents=[common], help="Reply to an existing comment")
    p_reply.add_argument("id", help="Comment ID (e.g. c-1234abcd)")
    p_reply.add_argument("text", help="Reply text")
    p_reply.add_argument("--author", default="claude")
    p_reply.add_argument("--edit", action="append", default=[], help="Edited location (repeatable, e.g. main.tex:42)")

    p_resolve = sub.add_parser("resolve", parents=[common], help="Resolve a comment")
    p_resolve.add_argument("id", help="Comment ID")
    p_resolve.add_argument("summary", help="Resolution summary")
    p_resolve.add_argument("--author", default="claude")
    p_resolve.add_argument("--edit", action="append", default=[], help="Edited location (repeatable)")

    p_dismiss = sub.add_parser("dismiss", parents=[common], help="Dismiss a comment")
    p_dismiss.add_argument("id", help="Comment ID")
    p_dismiss.add_argument("reason", help="Dismissal reason")
    p_dismiss.add_argument("--author", default="claude")

    sub.add_parser("compile", parents=[common], help="Trigger compilation and return structured errors")

    p_image = sub.add_parser("image", parents=[common], help="Render a PDF page, source range, or comment region as PNG")
    group = p_image.add_mutually_exclusive_group(required=True)
    group.add_argument("--comment-id", help="Render the anchored region of this comment")
    group.add_argument("--page", type=int, help="1-based PDF page number")
    group.add_argument("--source", help="Source range (e.g. sections/method.tex:40-65)")
    p_image.add_argument("--bbox", default=None, help="Optional x1,y1,x2,y2 PDF point box with --page")
    p_image.add_argument("--dpi", type=int, default=150, help="Render DPI (default 150)")
    p_image.add_argument("--out", required=True, help="Output PNG file path")

    p_goto = sub.add_parser("goto", parents=[common], help="Scroll the live PDF viewer")
    g_target = p_goto.add_mutually_exclusive_group(required=True)
    g_target.add_argument("--line", type=int, help="Source line number (pair with --file)")
    g_target.add_argument("--page", type=int, help="PDF page number")
    g_target.add_argument("--section", help="Section title")
    g_target.add_argument("--label", help="LaTeX \\label{...} target")
    p_goto.add_argument("--file", default=None, help="Source file for --line (defaults to main in .scholia.yaml)")

    p_git = sub.add_parser("git-setup", parents=[common], help="Configure .gitignore, .gitattributes, and conflict-free Git merge driver")
    p_git.add_argument("--no-driver", action="store_true", help="Skip registering the local git merge driver")

    p_merge = sub.add_parser("merge-comments", help="Semantic 3-way merge driver for .scholia/comments.json (%O %A %B)")
    p_merge.add_argument("base", help="Base version path (%O)")
    p_merge.add_argument("ours", help="Current version path (%A, overwritten unless --out is given)")
    p_merge.add_argument("theirs", help="Incoming version path (%B)")
    p_merge.add_argument("--out", default=None, help="Optional output path")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.cmd == "merge-comments":
        merge_comment_files(
            pathlib.Path(args.base),
            pathlib.Path(args.ours),
            pathlib.Path(args.theirs),
            pathlib.Path(args.out) if args.out else None,
        )
        return 0

    directory = pathlib.Path(args.dir).resolve()

    if args.cmd == "git-setup":
        return cmd_git_setup(directory, install_driver=not args.no_driver)

    if args.cmd == "comments" and args.offline:
        comments = read_local_comments(directory, status=args.status)
        if args.format == "text":
            print_comments_text(comments)
        else:
            print(json.dumps({"comments": comments}, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "show":
        if args.offline:
            found = next((c for c in read_local_comments(directory, "all") if c.get("id") == args.id), None)
            if found is None:
                raise SystemExit(f"Comment {args.id} not found in {directory / '.scholia' / 'comments.json'}")
        else:
            port = discover_port(directory, args.port)
            found = request_json(port, "GET", f"/comments/{urllib.parse.quote(args.id, safe='')}")
        print_comment_detail(directory, found, args.context)
        return 0

    port = discover_port(directory, args.port)

    if args.cmd == "paper":
        data = request_json(port, "GET", "/paper")
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "comments":
        query = "" if args.status == "all" else f"?{urllib.parse.urlencode({'status': args.status})}"
        data = request_json(port, "GET", f"/comments{query}")
        if args.format == "text":
            print_comments_text(data.get("comments", []))
        else:
            print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "add":
        if args.file and args.line_start is not None:
            anchor: dict[str, Any] = {
                "kind": "source_range",
                "file": args.file,
                "line_start": args.line_start,
                "line_end": args.line_end if args.line_end is not None else args.line_start,
            }
        elif args.section:
            anchor = {"kind": "section", "title": args.section}
        elif args.paper:
            anchor = {"kind": "paper"}
        else:
            raise SystemExit("Specify an anchor: (--file and --line-start), --section, or --paper.")
        payload: dict[str, Any] = {"anchor": anchor, "text": args.text, "author": args.author}
        if args.old is not None or args.new is not None:
            payload["suggestion"] = {"old": args.old or "", "new": args.new or ""}
        data = request_json(port, "POST", "/comments", payload)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "reply":
        payload = {"text": args.text, "author": args.author, "edits": args.edit}
        data = request_json(port, "POST", f"/comments/{urllib.parse.quote(args.id, safe='')}/reply", payload)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "resolve":
        payload = {"summary": args.summary, "author": args.author, "edits": args.edit}
        data = request_json(port, "POST", f"/comments/{urllib.parse.quote(args.id, safe='')}/resolve", payload)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "dismiss":
        payload = {"reason": args.reason, "author": args.author}
        data = request_json(port, "POST", f"/comments/{urllib.parse.quote(args.id, safe='')}/dismiss", payload)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "compile":
        data = request_json(port, "POST", "/compile", {})
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    if args.cmd == "image":
        params: dict[str, Any] = {"dpi": args.dpi}
        if args.comment_id:
            params["comment"] = args.comment_id
        elif args.page is not None:
            params["page"] = args.page
            if args.bbox:
                params["bbox"] = args.bbox
        elif args.source:
            params["source"] = args.source
        _, body, _ = request_raw(port, "GET", f"/image?{urllib.parse.urlencode(params)}")
        out = pathlib.Path(args.out).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(body)
        print(json.dumps({"path": str(out), "bytes": len(body)}))
        return 0

    if args.cmd == "goto":
        if args.line is not None:
            src_file = args.file
            if not src_file:
                cfg = directory / ".scholia.yaml"
                if cfg.is_file():
                    for line in cfg.read_text("utf-8", errors="ignore").splitlines():
                        m = re.match(r"^\s*main\s*:\s*([^\s#]+)", line)
                        if m:
                            src_file = m.group(1).strip("\"'")
                            break
            if not src_file:
                raise SystemExit("--line requires --file (or main: in .scholia.yaml)")
            payload = {"line": args.line, "file": src_file}
        elif args.page is not None:
            payload = {"page": args.page}
        elif args.label:
            payload = {"label": args.label}
        else:
            payload = {"section": args.section}
        data = request_json(port, "POST", "/goto", payload)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 0

    raise SystemExit(f"unknown command: {args.cmd}")


if __name__ == "__main__":
    raise SystemExit(main())
