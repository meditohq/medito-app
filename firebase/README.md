# Firebase Webhook → GitHub PR

Automatically create GitHub Pull Requests from Firebase events (Firestore changes, Crashlytics alerts, or any custom trigger).

## Architecture

```
Firebase Event
  ↓
Cloud Function (trigger or HTTP)
  ↓
GitHub repository_dispatch API
  ↓
GitHub Action workflow
  ↓
New branch + PR created automatically
```

## Setup

### 1. Create a GitHub Personal Access Token (PAT)

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token with these permissions on `meditohq/medito-app`:
   - **Contents**: Read and Write
   - **Pull requests**: Read and Write
3. Copy the token

### 2. Store the token as a Firebase secret

```bash
cd firebase/functions
firebase functions:secrets:set GITHUB_TOKEN
# Paste your GitHub PAT when prompted
```

### 3. Deploy the Cloud Functions

```bash
cd firebase/functions
npm install
firebase deploy --only functions
```

### 4. Test it

**Option A — Via the HTTP endpoint:**

```bash
curl -X POST \
  https://<REGION>-<PROJECT_ID>.cloudfunctions.net/webhookToGitHubPR \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Crashlytics: High crash rate in AudioPlayer",
    "description": "Crash rate exceeded 1% on Android 14 devices in the AudioPlayer screen.",
    "severity": "critical",
    "source": "crashlytics",
    "event_type": "crash_spike",
    "data": {
      "crash_count": 1523,
      "affected_users": 890,
      "version": "3.6.1"
    }
  }'
```

**Option B — Via Firestore (auto-trigger):**

Add a document to the `firebase_issues` collection in Firestore:

```json
{
  "title": "Performance degradation in meditation player",
  "description": "Average load time increased by 200ms",
  "severity": "high"
}
```

**Option C — Test locally with `curl` + GitHub API directly:**

```bash
curl -X POST \
  https://api.github.com/repos/meditohq/medito-app/dispatches \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR_GITHUB_TOKEN>" \
  -d '{
    "event_type": "firebase-alert",
    "client_payload": {
      "title": "Test: Firebase webhook PR",
      "description": "Testing the webhook-to-PR pipeline",
      "severity": "low",
      "source": "manual-test",
      "event_type": "test"
    }
  }'
```

## Payload Schema

| Field         | Type   | Required | Description                              |
|---------------|--------|----------|------------------------------------------|
| `title`       | string | Yes      | Short title for the PR                   |
| `description` | string | No       | Detailed description of the issue        |
| `severity`    | string | No       | `critical`, `high`, `medium`, or `low`   |
| `source`      | string | No       | Origin (e.g., `crashlytics`, `firestore`)|
| `event_type`  | string | No       | Type of event (e.g., `crash_spike`)      |
| `data`        | object | No       | Any additional structured data           |

## Connecting to Firebase Alerts

To forward Firebase Alerts (Crashlytics, Performance, App Distribution) to this webhook:

1. Go to **Firebase Console → Project Settings → Integrations**
2. Set up a **Cloud Function trigger** for the alert type you want
3. Or use **Firebase Alerting** to call the `webhookToGitHubPR` HTTP endpoint

## Files

- `.github/workflows/firebase-webhook-pr.yml` — GitHub Action that creates the PR
- `firebase/functions/index.js` — Cloud Functions (Firestore trigger + HTTP endpoint)
- `firebase/functions/package.json` — Node.js dependencies
