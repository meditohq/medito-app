const chartPermalinkPattern = /^\/_data\/charts\/([^/]+)(\/detail)?$/u;
const componentPermalinkPattern = /^\/_data\/components\/([^/]+)$/u;
const urlUuidNamespace = Uint8Array.of(
  0x6b,
  0xa7,
  0xb8,
  0x11,
  0x9d,
  0xad,
  0x11,
  0xd1,
  0x80,
  0xb4,
  0x00,
  0xc0,
  0x4f,
  0xd4,
  0x30,
  0xc8,
);

function rotateLeft(value, bits) {
  return (value << bits) | (value >>> (32 - bits));
}

// UUIDv5 requires SHA-1 for stable identities; this digest is never used for authentication.
function sha1(bytes) {
  const length = Math.ceil((bytes.length + 9) / 64) * 64;
  const padded = new Uint8Array(length);
  padded.set(bytes);
  padded[bytes.length] = 0x80;
  const view = new DataView(padded.buffer);
  const bitLength = bytes.length * 8;
  view.setUint32(length - 8, Math.floor(bitLength / 0x1_0000_0000));
  view.setUint32(length - 4, bitLength >>> 0);

  const state = Uint32Array.of(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0);
  const words = new Uint32Array(80);
  for (let offset = 0; offset < length; offset += 64) {
    for (let index = 0; index < 16; index += 1) words[index] = view.getUint32(offset + index * 4);
    for (let index = 16; index < 80; index += 1) {
      words[index] = rotateLeft(words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16], 1);
    }

    let [a, b, c, d, e] = state;
    for (let index = 0; index < 80; index += 1) {
      let mix;
      let constant;
      if (index < 20) {
        mix = (b & c) | (~b & d);
        constant = 0x5a827999;
      } else if (index < 40) {
        mix = b ^ c ^ d;
        constant = 0x6ed9eba1;
      } else if (index < 60) {
        mix = (b & c) | (b & d) | (c & d);
        constant = 0x8f1bbcdc;
      } else {
        mix = b ^ c ^ d;
        constant = 0xca62c1d6;
      }
      const next = (rotateLeft(a, 5) + mix + e + constant + words[index]) >>> 0;
      e = d;
      d = c;
      c = rotateLeft(b, 30) >>> 0;
      b = a;
      a = next;
    }
    state[0] = (state[0] + a) >>> 0;
    state[1] = (state[1] + b) >>> 0;
    state[2] = (state[2] + c) >>> 0;
    state[3] = (state[3] + d) >>> 0;
    state[4] = (state[4] + e) >>> 0;
  }

  const result = new Uint8Array(20);
  const resultView = new DataView(result.buffer);
  for (let index = 0; index < state.length; index += 1) resultView.setUint32(index * 4, state[index]);
  return result;
}

export function validComponentId(id) {
  if (typeof id !== "string" || id.length > 200 || !id.trim() || id === "." || id === ".." || /[\\/\0]/u.test(id))
    return false;

  try {
    encodeURIComponent(id);
    return true;
  } catch {
    return false;
  }
}

export function isComponentPermalinkTargetVisible(element) {
  if (!element?.isConnected || element.closest("[hidden], [inert]") || !element.getClientRects().length) {
    return false;
  }
  const { visibility } = element.ownerDocument.defaultView.getComputedStyle(element);
  return visibility !== "hidden" && visibility !== "collapse";
}

export function componentPermalinkId(location, id) {
  if (!validComponentId(id)) throw new Error("A non-empty, safe dashboard component ID is required.");

  let source;
  try {
    source = new URL(typeof location === "string" ? location : location?.href ?? location?.origin);
  } catch {
    throw new Error("A valid hosted Data app URL is required to identify a dashboard component.");
  }
  if (!["http:", "https:"].includes(source.protocol)) {
    throw new Error("A valid hosted Data app URL is required to identify a dashboard component.");
  }

  const name = new TextEncoder().encode(`openai.data-app.component\0${source.origin}\0${id}`);
  const input = new Uint8Array(urlUuidNamespace.length + name.length);
  input.set(urlUuidNamespace);
  input.set(name, urlUuidNamespace.length);
  const digest = sha1(input);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = Array.from(digest.subarray(0, 16), (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function componentPermalinkShortId(location, id) {
  const uuid = componentPermalinkId(location, id);
  const hex = uuid.slice(0, 8) + uuid.slice(9, 13);
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  let alias = "";

  for (let offset = 0; offset < hex.length; offset += 6) {
    const group = Number.parseInt(hex.slice(offset, offset + 6), 16);
    alias +=
      alphabet[(group >>> 18) & 63] +
      alphabet[(group >>> 12) & 63] +
      alphabet[(group >>> 6) & 63] +
      alphabet[group & 63];
  }
  return alias;
}

export function readChartPermalink(location = globalThis.location) {
  const pathname = typeof location === "string" ? location : location?.pathname;
  if (typeof pathname !== "string") return null;

  const match = chartPermalinkPattern.exec(pathname);
  if (!match) return null;

  try {
    const id = decodeURIComponent(match[1]);
    return validComponentId(id) ? { id, detail: match[2] === "/detail" } : null;
  } catch {
    return null;
  }
}

export function readComponentPermalink(location = globalThis.location) {
  const pathname = typeof location === "string" ? location : location?.pathname;
  if (typeof pathname !== "string") return null;

  const match = componentPermalinkPattern.exec(pathname);
  if (match) {
    try {
      const id = decodeURIComponent(match[1]);
      return validComponentId(id) ? { id, detail: false, kind: "component" } : null;
    } catch {
      return null;
    }
  }

  const chart = readChartPermalink(pathname);
  return chart ? { ...chart, kind: "chart" } : null;
}

export function canonicalDashboardPath(pathname) {
  return readComponentPermalink(pathname) ? "/" : pathname;
}

function dashboardPermalink(location, id, kind, detail = false) {
  const noun = kind === "charts" ? "chart" : "dashboard";
  if (!validComponentId(id)) throw new Error(`A non-empty, safe ${noun} component ID is required.`);

  let source;
  try {
    source = new URL(typeof location === "string" ? location : location?.href ?? location?.origin);
  } catch {
    throw new Error(`A valid hosted Data app URL is required to create a ${noun} link.`);
  }
  if (!["http:", "https:"].includes(source.protocol)) {
    throw new Error(`A valid hosted Data app URL is required to create a ${noun} link.`);
  }

  return `${source.origin}/_data/${kind}/${encodeURIComponent(id)}${detail ? "/detail" : ""}`;
}

export function chartPermalink(location, id, { detail = false } = {}) {
  return dashboardPermalink(location, id, "charts", detail);
}

export function componentPermalink(location, id) {
  return dashboardPermalink(location, id, "components");
}
