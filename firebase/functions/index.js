const { onNewFatalIssuePublished, onNewAnrIssuePublished, onRegressionAlertPublished } = require("firebase-functions/v2/alerts/crashlytics");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");

const githubToken = defineSecret("GITHUB_TOKEN");

const GITHUB_OWNER = "meditohq";
const GITHUB_REPO = "medito-app";

async function createGitHubIssue({ title, body }) {
  const token = githubToken.value();
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: JSON.stringify({ title, body, labels: ["crash"] }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GitHub API error ${response.status}: ${text}`);
  }

  const issue = await response.json();
  logger.info("GitHub issue created", { url: issue.html_url });
  return issue;
}

function buildIssueBody(issue, appVersion, platform) {
  return [
    `**App version:** ${appVersion || "unknown"}`,
    `**Platform:** ${platform || "unknown"}`,
    `**Issue ID:** ${issue.id}`,
    `**First seen:** ${issue.createTime || "unknown"}`,
    "",
    "## Stack trace",
    "```",
    issue.subtitle || "No stack trace available",
    "```",
    "",
    `[View in Firebase Console](https://console.firebase.google.com/project/medito-9165c/crashlytics)`,
  ].join("\n");
}

exports.onCrash = onNewFatalIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const { appVersion, crashIssue } = event.data.payload;
    const title = `[Crash] ${crashIssue.title}`;
    const body = buildIssueBody(crashIssue, appVersion, "mobile");

    try {
      await createGitHubIssue({ title, body });
    } catch (err) {
      logger.error("Failed to create GitHub issue", err);
      throw err;
    }
  }
);

exports.onRegressed = onRegressionAlertPublished(
  { secrets: [githubToken] },
  async (event) => {
    const { appVersion, regressedIssue } = event.data.payload;
    const title = `[Regressed] ${regressedIssue.title}`;
    const body = buildIssueBody(regressedIssue, appVersion, "mobile");

    try {
      await createGitHubIssue({ title, body });
    } catch (err) {
      logger.error("Failed to create GitHub issue", err);
      throw err;
    }
  }
);

exports.onAnr = onNewAnrIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const { appVersion, anrIssue } = event.data.payload;
    const title = `[ANR] ${anrIssue.title}`;
    const body = buildIssueBody(anrIssue, appVersion, "android");

    try {
      await createGitHubIssue({ title, body });
    } catch (err) {
      logger.error("Failed to create GitHub issue", err);
      throw err;
    }
  }
);
