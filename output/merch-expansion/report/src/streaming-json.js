// Portable JSON parsing/serialization. Chunks bound temporary strings; callers
// still own the complete parsed value unless they explicitly discard containers.
const CHUNK_SIZE = 64 * 1024;
const NUMBER_DIGITS = 1100;
const JSON_WHITESPACE = new Set([" ", "\t", "\n", "\r"]);
const STRING_SPECIAL = /["\\\u0000-\u001f]/g;
const ESCAPES = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };

/**
 * Incrementally parse exactly one JSON value. write accepts strings (not bytes).
 * discard(path) may replace a container with an empty {} or [], while its
 * complete grammar is still checked. Paths use string keys and numeric indices.
 * onValue({ value, path }) observes completed values, including overwritten
 * duplicate properties; discarded containers are represented by placeholders.
 */
export function createStreamingJsonParser({ discard, onValue } = {}) {
  const stack = [];
  let root;
  let rootComplete = false;
  let finished = false;
  let failed = false;
  let offset = 0;
  let token = null;

  function invalid(message = "Invalid JSON") {
    failed = true;
    throw new SyntaxError(`${message} at position ${offset}`);
  }

  function pathForValue() {
    const path = stack.slice(1).map((frame) => frame.segment);
    const parent = stack.at(-1);
    if (parent) path.push(parent.type === "array" ? parent.index : parent.key);
    return path;
  }

  function complete(value) {
    if (onValue) onValue({ value, path: pathForValue() });
    const parent = stack.at(-1);
    if (!parent) {
      root = value;
      rootComplete = true;
    } else if (parent.type === "array") {
      if (!parent.skip) parent.value.push(value);
      parent.index += 1;
      parent.phase = "comma";
    } else {
      if (!parent.skip) {
        // Assignment to this name would invoke Object.prototype's setter.
        if (parent.key === "__proto__") {
          Object.defineProperty(parent.value, parent.key, {
            value, writable: true, enumerable: true, configurable: true,
          });
        } else parent.value[parent.key] = value;
      }
      parent.key = null;
      parent.phase = "comma";
    }
  }

  function closeContainer() {
    const frame = stack.pop();
    complete(frame.value);
  }

  function addDigit(character) {
    if (token.fraction) token.fractionDigits += 1;
    if (token.significantDigits === 0 && character === "0") return;
    token.significantDigits += 1;
    if (token.digits.length < NUMBER_DIGITS) token.digits += character;
    else if (character !== "0") token.sticky = true;
  }

  function finishNumber() {
    if (!["zero", "integer", "fraction", "exponent"].includes(token.phase)) invalid("Incomplete JSON number");
    // Every binary64 rounding boundary has fewer than 1100 significant decimal
    // digits. Keep that prefix plus one sticky digit so arbitrarily long JSON
    // numbers round exactly, including subnormals and overflow, without keeping
    // an arbitrarily long token string.
    let digits = token.digits;
    if (token.sticky) digits += "1";
    const exponent = token.exponentSign * token.exponent - token.fractionDigits
      + token.significantDigits - digits.length;
    const value = digits.length === 0 ? (token.negative ? -0 : 0)
      : Number(`${token.negative ? "-" : ""}${digits}e${exponent}`);
    token = null;
    complete(value);
  }

  function numberCharacter(character) {
    const digit = character >= "0" && character <= "9";
    if (token.phase === "sign") {
      if (!digit) invalid("Invalid JSON number");
      token.phase = character === "0" ? "zero" : "integer";
      addDigit(character);
    } else if (token.phase === "integer" && digit) addDigit(character);
    else if ((token.phase === "zero" || token.phase === "integer") && character === ".") {
      token.fraction = true;
      token.phase = "dot";
    } else if (token.phase === "dot" && digit) {
      token.phase = "fraction";
      addDigit(character);
    } else if (token.phase === "fraction" && digit) addDigit(character);
    else if (["zero", "integer", "fraction"].includes(token.phase) && (character === "e" || character === "E")) token.phase = "e";
    else if (token.phase === "e" && (character === "+" || character === "-")) {
      token.exponentSign = character === "-" ? -1 : 1;
      token.phase = "exponent-sign";
    } else if (["e", "exponent-sign", "exponent"].includes(token.phase) && digit) {
      token.phase = "exponent";
      token.exponent = Math.min(Number.MAX_SAFE_INTEGER, token.exponent * 10 + Number(character));
    } else return false;
    return true;
  }

  function startString(key) {
    token = { type: "string", key, parts: [], escape: false, unicode: null,
      keep: Boolean(onValue || !stack.at(-1)?.skip) };
  }

  function startValue(character) {
    if (character === "{" || character === "[") {
      const parent = stack.at(-1);
      const segment = parent ? (parent.type === "array" ? parent.index : parent.key) : null;
      const skip = Boolean(parent?.skip || (discard && discard(pathForValue())));
      const type = character === "[" ? "array" : "object";
      stack.push({ type, value: type === "array" ? [] : {}, phase: "first", skip, segment, key: null, index: 0 });
    } else if (character === '"') startString(false);
    else if (character === "t" || character === "f" || character === "n") {
      token = { type: "literal", expected: character === "t" ? "true" : character === "f" ? "false" : "null", index: 1 };
    } else if (character === "-" || (character >= "0" && character <= "9")) {
      token = { type: "number", phase: "sign", negative: character === "-", digits: "", significantDigits: 0,
        fraction: false, fractionDigits: 0, exponent: 0, exponentSign: 1, sticky: false };
      if (character !== "-") numberCharacter(character);
    } else invalid("Expected a JSON value");
  }

  function write(text) {
    if (finished || failed) throw new SyntaxError("JSON parser is no longer writable");
    if (typeof text !== "string") throw new TypeError("JSON parser chunks must be strings");
    let index = 0;
    let stringSpecialIndex = -1;
    try {
      while (index < text.length) {
        const character = text[index];
        if (token?.type === "string") {
          if (token.unicode !== null) {
            if (!/[0-9a-fA-F]/.test(character)) invalid("Invalid JSON Unicode escape");
            token.unicode += character;
            if (token.unicode.length === 4) {
              if (token.keep) token.parts.push(String.fromCharCode(Number.parseInt(token.unicode, 16)));
              token.unicode = null;
            }
          } else if (token.escape) {
            token.escape = false;
            if (character === "u") token.unicode = "";
            else if (Object.hasOwn(ESCAPES, character)) {
              if (token.keep) token.parts.push(ESCAPES[character]);
            }
            else invalid("Invalid JSON escape");
          } else if (character === '"') {
            const value = token.parts.join("");
            const key = token.key;
            token = null;
            if (key) {
              stack.at(-1).key = value;
              stack.at(-1).phase = "colon";
            } else complete(value);
          } else if (character === "\\") token.escape = true;
          else if (character < " ") invalid("Unescaped control character in JSON string");
          else {
            if (stringSpecialIndex < index) {
              STRING_SPECIAL.lastIndex = index;
              stringSpecialIndex = STRING_SPECIAL.exec(text)?.index ?? text.length;
            }
            const end = Math.min(stringSpecialIndex, index + CHUNK_SIZE);
            // Native parsing copies this bounded, escape-free span. Keeping a
            // substring instead can retain its entire decoded input window for
            // the lifetime of a tiny cell value (notably in V8).
            if (token.keep) token.parts.push(JSON.parse(`"${text.slice(index, end)}"`));
            offset += end - index;
            index = end;
            continue;
          }
        } else if (token?.type === "number") {
          if (!numberCharacter(character)) {
            finishNumber();
            continue;
          }
        } else if (token?.type === "literal") {
          if (character !== token.expected[token.index]) invalid("Invalid JSON literal");
          token.index += 1;
          if (token.index === token.expected.length) {
            const value = token.expected === "true" ? true : token.expected === "false" ? false : null;
            token = null;
            complete(value);
          }
        } else if (!JSON_WHITESPACE.has(character)) {
          const frame = stack.at(-1);
          if (!frame) {
            if (rootComplete) invalid("Unexpected content after JSON value");
            startValue(character);
          } else if (frame.type === "array") {
            if (frame.phase === "comma") {
              if (character === ",") frame.phase = "value";
              else if (character === "]") closeContainer();
              else invalid("Expected ',' or ']' in JSON array");
            } else if (frame.phase === "first" && character === "]") closeContainer();
            else startValue(character);
          } else if (frame.phase === "first" && character === "}") closeContainer();
          else if (frame.phase === "first" || frame.phase === "key") {
            if (character !== '"') invalid("Expected a JSON object key");
            startString(true);
          } else if (frame.phase === "colon") {
            if (character !== ":") invalid("Expected ':' after JSON object key");
            frame.phase = "value";
          } else if (frame.phase === "value") startValue(character);
          else if (character === ",") frame.phase = "key";
          else if (character === "}") closeContainer();
          else invalid("Expected ',' or '}' in JSON object");
        }
        index += 1;
        offset += 1;
      }
    } catch (error) {
      failed = true;
      throw error;
    }
  }

  function finish() {
    if (finished || failed) throw new SyntaxError("JSON parser has already finished or failed");
    finished = true;
    if (token?.type === "number") finishNumber();
    if (token || stack.length || !rootComplete) invalid("Unexpected end of JSON input");
    return root;
  }

  return { write, finish };
}

/** Decode bounded byte slices, matching Buffer UTF-8 decoding by default. */
export function parseJsonBytes(bytes, { fatal = false, ignoreBOM = true, ...options } = {}) {
  const view = bytes instanceof ArrayBuffer ? new Uint8Array(bytes)
    : new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const decoder = new TextDecoder("utf-8", { fatal, ignoreBOM });
  const parser = createStreamingJsonParser(options);
  for (let offset = 0; offset < view.byteLength; offset += CHUNK_SIZE) {
    parser.write(decoder.decode(view.subarray(offset, offset + CHUNK_SIZE), { stream: true }));
  }
  parser.write(decoder.decode());
  return parser.finish();
}

/** Match Response.json UTF-8/BOM behavior without a whole-response string. */
export async function parseJsonResponse(response, { fatal = false, ignoreBOM = false, ...options } = {}) {
  const parser = createStreamingJsonParser(options);
  const decoder = new TextDecoder("utf-8", { fatal, ignoreBOM });
  if (!response.body) return parser.finish();
  const reader = response.body.getReader();
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      for (let offset = 0; offset < value.byteLength; offset += CHUNK_SIZE) {
        parser.write(decoder.decode(value.subarray(offset, offset + CHUNK_SIZE), { stream: true }));
      }
    }
    parser.write(decoder.decode());
    return parser.finish();
  } catch (error) {
    try { await reader.cancel(error); } catch { /* Preserve the parse/read error. */ }
    throw error;
  } finally {
    reader.releaseLock();
  }
}

function* stringChunks(value) {
  yield '"';
  for (let offset = 0; offset < value.length;) {
    let end = Math.min(offset + CHUNK_SIZE / 8, value.length);
    // JSON.stringify escapes lone surrogates; never split a valid pair.
    if (end < value.length && value.charCodeAt(end - 1) >= 0xd800 && value.charCodeAt(end - 1) <= 0xdbff
      && value.charCodeAt(end) >= 0xdc00 && value.charCodeAt(end) <= 0xdfff) end -= 1;
    yield JSON.stringify(value.slice(offset, end)).slice(1, -1);
    offset = end;
  }
  yield '"';
}

function jsonValue(holder, key) {
  let value = holder[key];
  if ((value !== null && typeof value === "object") || typeof value === "function" || typeof value === "bigint") {
    const toJSON = value.toJSON;
    if (typeof toJSON === "function") value = toJSON.call(value, key);
  }
  if (value instanceof Number) value = +value;
  else if (value instanceof String) value = String(value);
  else if (value instanceof Boolean) value = Boolean.prototype.valueOf.call(value);
  else if (value instanceof BigInt) value = BigInt.prototype.valueOf.call(value);
  return value;
}

/** Yield compact JSON.stringify-compatible output; undefined roots emit nothing. */
export function* stringifyJsonChunks(value) {
  const ancestors = new Set();
  const stack = [{ type: "value", value: jsonValue({ "": value }, "") }];
  let buffer = "";
  function* emit(text) {
    if (buffer.length + text.length > CHUNK_SIZE) {
      if (buffer) yield buffer;
      buffer = "";
    }
    buffer += text;
  }
  while (stack.length) {
    const frame = stack.at(-1);
    if (frame.type === "value") {
      stack.pop();
      const current = frame.value;
      if (typeof current === "string") {
        for (const part of stringChunks(current)) yield* emit(part);
      } else if (current === null || typeof current === "number" || typeof current === "boolean") yield* emit(JSON.stringify(current));
      else if (typeof current === "bigint") throw new TypeError("Do not know how to serialize a BigInt");
      else if (typeof current === "object") {
        if (ancestors.has(current)) throw new TypeError("Converting circular structure to JSON");
        ancestors.add(current);
        const array = Array.isArray(current);
        stack.push({ type: array ? "array" : "object", value: current, keys: array ? null : Object.keys(current),
          length: array ? current.length : 0, index: 0, emitted: false });
        yield* emit(array ? "[" : "{");
      }
    } else {
      if (frame.index === (frame.keys?.length ?? frame.length)) {
        stack.pop();
        ancestors.delete(frame.value);
        yield* emit(frame.type === "array" ? "]" : "}");
        continue;
      }
      const key = frame.keys ? frame.keys[frame.index] : String(frame.index);
      frame.index += 1;
      let current = jsonValue(frame.value, key);
      if (current === undefined || typeof current === "function" || typeof current === "symbol") {
        if (frame.type === "object") continue;
        current = null;
      }
      if (frame.emitted) yield* emit(",");
      frame.emitted = true;
      if (frame.type === "object") {
        for (const part of stringChunks(key)) yield* emit(part);
        yield* emit(":");
      }
      stack.push({ type: "value", value: current });
    }
  }
  if (buffer) yield buffer;
}
