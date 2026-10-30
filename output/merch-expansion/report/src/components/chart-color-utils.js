const semanticColorLabels = new Map([
  ["var(--secondary)", "Secondary"],
  ["var(--positive)", "Positive"],
  ["var(--negative)", "Negative"],
]);

/** Identify the stored color role without guessing a hue from theme-dependent CSS. */
export function chartColorIdentity(color, { automatic = false } = {}) {
  if (automatic) return { label: "Automatic", explicitColor: null, customHex: null };
  const explicitColor = typeof color === "string" ? color : null;
  const customHex = /^#[\da-f]{6}$/iu.test(explicitColor ?? "") ? explicitColor.toUpperCase() : null;
  const slot = /^var\(--chart-([1-8])\)$/u.exec(explicitColor ?? "");
  const blended = /^color-mix\(in srgb, var\(--chart-([1-8])\) 42%, var\(--surface\)\)$/u.exec(explicitColor ?? "");
  const label = customHex
    ? `Custom ${customHex}`
    : slot
      ? `Theme color ${slot[1]}`
      : blended
        ? `Theme color ${blended[1]}, blended`
        : semanticColorLabels.get(explicitColor) ?? "Custom color";
  return { label, explicitColor, customHex };
}

const paletteTokens = Array.from({ length: 7 }, (_, index) => `var(--chart-${index + 1})`);
export const chartColorOptions = [
  ...paletteTokens,
  "var(--secondary)",
  ...paletteTokens.map((token) => `color-mix(in srgb, ${token} 42%, var(--surface))`),
].map((token) => ({ label: chartColorIdentity(token).label, token }));

export function hexToHsv(hex) {
  const [r, g, b] = [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255);
  const max = Math.max(r, g, b),
    min = Math.min(r, g, b),
    delta = max - min;
  const hue = !delta ? 0 : max === r ? ((g - b) / delta) % 6 : max === g ? (b - r) / delta + 2 : (r - g) / delta + 4;
  return { hue: (hue * 60 + 360) % 360, saturation: max ? (delta / max) * 100 : 0, value: max * 100 };
}

export function hsvToHex({ hue, saturation, value }) {
  const v = value / 100,
    c = (v * saturation) / 100;
  const h = (((hue % 360) + 360) % 360) / 60;
  const x = c * (1 - Math.abs((h % 2) - 1)),
    m = v - c;
  const rgb =
    h < 1 ? [c, x, 0] : h < 2 ? [x, c, 0] : h < 3 ? [0, c, x] : h < 4 ? [0, x, c] : h < 5 ? [x, 0, c] : [c, 0, x];
  return `#${rgb
    .map((channel) =>
      Math.round((channel + m) * 255)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("")}`;
}

export function colorNameFromHex(hex) {
  if (!/^#[\da-f]{6}$/iu.test(hex ?? "")) return "Theme color";
  const { hue, saturation, value } = hexToHsv(hex);
  if (value <= 12) return "Black";
  if (saturation < 12) return value >= 96 ? "White" : "Gray";
  if (hue < 15 || hue >= 345) return "Red";
  if (hue < 42) return "Orange";
  if (hue < 68) return "Yellow";
  if (hue < 100) return "Lime";
  if (hue < 165) return "Green";
  if (hue < 180) return "Teal";
  if (hue < 205) return "Cyan";
  if (hue < 250) return "Blue";
  if (hue < 290) return "Purple";
  if (hue < 325) return "Magenta";
  return "Pink";
}

export function resolvedColorHex(color, parent) {
  if (/^#[\da-f]{6}$/iu.test(color ?? "")) return color;
  const ownerDocument = parent?.ownerDocument ?? document;
  const ownerWindow = ownerDocument.defaultView ?? window;
  const probe = ownerDocument.createElement("span");
  probe.style.color = color || "var(--chart-1)";
  parent.append(probe);
  const resolved = ownerWindow.getComputedStyle(probe).color;
  probe.remove();
  const canvas = ownerDocument.createElement("canvas");
  canvas.width = canvas.height = 1;
  const context = canvas.getContext("2d");
  context.fillStyle = resolved;
  context.fillRect(0, 0, 1, 1);
  return `#${[...context.getImageData(0, 0, 1, 1).data]
    .slice(0, 3)
    .map((channel) => channel.toString(16).padStart(2, "0"))
    .join("")}`;
}

export function resolvedColorName(color, parent) {
  return colorNameFromHex(resolvedColorHex(color, parent));
}

// Portals leave the authored chart's CSS scope. Carry only tokens referenced by
// its spec, not page layout/typography or resolved colors in the persisted spec.
export function chartColorContext(spec, style) {
  if (!style) return {};
  const tokens = [...JSON.stringify(spec ?? {}).matchAll(/var\(\s*(--[\w-]+)/gu)].map(match => match[1]);
  return Object.fromEntries([...new Set(tokens)].flatMap(token => {
    const value = style.getPropertyValue(token).trim();
    return value ? [[token, value]] : [];
  }));
}
