const white = [255, 255, 255, 1];
const ink = [23, 24, 26, 1];

function channel(value) {
  return Math.max(0, Math.min(255, Math.round(value)));
}

export function parseChromeColor(value) {
  if (typeof value !== "string") return undefined;
  const hex = value.trim().match(/^#([\da-f]{3}|[\da-f]{6})$/iu);
  if (hex) {
    const digits = hex[1].length === 3
      ? [...hex[1]].map((digit) => digit.repeat(2)).join("") : hex[1];
    return [0, 2, 4].map((index) => parseInt(digits.slice(index, index + 2), 16)).concat(1);
  }
  const rgb = value.trim().match(/^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:\s*[,/]\s*([\d.]+))?\s*\)$/iu);
  if (rgb) return [channel(Number(rgb[1])), channel(Number(rgb[2])), channel(Number(rgb[3])), Number(rgb[4] ?? 1)];
  const srgb = value.trim().match(/^color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*\/\s*([\d.]+))?\s*\)$/iu);
  if (srgb) return [1, 2, 3].map((index) => channel(Number(srgb[index]) * 255)).concat(Number(srgb[4] ?? 1));
  return undefined;
}

export function compositeChromeColor(foreground, background = white) {
  const alpha = Math.max(0, Math.min(1, foreground[3] ?? 1));
  return [0, 1, 2].map((index) => channel(foreground[index] * alpha + background[index] * (1 - alpha))).concat(1);
}

function mixColor(foreground, background, foregroundWeight) {
  return [0, 1, 2]
    .map((index) => channel(foreground[index] * foregroundWeight + background[index] * (1 - foregroundWeight)))
    .concat(1);
}

function luminance(color) {
  return color.slice(0, 3).map((channelValue) => {
    const scaled = channelValue / 255;
    return scaled <= .04045 ? scaled / 12.92 : ((scaled + .055) / 1.055) ** 2.4;
  }).reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
}

export function chromeContrastRatio(foreground, background) {
  const first = luminance(foreground);
  const second = luminance(background);
  return (Math.max(first, second) + .05) / (Math.min(first, second) + .05);
}

function mostReadable(background) {
  return chromeContrastRatio(white, background) >= chromeContrastRatio(ink, background) ? white : ink;
}

function cssColor(color) {
  return `rgb(${color[0]}, ${color[1]}, ${color[2]})`;
}

function verificationColor(preferred, surface, hoverSurface) {
  const target = mostReadable(surface);
  // The badge is a non-text control. Preserve its state color while meeting
  // 3:1 contrast on both the top bar and its hover background.
  for (let step = 0; step <= 20; step += 1) {
    const candidate = mixColor(preferred, target, 1 - step / 20);
    if ([surface, hoverSurface].every((background) => chromeContrastRatio(candidate, background) >= 3)) {
      return cssColor(candidate);
    }
  }
  return cssColor(target);
}

export function dataAppChromeColors({ background, underlay, foreground, secondary, positive }) {
  const base = parseChromeColor(underlay) ?? white;
  const surface = compositeChromeColor(parseChromeColor(background) ?? base, base);
  const requested = parseChromeColor(foreground);
  const text = requested && chromeContrastRatio(requested, surface) >= 4.5
    ? requested : mostReadable(surface);
  const requestedSecondary = parseChromeColor(secondary);
  let muted = requestedSecondary && chromeContrastRatio(requestedSecondary, surface) >= 4.5
    ? requestedSecondary : mixColor(text, surface, .78);
  if (chromeContrastRatio(muted, surface) < 4.5) muted = text;
  const requestedPositive = parseChromeColor(positive);
  const compositePositive = requestedPositive && compositeChromeColor(requestedPositive, surface);
  const readablePositive = compositePositive && chromeContrastRatio(compositePositive, surface) >= 4.5
    ? compositePositive : text;
  const track = mixColor(text, surface, .08);
  const indicator = luminance(text) > .5 ? text : white;
  const indicatorText = mostReadable(indicator);
  const publishText = mostReadable(text);

  return {
    "--data-app-safe-chrome-foreground": cssColor(text),
    "--data-app-safe-chrome-secondary": cssColor(muted),
    "--data-app-safe-chrome-positive": cssColor(readablePositive),
    "--data-app-safe-chrome-verified": verificationColor([0, 100, 45, 1], surface, track),
    "--data-app-safe-chrome-unverified": verificationColor([160, 160, 160, 1], surface, track),
    "--data-app-safe-chrome-track": cssColor(track),
    "--data-app-safe-chrome-indicator": cssColor(indicator),
    "--data-app-safe-chrome-indicator-text": cssColor(indicatorText),
    "--data-app-safe-chrome-publish-background": cssColor(text),
    "--data-app-safe-chrome-publish-text": cssColor(publishText),
  };
}
