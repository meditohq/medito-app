// This is anonymous browser education state, not authentication or analytics.
// One workspace-domain cookie is shared by all of its dashboard subdomains.
export const REFRESH_COACHMARK_COOKIE = "data_app_refresh_coachmark_v1";
const maxAge = 400 * 24 * 60 * 60;

export function refreshCoachmarkDomain(location = globalThis.location) {
  if (location?.protocol !== "https:") return null;
  const match = /^([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)\.([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)\.chatgpt\.site$/u
    .exec(location.hostname?.toLowerCase() ?? "");
  // Direct personal Site hosts have no workspace-wide scope. Never fall back to a
  // host-only cookie, a public-suffix cookie, or a custom domain.
  return match ? `${match[2]}.chatgpt.site` : null;
}

function cookieValue(document) {
  const values = document.cookie.split(";").map(value => value.trim());
  return values.find(value => value.startsWith(`${REFRESH_COACHMARK_COOKIE}=`))?.slice(REFRESH_COACHMARK_COOKIE.length + 1);
}

function writeCookie(document, domain, value) {
  document.cookie = `${REFRESH_COACHMARK_COOKIE}=${value}; Domain=${domain}; Path=/; Max-Age=${maxAge}; Secure; SameSite=Lax`;
}

export function rememberRefreshCoachmark({ document = globalThis.document, location = globalThis.location } = {}) {
  const domain = refreshCoachmarkDomain(location);
  if (!domain || !document) return false;
  try {
    writeCookie(document, domain, "1");
    return cookieValue(document) === "1";
  } catch { return false; }
}

export async function claimRefreshCoachmark({
  document = globalThis.document,
  location = globalThis.location,
  nonce = () => globalThis.crypto.randomUUID(),
  settle = () => new Promise(resolve => setTimeout(resolve, 180)),
  cancelled = () => false,
} = {}) {
  const domain = refreshCoachmarkDomain(location);
  if (!domain || !document || cancelled()) return false;
  try {
    const existing = cookieValue(document);
    if (existing !== undefined) {
      // Renew a completed marker as owners return, within browser retention
      // limits. Do not overwrite another tab's in-progress claim.
      if (existing === "1") writeCookie(document, domain, "1");
      return false;
    }
    const claim = nonce();
    if (!/^[a-zA-Z0-9-]{8,80}$/u.test(claim)) return false;
    writeCookie(document, domain, claim);
    if (cookieValue(document) !== claim) return false;
    // A short readback interval suppresses ordinary concurrent first opens.
    // Cookies are not an atomic cross-origin lock; this is UI suppression,
    // never an exactly-once transaction or a permission boundary.
    await settle();
    if (cancelled() || cookieValue(document) !== claim) return false;
    writeCookie(document, domain, "1");
    return cookieValue(document) === "1";
  } catch { return false; }
}
