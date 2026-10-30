import { toSvg } from "html-to-image";

const MAX_PIXELS = 16_000_000;
const MAX_DIMENSION = 16_384;
const CAPTURE_TIMEOUT_MS = 10_000;
const OMIT = '[role="menu"], [role="tooltip"], .menu-trigger, .info-wrap, .block-resize-boundary, .recharts-tooltip-wrapper, .chart-funnel-tooltip, [data-card-image-exclude], script, style, link';
const UNSUPPORTED = "iframe, object, embed, video, audio";

export function cardImageDimensions(width, height, scale = 2) {
  if (!Number.isFinite(scale) || scale < 1 || scale > 3) {
    throw new Error("Card image scale must be a number between 1 and 3.");
  }
  const dimensions = { width: Math.ceil(width * scale), height: Math.ceil(height * scale) };
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    throw new Error("This card has no visible image dimensions.");
  }
  if (dimensions.width > MAX_DIMENSION || dimensions.height > MAX_DIMENSION
    || dimensions.width * dimensions.height > MAX_PIXELS) {
    throw new Error("This card exceeds the image size limit. Reduce its size or export scale.");
  }
  return dimensions;
}

function visibleCard(element) {
  if (!element?.isConnected || !element.ownerDocument?.defaultView || element.nodeType !== 1) {
    throw new Error("This card is not mounted in the current app.");
  }
  const view = element.ownerDocument.defaultView;
  for (let ancestor = element; ancestor; ancestor = ancestor.parentElement) {
    const style = view.getComputedStyle(ancestor);
    if (ancestor.hidden || style.display === "none" || style.visibility === "hidden"
      || style.visibility === "collapse" || style.contentVisibility === "hidden" || Number(style.opacity) === 0) {
      throw new Error("This card is hidden in the current app view.");
    }
  }
  return element.getBoundingClientRect();
}

function included(node) {
  return node.nodeType !== 1 || !node.matches(OMIT);
}

function cardFragment(reference, card) {
  let id;
  try { id = decodeURIComponent(reference.slice(1)); } catch { /* Invalid fragment. */ }
  const target = id && card.ownerDocument.getElementById(id);
  if (!target || !card.contains(target) || target.closest(OMIT)) {
    throw new Error("Card images require SVG paint and clip definitions inside the captured card.");
  }
  return target;
}

function embeddedUrls(value, allowFragment = false, card) {
  for (const match of String(value).matchAll(/url\(\s*(["']?)(.*?)\1\s*\)/giu)) {
    if (/^data:/iu.test(match[2])) continue;
    if (allowFragment && match[2].startsWith("#")) {
      cardFragment(match[2], card);
      continue;
    }
    throw new Error("Card images require embedded assets; an external image or font cannot be captured reliably.");
  }
}

function validateStyle(style, card) {
  for (const property of style) {
    // The serializer embeds backgrounds and masks by fetching their URLs, even
    // for fragment references. SVG paint/clip references stay local to the card.
    embeddedUrls(style.getPropertyValue(property), !/background|mask/u.test(property), card);
  }
}

function embeddedFonts(document, families) {
  const fonts = [];
  function visit(rules) {
    for (const rule of rules) {
      if (rule.type === 5 && families.has(rule.style.fontFamily.replace(/["']/gu, "").trim())) {
        embeddedUrls(rule.style.getPropertyValue("src"));
        fonts.push(rule.cssText);
      } else if (rule.cssRules) visit(rule.cssRules);
      else if (rule.type === 3) throw new Error("Card images cannot capture imported font stylesheets reliably.");
    }
  }
  for (const sheet of document.styleSheets) {
    try { visit(sheet.cssRules); }
    catch (error) {
      if (error.name === "SecurityError") throw new Error("Card images cannot capture inaccessible font stylesheets reliably.");
      throw error;
    }
  }
  return fonts.join("\n");
}

async function prepareAssets(element) {
  const view = element.ownerDocument.defaultView;
  const nodes = [element, ...element.querySelectorAll("*")].filter((node) => !node.closest(OMIT));
  if (nodes.length > 5_000) throw new Error("This card contains too many elements to export as one image.");
  const families = new Set();
  const images = [];
  for (const node of nodes) {
    if (node.matches(UNSUPPORTED) || node.shadowRoot) {
      throw new Error("This card contains an embedded view that cannot be captured reliably.");
    }
    if (node.matches("canvas") && (!node.width || !node.height)) {
      throw new Error("A canvas in this card has not finished rendering.");
    }
    if (node.scrollLeft || node.scrollTop) {
      throw new Error("Scroll this card's contents to the beginning before exporting its image.");
    }
    const style = view.getComputedStyle(node);
    validateStyle(style, element);
    for (const family of style.fontFamily.split(",")) families.add(family.replace(/["']/gu, "").trim());
    for (const pseudo of ["::before", "::after"]) {
      const pseudoStyle = view.getComputedStyle(node, pseudo);
      if (pseudoStyle.content && !["none", "normal"].includes(pseudoStyle.content)) validateStyle(pseudoStyle, element);
    }
    if (node.matches("img")) {
      if (!/^data:/iu.test(node.currentSrc || node.src) || node.srcset) {
        throw new Error("Card images require embedded image assets without responsive external sources.");
      }
      images.push(node.decode().then(() => {
        if (!node.naturalWidth || !node.naturalHeight) throw new Error("A card image has not loaded.");
      }));
    } else if (node.namespaceURI === "http://www.w3.org/2000/svg" && node.localName !== "a") {
      const href = node.getAttribute("href") || node.getAttribute("xlink:href");
      if (href && !/^data:/iu.test(href)) {
        if (!href.startsWith("#") || node.localName === "image") {
          throw new Error("Card images cannot capture external SVG references reliably.");
        }
        const target = cardFragment(href, element);
        if (node.localName === "use" && !node.ownerSVGElement.contains(target)) {
          throw new Error("Card images require SVG definitions inside the captured chart.");
        }
      }
    }
  }
  await Promise.all(images);
  return embeddedFonts(element.ownerDocument, families);
}

function inlineSvgStyles(source, clone) {
  const style = source.ownerDocument.defaultView.getComputedStyle(source);
  for (const property of style) clone.style.setProperty(property, style.getPropertyValue(property), style.getPropertyPriority(property));
  for (let index = source.children.length - 1; index >= 0; index -= 1) {
    if (included(source.children[index])) inlineSvgStyles(source.children[index], clone.children[index]);
    else clone.children[index].remove();
  }
}

async function capture(element, scale, signal) {
  const document = element.ownerDocument;
  const view = document.defaultView;
  if (document.fonts) await document.fonts.ready;
  await new Promise((resolve) => view.requestAnimationFrame(() => view.requestAnimationFrame(resolve)));
  signal.throwIfAborted();
  const bounds = visibleCard(element);
  const dimensions = cardImageDimensions(bounds.width, bounds.height, scale);
  let changed = false;
  const observer = new view.MutationObserver(() => { changed = true; });
  observer.observe(element, { subtree: true, childList: true, characterData: true, attributes: true });
  const disconnect = () => observer.disconnect();
  signal.addEventListener("abort", disconnect, { once: true });
  try {
    const fontEmbedCSS = await prepareAssets(element);
    signal.throwIfAborted();
    const dataUrl = await toSvg(element, {
      width: bounds.width, height: bounds.height, fontEmbedCSS, filter: included,
      style: { margin: "0", transform: "none", boxSizing: "border-box" },
    });
    signal.throwIfAborted();
    const svg = new view.DOMParser().parseFromString(decodeURIComponent(dataUrl.split(",").slice(1).join(",")), "image/svg+xml");
    const foreignObject = svg.querySelector("foreignObject");
    if (!foreignObject) throw new Error("The card image could not be serialized.");
    // html-to-image deep-clones SVGs without their descendant computed styles.
    // Preserve CSS-driven chart marks, text, and the smoothed card background.
    const sourceSvgs = [...element.querySelectorAll("svg")]
      .filter((node) => !element.contains(node.parentElement.closest("svg")) && !node.closest(OMIT));
    const clonedSvgs = [...foreignObject.querySelectorAll("svg")]
      .filter((node) => !foreignObject.contains(node.parentElement.closest("svg")));
    if (sourceSvgs.length !== clonedSvgs.length) throw new Error("The card changed while its image was captured. Retry the export.");
    sourceSvgs.forEach((source, index) => {
      const clone = source.cloneNode(true);
      inlineSvgStyles(source, clone);
      clonedSvgs[index].replaceWith(clone);
    });
    const image = new view.Image();
    image.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(new view.XMLSerializer().serializeToString(svg))}`;
    await image.decode();
    signal.throwIfAborted();
    const after = visibleCard(element);
    if (changed || observer.takeRecords().length || after.width !== bounds.width || after.height !== bounds.height) {
      throw new Error("The card changed while its image was captured. Retry the export.");
    }
    const canvas = document.createElement("canvas");
    canvas.width = dimensions.width;
    canvas.height = dimensions.height;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("This browser cannot render card images.");
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const sample = document.createElement("canvas");
    sample.width = sample.height = 64;
    const sampleContext = sample.getContext("2d");
    if (!sampleContext) throw new Error("This browser cannot validate card images.");
    sampleContext.drawImage(canvas, 0, 0, 64, 64);
    const pixels = sampleContext.getImageData(0, 0, 64, 64).data;
    if (!pixels.some((channel, index) => channel !== pixels[index % 4])) {
      throw new Error("The card rendered an empty image; this browser may not support card image export.");
    }
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
    signal.throwIfAborted();
    if (!blob?.size || blob.type !== "image/png") throw new Error("The card image could not be encoded as PNG.");
    return { blob, ...dimensions };
  } finally {
    signal.removeEventListener("abort", disconnect);
    observer.disconnect();
  }
}

// Captures only this mounted card, with no clipboard, download, or navigation.
// Dimensions describe output pixels; the current layout and filters are retained.
export async function renderDataAppCardImage(element, { scale = 2 } = {}) {
  const bounds = visibleCard(element);
  cardImageDimensions(bounds.width, bounds.height, scale);
  const controller = new AbortController();
  let timer;
  try {
    return await Promise.race([
      capture(element, scale, controller.signal),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          const error = new Error("Card image export timed out waiting for fonts, images, or layout. Retry when the card has finished loading.");
          controller.abort(error);
          reject(error);
        }, CAPTURE_TIMEOUT_MS);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
