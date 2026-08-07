#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const segmentRe = /^[a-z0-9_-]+$/;

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

function argNumber(name, fallback) {
  const value = Number(argValue(name, ""));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function projectRoot() {
  return path.resolve(__dirname, "..");
}

function slugSegment(value, field) {
  const text = String(value || "").trim().toLowerCase();
  if (!text || !segmentRe.test(text) || text.includes("..") || text.includes("/") || text.includes("\\")) {
    throw new Error(`Invalid ${field}: ${value}; only a-z, 0-9, _, - are allowed`);
  }
  return text;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, payload) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(payload, null, 2), "utf8");
}

function claim(file) {
  const lock = `${file}.claim.lock`;
  try {
    const fd = fs.openSync(lock, "wx");
    fs.writeFileSync(fd, `pid=${process.pid}\ncreated_at=${Date.now()}\n`);
    return { fd, lock };
  } catch (err) {
    if (err.code === "EEXIST") return null;
    throw err;
  }
}

function release(claimed) {
  if (!claimed) return;
  try { fs.closeSync(claimed.fd); } catch (_) {}
  try { fs.unlinkSync(claimed.lock); } catch (_) {}
}

function prepareJob(inboxFile, jobsDir, outputRoot) {
  const claimed = claim(inboxFile);
  if (!claimed) return null;
  try {
    const job = readJson(inboxFile);
    const jobId = slugSegment(job.job_id || path.basename(inboxFile, ".json"), "job_id");
    const productId = slugSegment(job.product_id || "product", "product_id");
    const jobDir = path.join(jobsDir, jobId);
    const outputDir = path.join(outputRoot, productId, jobId);
    fs.mkdirSync(jobDir, { recursive: true });
    fs.mkdirSync(outputDir, { recursive: true });
    job.job_id = jobId;
    job.product_id = productId;
    job.status_dir = jobDir;
    job.output_dir = outputDir;
    job.scenes = (job.scenes || []).map((scene, index) => {
      const sceneId = slugSegment(scene.scene_id || `scene_${index + 1}`, "scene_id");
      return { ...scene, scene_id: sceneId, output_file: path.join(outputDir, `${sceneId}.mp4`) };
    });
    const jobJson = path.join(jobDir, "job.json");
    writeJson(jobJson, job);
    fs.renameSync(inboxFile, path.join(jobDir, "submitted_job.json"));
    release(claimed);
    return { jobJson, jobDir };
  } catch (err) {
    release(claimed);
    throw err;
  }
}

function runWorker(worker, jobJson, jobDir, running, onExit) {
  const logFile = path.join(jobDir, "worker.log");
  const log = fs.openSync(logFile, "a");
  const child = spawn(process.execPath, [worker, "--job", jobJson], { stdio: ["ignore", log, log], env: process.env });
  running.set(child.pid, child);
  console.log(`started worker pid=${child.pid} job=${jobJson}`);
  child.on("exit", (code) => {
    running.delete(child.pid);
    try { fs.closeSync(log); } catch (_) {}
    console.log(`worker exited pid=${child.pid} code=${code}`);
    onExit();
  });
}

async function main() {
  const root = projectRoot();
  const jobsDir = path.resolve(argValue("--jobs-dir", path.join(root, "video_jobs")));
  const inboxDir = path.join(jobsDir, "inbox");
  const outputRoot = path.resolve(process.env.N8N_LOCAL_OUTPUT_DIR || path.join(root, "video_output"));
  const worker = path.resolve(argValue("--worker", path.join(root, "workers", "moyin_worker.js")));
  const maxParallel = argNumber("--max-parallel", 2);
  const scanIntervalMs = argNumber("--scan-interval-seconds", 5) * 1000;
  const idleTimeoutMs = argNumber("--idle-timeout-seconds", 1800) * 1000;
  fs.mkdirSync(inboxDir, { recursive: true });
  fs.mkdirSync(outputRoot, { recursive: true });
  const running = new Map();
  let lastActivity = Date.now();
  const touch = () => { lastActivity = Date.now(); };
  console.log(`watching inbox=${inboxDir}`);
  while (true) {
    const files = fs.readdirSync(inboxDir).filter((name) => name.endsWith(".json")).sort();
    for (const name of files) {
      if (running.size >= maxParallel) break;
      const inboxFile = path.join(inboxDir, name);
      try {
        const prepared = prepareJob(inboxFile, jobsDir, outputRoot);
        if (!prepared) continue;
        touch();
        runWorker(worker, prepared.jobJson, prepared.jobDir, running, touch);
      } catch (err) {
        console.error(`failed to prepare ${inboxFile}: ${err.message || err}`);
        touch();
      }
    }
    if (running.size === 0 && Date.now() - lastActivity > idleTimeoutMs) {
      console.log("idle timeout reached; exiting watcher");
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, scanIntervalMs));
  }
}

main().catch((err) => {
  console.error(`worker_watcher failed: ${err.message || err}`);
  process.exit(1);
});
