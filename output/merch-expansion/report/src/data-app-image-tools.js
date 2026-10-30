import { isComponentPermalinkTargetVisible } from "./chart-permalink.js";

const maxCards = 8;
const maxImageBytes = 4 * 1024 * 1024;
const maxBatchBytes = 8 * 1024 * 1024;
const cardIdSchema = { type: "string", minLength: 1, maxLength: 200 };
const scaleSchema = { type: "number", minimum: 1, maximum: 3, default: 2 };

function validateInput(input, keys) {
  if (!input || typeof input !== "object" || Array.isArray(input)
    || Object.keys(input).some((key) => !keys.includes(key))) {
    throw new Error("Invalid Data app image tool input.");
  }
}

function validateCardId(id) {
  if (typeof id !== "string" || !id.trim() || id.length > 200) {
    throw new Error("Use an exact cardId returned by list_data_app_cards.");
  }
}

function cardMetadata({ component }) {
  return {
    cardId: component.id, title: component.title, kind: component.kind,
    queryIds: component.queryIds ?? [component.queryId],
    scopeFilters: component.scopeFilters ?? [],
  };
}

function cardUnavailableReason({ element }) {
  if (!isComponentPermalinkTargetVisible(element)) return "hidden";
  // DataComponent retains its visible frame while loading or showing a load
  // error. Those placeholders must not be exported as reviewed evidence.
  if (element.getAttribute("aria-busy") === "true" || element.hasAttribute("data-loading-kind")) {
    return "data_unavailable";
  }
  return null;
}

function imageFilename(id) {
  const stem = id.normalize("NFKD").replace(/\p{Mark}+/gu, "")
    .replace(/[^a-z0-9]+/giu, "-").replace(/^-+|-+$/gu, "").slice(0, 80) || "card";
  return `${stem}.png`;
}

async function base64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

// The shell supplies only registered cards beneath its own content root. Resolve
// exact IDs on every call; titles, permalink aliases, and CSS selectors are not IDs.
export function createDataAppImageTools({ getTargets, getViewState, renderImage }) {
  let active = true;
  let exporting = false;
  const assertActive = () => {
    if (!active) throw new Error("This Data app is no longer open. Fetch its tools again.");
  };
  function resolveCard(id) {
    assertActive();
    const matches = getTargets().filter(({ component }) => component.id === id);
    if (!matches.length) throw new Error(`Card ${JSON.stringify(id)} is not mounted in this view. Open its tab and call list_data_app_cards again.`);
    if (matches.length !== 1) throw new Error(`Card ID ${JSON.stringify(id)} is ambiguous. Give each card a unique ID.`);
    const unavailableReason = cardUnavailableReason(matches[0]);
    if (unavailableReason === "hidden") {
      throw new Error(`Card ${JSON.stringify(id)} is hidden. Show it before exporting.`);
    }
    if (unavailableReason === "data_unavailable") {
      throw new Error(`Card ${JSON.stringify(id)} has data that is loading or failed to load. Wait for a successful load before exporting.`);
    }
    return matches[0];
  }

  async function exportCards(ids, scale = 2) {
    assertActive();
    if (!Array.isArray(ids) || !ids.length || ids.length > maxCards || new Set(ids).size !== ids.length) {
      throw new Error(`Provide between 1 and ${maxCards} unique cardIds.`);
    }
    ids.forEach(validateCardId);
    if (!Number.isFinite(scale) || scale < 1 || scale > 3) throw new Error("Image scale must be between 1 and 3.");
    if (exporting) throw new Error("An image export is already running. Wait for it to finish.");
    const targets = ids.map(resolveCard);
    const view = JSON.stringify(getViewState());
    function assertUnchanged() {
      assertActive();
      if (JSON.stringify(getViewState()) !== view || targets.some((target, index) => {
        const current = resolveCard(ids[index]);
        return current.element !== target.element || current.component !== target.component;
      })) throw new Error("The Data app changed during image export. List the cards and retry.");
    }
    exporting = true;
    try {
      const images = [];
      let totalBytes = 0;
      for (const target of targets) {
        assertUnchanged();
        const { blob, width, height } = await renderImage(target.element, { scale });
        assertUnchanged();
        if (!blob?.size || blob.type !== "image/png") throw new Error("The card did not produce a PNG image.");
        totalBytes += blob.size;
        if (blob.size > maxImageBytes || totalBytes > maxBatchBytes) {
          throw new Error("Image export is too large. Use a smaller scale or fewer cards.");
        }
        images.push({ ...cardMetadata(target), mimeType: "image/png", encoding: "base64",
          data: await base64(blob), width, height, filename: imageFilename(target.component.id) });
      }
      assertUnchanged();
      return { view: JSON.parse(view), images };
    } finally {
      exporting = false;
    }
  }

  const annotations = { readOnlyHint: true, untrustedContentHint: true };
  const tools = [{
    name: "list_data_app_cards",
    description: "List mounted Data app cards with exact stable cardIds, titles, source queryIds, and image availability in the current tab and filters. Offscreen cards are included; unmounted tabs are not. Read-only; does not change the view.",
    annotations,
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    execute: async (input = {}) => {
      validateInput(input, []);
      assertActive();
      const targets = getTargets();
      const counts = new Map();
      for (const { component } of targets) counts.set(component.id, (counts.get(component.id) ?? 0) + 1);
      return { view: getViewState(), cards: targets.map((target) => {
        const unavailableReason = counts.get(target.component.id) > 1 ? "duplicate_id" : cardUnavailableReason(target);
        return {
          ...cardMetadata(target), imageAvailable: unavailableReason === null,
          ...(unavailableReason ? { unavailableReason } : {}),
        };
      }) };
    },
  }, {
    name: "get_data_app_card_image",
    description: "Export one mounted Data app card by its exact cardId from list_data_app_cards. Returns a PNG as base64 data with pixel width/height, filename, source IDs, and current view metadata for slides or documents. Captures the current rendered card, including filters and presentation; no clipboard, download, navigation, or data writes. Hidden, duplicate, loading, failed-to-load, changing, oversized, or unsupported cards fail explicitly. Decode data as base64 to save a PNG; do not print the image bytes as text.",
    annotations,
    inputSchema: { type: "object", properties: { cardId: cardIdSchema, scale: scaleSchema },
      required: ["cardId"], additionalProperties: false },
    execute: async (input) => {
      validateInput(input, ["cardId", "scale"]);
      const { view, images } = await exportCards([input.cardId], input.scale);
      return { view, ...images[0] };
    },
  }, {
    name: "get_data_app_card_images",
    description: "Export up to 8 unique mounted Data app cardIds as PNG images in requested order. Same read-only capture and base64 format as get_data_app_card_image; validates every ID before rendering and returns all images or an error, never a partial batch. Maximum 4 MiB per PNG and 8 MiB total; lower scale or split a large batch. Does not open inactive tabs.",
    annotations,
    inputSchema: { type: "object", properties: {
      cardIds: { type: "array", minItems: 1, maxItems: maxCards, uniqueItems: true, items: cardIdSchema },
      scale: scaleSchema,
    }, required: ["cardIds"], additionalProperties: false },
    execute: async (input) => {
      validateInput(input, ["cardIds", "scale"]);
      return exportCards(input.cardIds, input.scale);
    },
  }];
  return { tools, dispose: () => { active = false; } };
}
