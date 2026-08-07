#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { pipeline } = require("stream/promises");
const { Readable } = require("stream");

const successDefaults = new Set(["completed", "succeeded", "success", "done"]);
const failedDefaults = new Set(["failed", "error", "cancelled", "canceled"]);
const segmentRe = /^[a-z0-9_-]+$/;
const mp4Re = /^[a-z0-9_-]+\.mp4$/;

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : "";
}

function localJobsRoot() {
  return process.env.N8N_LOCAL_JOBS_DIR || "E:/n8n-video-gemini/video_jobs";
}

function localOutputRoot() {
  return process.env.N8N_LOCAL_OUTPUT_DIR || "E:/n8n-video-gemini/video_output";
}

function slugify(value, fallback = "item") {
  const text = String(value || fallback).trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^[._-]+|[._-]+$/g, "");
  return (text || fallback).slice(0, 120);
}

function requireUnderRoot(value, label, rootValue, kind = "dir") {
  if (!value) throw new Error(`${label} is required`);
  const raw = String(value);
  if (/\0|[;|&`$<>]/.test(raw)) throw new Error(`${label} contains unsafe characters`);
  const resolved = path.resolve(raw);
  const root = path.resolve(rootValue);
  const rel = path.relative(root, resolved);
  if (!rel || rel.startsWith("..") || path.isAbsolute(rel)) throw new Error(`${label} must be under ${rootValue}`);
  const parts = rel.split(path.sep).filter(Boolean);
  if (parts.includes("..")) throw new Error(`${label} must not contain ..`);
  const checkParts = kind === "mp4" || kind === "job_json" ? parts.slice(0, -1) : parts;
  const filePart = kind === "mp4" || kind === "job_json" ? parts[parts.length - 1] : "";
  for (const part of checkParts) {
    if (!segmentRe.test(part)) throw new Error(`${label} contains non-slug path segment: ${part}`);
  }
  if (kind === "mp4" && !mp4Re.test(filePart)) throw new Error(`${label} file name must look like slug.mp4`);
  if (kind === "job_json" && filePart !== "job.json") throw new Error(`${label} file name must be job.json`);
  return resolved;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function atomicWriteJson(file, payload) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(payload, null, 2), "utf8");
  fs.renameSync(tmp, file);
}

function getByPath(obj, dotted) {
  let cur = obj;
  for (const part of String(dotted).split(".")) {
    if (cur == null || typeof cur !== "object" || !(part in cur)) return undefined;
    cur = cur[part];
  }
  return cur;
}

function firstByPaths(payload, paths) {
  for (const p of paths) {
    const value = getByPath(payload, p);
    if (value !== undefined && value !== null && String(value).trim() !== "") return value;
  }
  return "";
}

function extractStatus(payload, paths) {
  return String(firstByPaths(payload, paths && paths.length ? paths : ["status", "state", "data.status", "data.state", "result.status", "result.state"])).toLowerCase();
}

function extractVideoUrl(payload, paths) {
  return String(firstByPaths(payload, paths && paths.length ? paths : ["video_url", "url", "data.video_url", "data.url", "result.video_url", "result.url"]));
}

function buildQueryUrl(api, taskId) {
  const base = String(api.base_url || process.env.MOYIN_API_BASE_URL || "").replace(/\/+$/, "");
  if (!base) throw new Error("MOYIN_API_BASE_URL is required");
  const template = String(api.query_path_template || process.env.MOYIN_QUERY_PATH_TEMPLATE || "/videos/{task_id}");
  const queryPath = template.replaceAll("{task_id}", encodeURIComponent(taskId));
  return `${base}${queryPath.startsWith("/") ? "" : "/"}${queryPath}`;
}

function normalizeJob(job) {
  const safe = { ...job };
  safe.job_id = slugify(job.job_id, "job");
  safe.script_id = slugify(job.script_id, "script");
  safe.product_id = slugify(job.product_id, "product");
  safe.status_dir = requireUnderRoot(job.status_dir, "status_dir", localJobsRoot(), "dir");
  safe.output_dir = requireUnderRoot(job.output_dir, "output_dir", localOutputRoot(), "dir");
  safe.scenes = (job.scenes || []).map((scene, index) => {
    const sceneId = slugify(scene.scene_id, `scene-${index + 1}`);
    if (!String(scene.moyin_task_id || "").trim()) throw new Error(`scene ${sceneId} missing moyin_task_id`);
    return {
      ...scene,
      scene_id: sceneId,
      output_file: requireUnderRoot(scene.output_file, "scene.output_file", localOutputRoot(), "mp4"),
    };
  });
  if (!safe.scenes.length) throw new Error("job.scenes is empty");
  return safe;
}

async function queryMoyin(api, taskId, apiKey) {
  const url = buildQueryUrl(api, taskId);
  const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : {};
  const res = await fetch(url, { method: "GET", headers });
  const text = await res.text();
  if (!res.ok) throw new Error(`Moyin query HTTP ${res.status}: ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
}

async function downloadFile(url, outputFile) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download HTTP ${res.status}`);
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  const tmp = `${outputFile}.part`;
  await pipeline(Readable.fromWeb(res.body), fs.createWriteStream(tmp));
  fs.renameSync(tmp, outputFile);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const jobArg = argValue("--job");
  const jobPath = requireUnderRoot(jobArg, "job", localJobsRoot(), "job_json");
  const job = normalizeJob(readJson(jobPath));
  const api = job.moyin_api || {};
  const apiKey = (process.env.MOYIN_API_KEY || "").trim();
  const success = new Set((api.success_statuses && api.success_statuses.length ? api.success_statuses : [...successDefaults]).map((s) => String(s).toLowerCase()));
  const failed = new Set((api.failed_statuses && api.failed_statuses.length ? api.failed_statuses : [...failedDefaults]).map((s) => String(s).toLowerCase()));
  const statusDir = String(job.status_dir);
  const outputDir = String(job.output_dir);
  fs.mkdirSync(statusDir, { recursive: true });
  fs.mkdirSync(outputDir, { recursive: true });

  const scenesState = {};
  for (const scene of job.scenes) {
    scenesState[scene.scene_id] = { scene_id: scene.scene_id, moyin_task_id: scene.moyin_task_id, status: "queued", output_file: String(scene.output_file) };
  }

  const startedAt = Date.now();
  const maxMs = Number(job.max_runtime_seconds || 7200) * 1000;
  const intervalMs = Number(job.poll_interval_seconds || 60) * 1000;
  const statusFile = path.join(statusDir, "status.json");
  const writeStatus = (status, extra = {}) => atomicWriteJson(statusFile, { ...job, status, updated_at: new Date().toISOString(), scenes_state: scenesState, ...extra });
  const fail = (reason, status = "failed") => {
    const payload = { ...job, status, reason, updated_at: new Date().toISOString(), scenes_state: scenesState };
    atomicWriteJson(statusFile, payload);
    atomicWriteJson(path.join(statusDir, "failed.json"), payload);
  };

  writeStatus("running");
  while (true) {
    if (Date.now() - startedAt > maxMs) {
      fail("max_runtime_seconds exceeded", "timeout");
      process.exitCode = 1;
      return;
    }

    let allCompleted = true;
    for (const scene of job.scenes) {
      const state = scenesState[scene.scene_id];
      if (state.status === "completed") continue;
      allCompleted = false;
      let payload;
      try {
        payload = await queryMoyin(api, scene.moyin_task_id, apiKey);
      } catch (err) {
        state.status = "query_error";
        state.error = String(err.message || err);
        writeStatus("running");
        continue;
      }
      const status = extractStatus(payload, api.status_paths || []);
      state.last_payload_status = status;
      state.last_checked_at = new Date().toISOString();
      if (failed.has(status)) {
        state.status = status || "failed";
        state.payload = payload;
        fail(`scene ${scene.scene_id} failed: ${state.status}`);
        process.exitCode = 1;
        return;
      }
      if (success.has(status)) {
        const videoUrl = extractVideoUrl(payload, api.video_url_paths || []);
        if (!videoUrl) {
          fail(`scene ${scene.scene_id} completed without video_url`);
          process.exitCode = 1;
          return;
        }
        state.status = "downloading";
        state.video_url = videoUrl;
        writeStatus("running");
        try {
          await downloadFile(videoUrl, String(scene.output_file));
        } catch (err) {
          state.status = "download_error";
          state.error = String(err.message || err);
          fail(`scene ${scene.scene_id} download failed`);
          process.exitCode = 1;
          return;
        }
        state.status = "completed";
        state.completed_at = new Date().toISOString();
        writeStatus("running");
      } else {
        state.status = status || "processing";
        writeStatus("running");
      }
    }

    if (allCompleted || Object.values(scenesState).every((s) => s.status === "completed")) {
      const payload = { ...job, status: "completed", completed_at: new Date().toISOString(), scenes_state: scenesState };
      atomicWriteJson(statusFile, payload);
      atomicWriteJson(path.join(statusDir, "done.json"), payload);
      return;
    }
    await sleep(intervalMs);
  }
}

main().catch((err) => {
  console.error(`moyin_worker failed: ${err.message || err}`);
  process.exit(1);
});
