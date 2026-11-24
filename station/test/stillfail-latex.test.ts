// Tests for the built-in stillfail-latex skill (Scholia preview + SyncTeX comments + Git sync).
// Covers skill/script materialization, scholia-ctl.py against a local 127.0.0.1 HTTP server,
// idempotent .gitignore configuration, and latex-preview.sh initialization + package validation.
import assert from "node:assert/strict";
import { execFile, execFileSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { promisify } from "node:util";
import { writeBuiltinSkills } from "../src/sessions/agent-home.ts";

const execFileAsync = promisify(execFile);

const dirs: string[] = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});
const fresh = (prefix = "stillfail-latex-") => {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  dirs.push(dir);
  return dir;
};

const SKILL_DIR = new URL("../assets/skills/stillfail-latex/", import.meta.url).pathname;
const CTL = join(SKILL_DIR, "scholia-ctl.py");
const PREVIEW = join(SKILL_DIR, "latex-preview.sh");

const hasPython = (() => {
  try {
    execFileSync("python3", ["--version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
})();

test("writeBuiltinSkills materializes stillfail-latex SKILL.md and runnable helper scripts", async () => {
  const root = fresh("latex-home-");
  const home = join(root, "agent");
  await writeBuiltinSkills(home, false);

  const skillMd = join(home, "skills", "stillfail-latex", "SKILL.md");
  const preview = join(home, "skills", "stillfail-latex", "latex-preview.sh");
  const ctl = join(home, "skills", "stillfail-latex", "scholia-ctl.py");

  assert.equal(
    readFileSync(skillMd, "utf8"),
    readFileSync(new URL("../assets/skills/stillfail-latex.md", import.meta.url), "utf8"),
  );
  assert.equal(readFileSync(preview, "utf8"), readFileSync(PREVIEW, "utf8"));
  assert.equal(readFileSync(ctl, "utf8"), readFileSync(CTL, "utf8"));
  if (process.platform !== "win32") {
    assert.ok(statSync(preview).mode & 0o100, "latex-preview.sh is runnable");
    assert.ok(statSync(ctl).mode & 0o100, "scholia-ctl.py is runnable");
  }

  writeFileSync(ctl, "tampered");
  await writeBuiltinSkills(home, false);
  assert.equal(readFileSync(ctl, "utf8"), readFileSync(CTL, "utf8"), "station restores its canonical script");
});

test("scholia-ctl.py git-setup configures .gitignore idempotently while tracking .scholia/comments.json", { skip: !hasPython && "python3 not installed" }, () => {
  const dir = fresh("latex-git-");
  writeFileSync(join(dir, ".gitignore"), "node_modules/\n");

  const first = JSON.parse(execFileSync("python3", [CTL, "git-setup", "--dir", dir], { encoding: "utf8" }));
  assert.equal(first.changed, true);
  assert.ok(first.added.includes("*.synctex.gz"));
  assert.ok(first.added.includes(".mcp.json"));
  assert.ok(first.added.includes("!.scholia/comments.json"));

  const content = readFileSync(join(dir, ".gitignore"), "utf8");
  assert.ok(content.startsWith("node_modules/\n"), "preserves existing entries");
  assert.ok(content.includes("!.scholia/comments.json\n"));

  const second = JSON.parse(execFileSync("python3", [CTL, "git-setup", "--dir", dir], { encoding: "utf8" }));
  assert.equal(second.changed, false);
  assert.deepEqual(second.added, []);
  assert.equal(readFileSync(join(dir, ".gitignore"), "utf8"), content, "idempotent on second run");
});

test("scholia-ctl.py talks to a local 127.0.0.1 Scholia server for paper, comments, image, compile, and goto", { skip: !hasPython && "python3 not installed" }, async () => {
  const seen: { method: string; url: string; body: any }[] = [];
  const fakePng = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const sampleComment = {
    id: "c-deadbeef",
    status: "open",
    stale: false,
    anchor: { kind: "pdf_region", page: 2, bbox: [10, 20, 300, 40] },
    resolved_source: { file: "sections/method.tex", line_start: 42, line_end: 45 },
    snippet: "\\section{Method}\nWe optimize $L(\\theta)$.",
    suggestion: { old: "We optimize", new: "We minimize" },
    thread: [{ author: "human", at: "2026-11-24T00:00:00Z", text: "Clarify objective." }],
  };

  const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    const chunks: Buffer[] = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      const body = raw ? JSON.parse(raw) : null;
      seen.push({ method: req.method ?? "", url: req.url ?? "", body });
      if (req.url === "/paper") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ main: "main.tex", sections: [{ title: "Method", line: 42 }], comments: { open: 1 } }));
      } else if (req.url?.startsWith("/comments?status=open")) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ comments: [sampleComment] }));
      } else if (req.url === "/comments" && req.method === "POST") {
        res.writeHead(201, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ id: "c-new12345", ...body }));
      } else if (req.url === "/comments/c-deadbeef/resolve" && req.method === "POST") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ...sampleComment, status: "resolved", resolution: body }));
      } else if (req.url === "/compile" && req.method === "POST") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ success: true, errors: [], warnings: [] }));
      } else if (req.url?.startsWith("/image?")) {
        res.writeHead(200, { "Content-Type": "image/png" });
        res.end(fakePng);
      } else if (req.url === "/goto" && req.method === "POST") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, target: body }));
      } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: "not found" }));
      }
    });
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", () => resolve()));
  const { port } = server.address() as { port: number };
  try {
    const dir = fresh("latex-ctl-");
    // Port discovery from .scholia.yaml
    writeFileSync(join(dir, ".scholia.yaml"), `main: main.tex\nport: ${port}\n`);
    const runCtl = async (...args: string[]) => (await execFileAsync("python3", [CTL, ...args], { encoding: "utf8" })).stdout;

    const paper = JSON.parse(await runCtl("paper", "--dir", dir));
    assert.equal(paper.main, "main.tex");

    const textOut = await runCtl("comments", "--dir", dir, "--status", "open", "--format", "text");
    assert.ok(textOut.includes("[c-deadbeef] (open) sections/method.tex:42-45 p.2"));
    assert.ok(textOut.includes("We optimize"));
    assert.ok(textOut.includes("We minimize"));
    assert.ok(textOut.includes("Clarify objective."));

    const added = JSON.parse(
      await runCtl("add", "--dir", dir, "--file", "main.tex", "--line-start", "10", "--line-end", "12", "--text", "Check citation", "--old", "a", "--new", "b"),
    );
    assert.equal(added.anchor.kind, "source_range");
    assert.equal(added.anchor.line_start, 10);
    assert.equal(added.anchor.line_end, 12);
    assert.deepEqual(added.suggestion, { old: "a", new: "b" });

    const resolved = JSON.parse(
      await runCtl("resolve", "--dir", dir, "c-deadbeef", "Clarified objective", "--edit", "sections/method.tex:42"),
    );
    assert.equal(resolved.status, "resolved");
    assert.deepEqual(resolved.resolution.edits, ["sections/method.tex:42"]);

    const compiled = JSON.parse(await runCtl("compile", "--dir", dir));
    assert.equal(compiled.success, true);

    const pngOut = join(dir, "crop.png");
    const img = JSON.parse(await runCtl("image", "--dir", dir, "--comment-id", "c-deadbeef", "--out", pngOut));
    assert.equal(img.bytes, fakePng.length);
    assert.deepEqual(readFileSync(pngOut), fakePng);

    const went = JSON.parse(await runCtl("goto", "--dir", dir, "--section", "Method"));
    assert.equal(went.ok, true);
    assert.deepEqual(went.target, { section: "Method" });

    assert.ok(seen.some((r) => r.method === "GET" && r.url === "/image?dpi=150&comment=c-deadbeef"));
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("latex-preview.sh --init-only detects main tex, preserves .mcp.json servers, and rejects unrelated scholia binaries", { skip: (process.platform === "win32" || !hasPython) && "requires bash and python3" }, () => {
  const dir = fresh("latex-init-");
  writeFileSync(join(dir, "intro.tex"), "\\section{Intro}\nHello.\n");
  writeFileSync(join(dir, "paper.tex"), "\\documentclass{article}\n\\begin{document}\n\\input{intro}\n\\end{document}\n");
  writeFileSync(join(dir, ".mcp.json"), JSON.stringify({ mcpServers: { existing: { command: "echo", args: ["ok"] } } }));

  const fakeGood = join(dir, "fake-scholia");
  writeFileSync(fakeGood, "#!/usr/bin/env bash\necho 'usage: scholia {serve,init,compile,goto,mcp}'\n");
  chmodSync(fakeGood, 0o755);

  execFileSync("bash", [PREVIEW, "--dir", dir, "--port", "9123", "--init-only"], {
    env: { ...process.env, SCHOLIA_BIN: fakeGood },
    encoding: "utf8",
  });

  const yaml = readFileSync(join(dir, ".scholia.yaml"), "utf8");
  assert.ok(yaml.includes("main: paper.tex"), "prefers the file with \\documentclass");
  assert.ok(yaml.includes("port: 9123"));

  const mcp = JSON.parse(readFileSync(join(dir, ".mcp.json"), "utf8"));
  assert.deepEqual(mcp.mcpServers.existing, { command: "echo", args: ["ok"] }, "preserves existing MCP entries");
  assert.equal(mcp.mcpServers.scholia.command, fakeGood);
  assert.deepEqual(mcp.mcpServers.scholia.args, ["mcp"]);
  assert.ok(existsSync(join(dir, ".gitignore")));

  const fakeWrongPypi = join(dir, "wrong-scholia");
  writeFileSync(fakeWrongPypi, "#!/usr/bin/env bash\necho 'scholia 0.3.1 marking aid'\n");
  chmodSync(fakeWrongPypi, 0o755);
  assert.throws(
    () =>
      execFileSync("bash", [PREVIEW, "--dir", dir, "--init-only"], {
        env: { ...process.env, SCHOLIA_BIN: fakeWrongPypi },
        stdio: "pipe",
      }),
    /not a valid queelius\/scholia/,
  );
});

test("scholia-ctl.py supports --offline comment reading, numbered source context in show, and .scholia/.port discovery", { skip: !hasPython && "python3 not installed" }, async () => {
  const dir = fresh("latex-offline-");
  mkdirSync(join(dir, ".scholia"), { recursive: true });
  writeFileSync(
    join(dir, "main.tex"),
    "\\documentclass{article}\n\\begin{document}\nLine 3\nWe optimize $L$.\nLine 5\n\\end{document}\n",
  );
  writeFileSync(
    join(dir, ".scholia", "comments.json"),
    JSON.stringify({
      version: 1,
      comments: [
        {
          id: "c-off1",
          status: "open",
          stale: false,
          anchor: { kind: "source_range", file: "main.tex", line_start: 4, line_end: 4 },
          resolved_source: { file: "main.tex", line_start: 4, line_end: 4 },
          snippet: "We optimize $L$.",
          thread: [{ author: "human", at: "2026-11-24T01:00:00Z", text: "Tighten notation" }],
        },
      ],
    }),
  );

  const listOut = execFileSync("python3", [CTL, "comments", "--dir", dir, "--offline", "--status", "open", "--format", "text"], { encoding: "utf8" });
  assert.ok(listOut.includes("[c-off1] (open) main.tex:4"));
  assert.ok(listOut.includes("Tighten notation"));

  const showOut = execFileSync("python3", [CTL, "show", "--dir", dir, "c-off1", "--offline", "--context", "1"], { encoding: "utf8" });
  assert.ok(showOut.includes("source (main.tex):"));
  assert.ok(showOut.includes(">    4 | We optimize $L$."));
  assert.ok(showOut.includes("     3 | Line 3"));

  // .scholia/.port overrides .scholia.yaml port without mutating tracked config
  const server = createServer((_req, res) => {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ main: "from-runtime-port.tex" }));
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", () => resolve()));
  const { port } = server.address() as { port: number };
  try {
    writeFileSync(join(dir, ".scholia.yaml"), "main: main.tex\nport: 1\n");
    writeFileSync(join(dir, ".scholia", ".port"), `${port}\n`);
    const paper = JSON.parse((await execFileAsync("python3", [CTL, "paper", "--dir", dir], { encoding: "utf8" })).stdout);
    assert.equal(paper.main, "from-runtime-port.tex");
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("git-setup merge driver resolves concurrent .scholia/comments.json edits cleanly in a real git merge", { skip: !hasPython && "python3 not installed" }, () => {
  const dir = fresh("latex-merge-");
  const git = (...args: string[]) =>
    execFileSync("git", ["-C", dir, "-c", "user.name=Test", "-c", "user.email=test@example.com", ...args], { encoding: "utf8" });

  git("init", "-b", "main");
  mkdirSync(join(dir, ".scholia"), { recursive: true });
  const baseComments = {
    version: 1,
    comments: [
      {
        id: "c-shared",
        status: "open",
        created: "2026-11-24T01:00:00Z",
        updated: "2026-11-24T01:00:00Z",
        anchor: { kind: "paper" },
        thread: [{ author: "human", at: "2026-11-24T01:00:00Z", text: "Base note" }],
      },
      {
        id: "c-delete-me",
        status: "open",
        created: "2026-11-24T01:00:00Z",
        updated: "2026-11-24T01:00:00Z",
        anchor: { kind: "paper" },
        thread: [{ author: "human", at: "2026-11-24T01:00:00Z", text: "Obsolete" }],
      },
    ],
  };
  writeFileSync(join(dir, ".scholia", "comments.json"), JSON.stringify(baseComments, null, 2) + "\n");
  const setup = JSON.parse(execFileSync("python3", [CTL, "git-setup", "--dir", dir], { encoding: "utf8" }));
  assert.equal(setup.merge_driver_configured, true);
  git("add", ".gitignore", ".gitattributes", ".scholia/comments.json");
  git("commit", "-m", "base");

  // Branch A: replies to c-shared, deletes c-delete-me, adds c-from-a
  git("checkout", "-b", "branch-a");
  const aComments = {
    version: 1,
    comments: [
      {
        ...baseComments.comments[0],
        updated: "2026-11-24T02:00:00Z",
        thread: [
          ...baseComments.comments[0]!.thread,
          { author: "human", at: "2026-11-24T02:00:00Z", text: "Reply from A" },
        ],
      },
      {
        id: "c-from-a",
        status: "open",
        created: "2026-11-24T02:05:00Z",
        updated: "2026-11-24T02:05:00Z",
        anchor: { kind: "paper" },
        thread: [{ author: "human", at: "2026-11-24T02:05:00Z", text: "New in A" }],
      },
    ],
  };
  writeFileSync(join(dir, ".scholia", "comments.json"), JSON.stringify(aComments, null, 2) + "\n");
  git("commit", "-am", "edits on A");

  // Branch B (from main): resolves c-shared with newer timestamp, adds c-from-b
  git("checkout", "main");
  const bComments = {
    version: 1,
    comments: [
      {
        ...baseComments.comments[0],
        status: "resolved",
        updated: "2026-11-24T03:00:00Z",
        thread: [
          ...baseComments.comments[0]!.thread,
          { author: "claude", at: "2026-11-24T03:00:00Z", text: "Resolved in B" },
        ],
      },
      baseComments.comments[1],
      {
        id: "c-from-b",
        status: "open",
        created: "2026-11-24T03:05:00Z",
        updated: "2026-11-24T03:05:00Z",
        anchor: { kind: "paper" },
        thread: [{ author: "human", at: "2026-11-24T03:05:00Z", text: "New in B" }],
      },
    ],
  };
  writeFileSync(join(dir, ".scholia", "comments.json"), JSON.stringify(bComments, null, 2) + "\n");
  git("commit", "-am", "edits on B");

  // Merge branch-a into main: should succeed cleanly with zero conflicts
  git("merge", "--no-edit", "branch-a");
  const merged = JSON.parse(readFileSync(join(dir, ".scholia", "comments.json"), "utf8"));
  const byId = new Map(merged.comments.map((c: any) => [c.id, c]));

  assert.equal(byId.has("c-delete-me"), false, "clean deletion on A is honored");
  assert.equal(byId.has("c-from-a"), true, "comment added on A is preserved");
  assert.equal(byId.has("c-from-b"), true, "comment added on B is preserved");
  const shared: any = byId.get("c-shared");
  assert.equal(shared.status, "resolved", "newer status wins");
  assert.deepEqual(
    shared.thread.map((e: any) => e.text),
    ["Base note", "Reply from A", "Resolved in B"],
    "concurrent replies are merged chronologically",
  );
});
