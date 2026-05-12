const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const crypto = require("crypto");

// Store your secrets in Firebase:
//   firebase functions:secrets:set GITHUB_TOKEN
//   firebase functions:secrets:set WEBHOOK_SECRET
const githubToken = defineSecret("GITHUB_TOKEN");
const webhookSecret = defineSecret("WEBHOOK_SECRET");

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = "meditohq";
const GITHUB_REPO = "medito-app";

const SEVERITY_LABELS = {
  critical: "critical",
  high: "high",
  medium: "medium",
  low: "low",
};

// ─── Helper: Verify HMAC signature ──────────────────────────────────────────
function verifySignature(secret, rawBody, signatureHeader) {
  if (!signatureHeader || !signatureHeader.startsWith("sha256=")) return false;

  try {
    // Compute HMAC over raw bytes when available, otherwise canonical JSON
    const payload = Buffer.isBuffer(rawBody) ? rawBody : JSON.stringify(rawBody);
    const expected = crypto
      .createHmac("sha256", secret)
      .update(payload)
      .digest();

    const signature = signatureHeader.slice("sha256=".length);
    if (!/^[a-fA-F0-9]{64}$/.test(signature)) return false;

    const provided = Buffer.from(signature, "hex");
    if (provided.length !== expected.length) return false;

    return crypto.timingSafeEqual(expected, provided);
  } catch {
    return false;
  }
}

// ─── Helper: GitHub API request ──────────────────────────────────────────────
async function githubAPI(method, path, body) {
  const token = githubToken.value();
  const response = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GitHub API ${method} ${path} → ${response.status}: ${text}`);
  }

  if (response.status === 204) return null;
  return response.json();
}

// ─── Helper: Create GitHub Issue ────────────────────────────────────────────
async function createGitHubIssue({ title, description, severity, source, eventType, data }) {
  const severityLabel = SEVERITY_LABELS[severity] || "medium";

  const issueBody = [
    `## ${source || "Firebase"} Alert`,
    "",
    `| Field | Value |`,
    `|-------|-------|`,
    `| **Source** | ${source || "firebase"} |`,
    `| **Event** | ${eventType || "unknown"} |`,
    `| **Severity** | ${severityLabel} |`,
    `| **Time** | ${new Date().toISOString()} |`,
    "",
    "## Description",
    "",
    description || "No description provided.",
    "",
    "## Raw Data",
    "",
    "```json",
    JSON.stringify(data || {}, null, 2),
    "```",
    "",
    `[View in Firebase Console](https://console.firebase.google.com/project/medito-9165c/crashlytics)`,
    "",
    "---",
    "*Auto-created by Firebase Cloud Function*",
  ].join("\n");

  const labels = ["firebase-alert", severityLabel].filter(Boolean);

  const issue = await githubAPI("POST", `/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`, {
    title: title || "Untitled Firebase Alert",
    body: issueBody,
    labels,
  });

  logger.info("GitHub issue created", { number: issue.number, title });
}

// ─── Firestore trigger ───────────────────────────────────────────────────────
exports.onFirestoreIssueCreated = onDocumentCreated(
  {
    document: "firebase_issues/{docId}",
    secrets: [githubToken],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("No data in Firestore event");
      return;
    }

    const doc = snap.data();

    await createGitHubIssue({
      title: doc.title || `Firestore issue: ${event.params.docId}`,
      description: doc.description || "",
      severity: doc.severity || "medium",
      source: "firestore",
      eventType: "document_created",
      data: doc,
    });
  }
);

// ─── HTTP endpoint: generic webhook receiver ─────────────────────────────────
exports.webhookToGitHubPR = onRequest(
  {
    secrets: [githubToken, webhookSecret],
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Verify HMAC signature
    const secret = webhookSecret.value();
    if (!secret) {
      logger.error("WEBHOOK_SECRET is not configured");
      res.status(500).json({ error: "Server misconfiguration" });
      return;
    }

    const signature = req.get("X-Webhook-Signature");
    if (!verifySignature(secret, req.rawBody || req.body, signature)) {
      res.status(401).json({ error: "Invalid or missing signature" });
      return;
    }

    const body = req.body ?? {};
    const { title, description, severity, source, event_type, data } = body;

    if (!title) {
      res.status(400).json({ error: "Missing required field: title" });
      return;
    }

    try {
      await createGitHubIssue({
        title,
        description,
        severity,
        source,
        eventType: event_type,
        data,
      });
      res.status(200).json({ success: true, message: "GitHub issue + PR workflow triggered" });
    } catch (err) {
      logger.error("Failed to create issue / trigger PR", err);
      res.status(500).json({ error: err.message });
    }
  }
);
