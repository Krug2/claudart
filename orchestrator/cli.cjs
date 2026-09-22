#!/usr/bin/env node
const fs = require("node:fs/promises")
const path = require("node:path")
const os = require("node:os")
const { spawn, execFile, execFileSync } = require("node:child_process")
const { parseArgs } = require("node:util")
const { randomUUID } = require("node:crypto")
const {
  createWorkflow,
  resumeWorkflow,
  runWorkflow,
  workerPrompt,
  createJevDecider,
} = require("./index.cjs")

async function credential() {
  if (process.env.JEV_API_KEY?.trim()) return process.env.JEV_API_KEY.trim()
  if (process.platform !== "win32")
    throw new Error("Set JEV_API_KEY before starting")
  const file = path.join(os.homedir(), ".claudart", "jev-key.dpapi")
  await fs.access(file)
  try {
    return execFileSync(
      "powershell.exe",
      [
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Add-Type -AssemblyName System.Security; $p = Join-Path $env:USERPROFILE '.claudart/jev-key.dpapi'; $b = [IO.File]::ReadAllBytes($p); [Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect($b, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))",
      ],
      { windowsHide: true, stdio: ["ignore", "pipe", "ignore"], timeout: 10000 }
    )
      .toString()
      .trim()
  } catch {
    throw new Error(
      "Could not unlock the local Jev credential; set JEV_API_KEY"
    )
  }
}

async function execute(worker, request, cwd, signal) {
  const codex = worker.adapter === "codex"
  const outputDir = codex
    ? await fs.mkdtemp(path.join(os.tmpdir(), "claudart-"))
    : null
  const outputFile = outputDir ? path.join(outputDir, "handoff.json") : null
  try {
    return await new Promise((resolve, reject) => {
      const claude = worker.adapter === "claude"
      const args = claude
        ? [
            ...(worker.args ?? []),
            "--print",
            "--output-format",
            "json",
            "--model",
            worker.model ?? "sonnet",
            "--permission-mode",
            request.permission === "write" ? "acceptEdits" : "plan",
          ]
        : codex
          ? [
              "exec",
              ...(worker.args ?? []),
              ...(worker.model ? ["--model", worker.model] : []),
              "--ephemeral",
              "--sandbox",
              request.permission === "write" ? "workspace-write" : "read-only",
              "--color",
              "never",
              "--output-last-message",
              outputFile,
              "-",
            ]
          : (worker.args ?? [])
      const env = { ...process.env }
      delete env.JEV_API_KEY
      delete env.BETTERC0DE_SETTINGS_KEY
      const child = spawn(
        worker.command ?? (claude ? "claude" : codex ? "codex" : ""),
        args,
        {
          cwd,
          env,
          windowsHide: true,
          shell: false,
          detached: process.platform !== "win32",
          stdio: ["pipe", "pipe", "pipe"],
        }
      )
      let output = ""
      let failure = null
      const kill = () => {
        if (!child.pid || child.exitCode !== null) return
        if (process.platform === "win32")
          execFile(
            "taskkill.exe",
            ["/PID", String(child.pid), "/T", "/F"],
            { windowsHide: true },
            () => {}
          )
        else {
          try {
            process.kill(-child.pid, "SIGTERM")
          } catch {}
          setTimeout(() => {
            if (child.exitCode === null)
              try {
                process.kill(-child.pid, "SIGKILL")
              } catch {}
          }, 2000).unref()
        }
      }
      const abort = () => {
        failure = new Error("Worker interrupted")
        kill()
      }
      signal.addEventListener("abort", abort, { once: true })
      const timer = setTimeout(() => {
        failure = new Error("Worker timed out")
        kill()
      }, 15 * 60_000)
      child.stdout.setEncoding("utf8")
      child.stdout.on("data", (chunk) => {
        if (codex || failure) return
        output += chunk
        if (Buffer.byteLength(output) > 256_000) {
          failure = new Error("Worker response too large")
          kill()
        }
      })
      child.stderr.resume()
      child.stdin.on("error", () => {})
      child.on("error", () => {
        failure = new Error("Worker could not start")
      })
      child.on("close", async (code) => {
        clearTimeout(timer)
        signal.removeEventListener("abort", abort)
        if (failure || code !== 0)
          return reject(
            failure ?? new Error(`Worker exited with status ${code}`)
          )
        try {
          if (codex) {
            if ((await fs.stat(outputFile)).size > 64_000)
              throw new Error("Worker response too large")
            output = await fs.readFile(outputFile, "utf8")
          }
          const result = JSON.parse(output)
          if (claude && result.is_error)
            throw new Error("Worker rejected the task")
          resolve(claude ? result.result : result)
        } catch {
          reject(new Error("Worker did not return a valid JSON handoff"))
        }
      })
      child.stdin.end(
        claude || codex
          ? workerPrompt(request)
          : JSON.stringify({ version: 1, ...request }) + "\n"
      )
      if (signal.aborted) abort()
    })
  } finally {
    if (outputFile) {
      await fs.unlink(outputFile).catch(() => {})
      await fs.rmdir(outputDir).catch(() => {})
    }
  }
}

async function main() {
  const { values } = parseArgs({
    options: {
      goal: { type: "string" },
      workspace: { type: "string", default: process.cwd() },
      config: { type: "string" },
      checkpoint: { type: "string" },
      resume: { type: "boolean" },
      clarification: { type: "string" },
      worker: { type: "string", default: "claude" },
      model: { type: "string" },
      "allow-write": { type: "boolean", default: false },
      scope: { type: "string", multiple: true },
      constraint: { type: "string", multiple: true },
      help: { type: "boolean", short: "h" },
    },
  })
  if (values.help) {
    process.stdout.write(
      'claudart-orchestrate --goal <request> [--workspace <directory>] [--worker claude|codex] [--model <model>] [--allow-write] [--scope <relative path>] [--constraint <instruction>] [--config <workers.json>] [--checkpoint <path>] [--resume] [--clarification <text>]\n\nUses JEV_API_KEY or the Windows local credential. Default worker: Claude Sonnet. Codex uses your configured model unless --model is supplied.\nResume with --resume --checkpoint <path>; add --clarification <text> to resolve a blocker. The original goal, scope and limits remain in force. Repeat --allow-write to permit further changes.\nWorker config: {"workers":[{"id":"worker","adapter":"json","command":"executable","args":[],"description":"Capabilities","canWrite":false}]}\nJSON workers read one version 1 request from stdin and return one JSON handoff to stdout. Hosts must enforce the requested permission and scope.\n'
    )
    return
  }
  if (values.clarification !== undefined && !values.resume)
    throw new Error("Use --clarification with --resume --checkpoint")
  const workspace = await fs.realpath(values.workspace)
  if (!(await fs.stat(workspace)).isDirectory())
    throw new Error("Workspace must be a directory")
  const key = await credential()
  if (!["claude", "codex"].includes(values.worker))
    throw new Error("Worker must be claude or codex")
  const config = values.config
    ? JSON.parse(await fs.readFile(values.config, "utf8"))
    : {
        workers: [
          {
            id: values.worker,
            adapter: values.worker,
            model:
              values.model ??
              (values.worker === "claude" ? "sonnet" : undefined),
            description: `${values.worker}: repository investigation, implementation planning, coding and review`,
            canWrite: true,
          },
        ],
      }
  if (
    !Array.isArray(config.workers) ||
    !config.workers.length ||
    config.workers.length > 128 ||
    new Set(config.workers.map((worker) => worker?.id)).size !==
      config.workers.length ||
    config.workers.some(
      (worker) =>
        !worker ||
        typeof worker.id !== "string" ||
        !/^[\w-]{1,64}$/.test(worker.id) ||
        !["json", "claude", "codex"].includes(worker.adapter) ||
        typeof worker.description !== "string" ||
        !worker.description.trim() ||
        worker.description.length > 4000 ||
        typeof worker.canWrite !== "boolean" ||
        (worker.adapter === "json" && typeof worker.command !== "string") ||
        (worker.command !== undefined &&
          (typeof worker.command !== "string" || !worker.command.trim())) ||
        (worker.model !== undefined &&
          (typeof worker.model !== "string" || !worker.model.trim())) ||
        (worker.args !== undefined &&
          (!Array.isArray(worker.args) ||
            worker.args.some((arg) => typeof arg !== "string")))
    )
  )
    throw new Error("Invalid worker configuration")
  if (!values.resume && !values.goal)
    throw new Error("Provide --goal or --resume --checkpoint")
  if (
    values.resume &&
    (!values.checkpoint || values.goal || values.scope || values.constraint)
  )
    throw new Error(
      "Resume requires --checkpoint and preserves its goal, scope and constraints"
    )
  let state = values.resume
    ? null
    : createWorkflow({
        goal: values.goal,
        scope: values.scope,
        constraints: values.constraint,
        allowWrite: values["allow-write"],
      })
  const checkpoint = path.resolve(
    values.checkpoint ??
      path.join(os.homedir(), ".claudart", "runs", state.id + ".json")
  )
  await fs.mkdir(path.dirname(checkpoint), { recursive: true, mode: 0o700 })
  const lockPath = checkpoint + ".lock"
  let lock
  try {
    lock = await fs.open(lockPath, "wx", 0o600)
  } catch (error) {
    if (error.code !== "EEXIST" || !values.resume) throw error
    const owner = JSON.parse(await fs.readFile(lockPath, "utf8"))
    if (!Number.isSafeInteger(owner.pid) || owner.pid < 1)
      throw new Error("Invalid checkpoint lock; inspect it before removal")
    try {
      process.kill(owner.pid, 0)
      throw new Error("This workflow is already running")
    } catch (failure) {
      if (failure.code !== "ESRCH") throw failure
    }
    await fs.unlink(lockPath)
    lock = await fs.open(lockPath, "wx", 0o600)
  }
  await lock.writeFile(JSON.stringify({ pid: process.pid }))
  const controller = new AbortController()
  const stop = () => controller.abort()
  process.on("SIGINT", stop)
  process.on("SIGTERM", stop)
  try {
    if (values.resume) {
      const saved = JSON.parse(await fs.readFile(checkpoint, "utf8"))
      if (saved.workspace !== workspace)
        throw new Error("Checkpoint belongs to a different workspace")
      state = resumeWorkflow(saved.workflow, {
        clarification: values.clarification,
      })
    }
    if (!values.resume) {
      try {
        await fs.access(checkpoint)
        throw new Error("Checkpoint already exists; use --resume or a new path")
      } catch (error) {
        if (error.code !== "ENOENT") throw error
      }
    }
    state = await runWorkflow(state, {
      workers: config.workers,
      allowWrite: values["allow-write"],
      decide: createJevDecider({ apiKey: key }),
      signal: controller.signal,
      checkpoint: async (workflow) => {
        const temp = checkpoint + "." + randomUUID() + ".tmp"
        const file = await fs.open(temp, "wx", 0o600)
        try {
          await file.writeFile(
            JSON.stringify({ workspace, workflow }, null, 2) + "\n"
          )
          await file.sync()
        } finally {
          await file.close()
        }
        try {
          await fs.rename(temp, checkpoint)
        } finally {
          await fs.unlink(temp).catch(() => {})
        }
        process.stderr.write(
          `${workflow.status} · ${workflow.active?.phase ?? workflow.records.at(-1)?.phase ?? "ready"}\n`
        )
      },
      execute: (request, signal) =>
        execute(
          config.workers.find((worker) => worker.id === request.workerId),
          request,
          workspace,
          signal
        ),
    })
    process.stdout.write(JSON.stringify({ checkpoint, workflow: state }) + "\n")
    if (state.status !== "completed") process.exitCode = 1
  } finally {
    process.off("SIGINT", stop)
    process.off("SIGTERM", stop)
    await lock.close()
    await fs.unlink(lockPath)
  }
}

main().catch((error) => {
  const message =
    error instanceof SyntaxError
      ? "Invalid JSON in the worker configuration or checkpoint"
      : error.code
        ? `Operation failed (${error.code}); check the configuration, checkpoint and credential paths`
        : error.message
  process.stderr.write(`${message}\n`)
  process.exitCode = 1
})
