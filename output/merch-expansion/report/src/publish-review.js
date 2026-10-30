export function publishReviewDestination(href) {
  try {
    const url = new URL(href);
    if (url.protocol === "codex:") return "Codex";
    if (url.protocol === "https:" && url.hostname === "chatgpt.com") return "ChatGPT";
  } catch { /* Missing routes stay explicit rather than naming a guessed host. */ }
  return null;
}
