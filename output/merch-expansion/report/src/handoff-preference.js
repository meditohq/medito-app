import { refreshCoachmarkDomain as workspaceCookieDomain } from "./refresh-coachmark.js";

// A browser convenience shared by workspace Sites, not identity or routing authority.
export const HANDOFF_DESTINATION_COOKIE = "data_app_handoff_destination_v1";
const maxAge = 400 * 24 * 60 * 60;
const validDestination = destination => destination === "desktop" || destination === "web";

function destinationCookies(document) {
  return document.cookie.split(";").map(value => value.trim())
    .filter(value => value.split("=", 1)[0] === HANDOFF_DESTINATION_COOKIE);
}

export function readHandoffDestination({ document = globalThis.document, location = globalThis.location } = {}) {
  try {
    if (!workspaceCookieDomain(location) || !document) return null;
    const values = destinationCookies(document);
    if (values.length !== 1) return null;
    const destination = values[0].slice(HANDOFF_DESTINATION_COOKIE.length + 1);
    return validDestination(destination) ? destination : null;
  } catch { return null; }
}

export function writeHandoffDestination(destination, { document = globalThis.document, location = globalThis.location } = {}) {
  try {
    if (destination !== null && !validDestination(destination)) return false;
    const domain = workspaceCookieDomain(location);
    if (!domain || !document) return false;
    document.cookie = `${HANDOFF_DESTINATION_COOKIE}=${destination ?? ""}; Domain=${domain}; Path=/; Max-Age=${destination === null ? 0 : maxAge}; Secure; SameSite=Lax`;
    return destination === null
      ? destinationCookies(document).length === 0
      : readHandoffDestination({ document, location }) === destination;
  } catch { return false; }
}
