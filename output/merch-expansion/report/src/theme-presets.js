export const dataAppThemeTokens = [
  "background", "surface", "surface-raised", "muted", "control", "control-hover", "text",
  "secondary", "border", "border-strong", "accent", "positive", "negative",
  ...Array.from({ length: 8 }, (_, index) => `chart-${index + 1}`),
  "card-radius", "control-radius", "mark-radius", "card-shadow", "shadow", "font-sans",
];

const dataAppThemeTokenIndexes = new Map(
  dataAppThemeTokens.map((token, index) => [token, index]),
);

export function dataAppThemeToken(palette, token, fallback) {
  const index = dataAppThemeTokenIndexes.get(token);
  return index === undefined ? fallback : palette?.[index] ?? fallback;
}

export const dataAppThemes = [
  { id: "original", label: "Original theme" },
  { id: "codex-classic", label: "Classic", tokens: [
    "#fff", "#fcfcfc", "#fff", "#f7f7f7", "#fff", "#f2f2f2", "#1a1c1f", "#767676",
    "#ededed", "#dfdfdf", "#339cff", "#00a240", "#e02e2a", "#0285ff", "#924ff7",
    "#04b84c", "#fb6a22", "#ff66ad", "#ffc300", "#fa423e", "#8f8f8f", "16px", "12px", "8",
    "0 4px 12px rgb(0 0 0 / 1%)", "0 8px 16px -4px rgb(0 0 0 / 12%)",
    '-apple-system-body, ui-sans-serif, -apple-system, system-ui, "Segoe UI", Helvetica, "Apple Color Emoji", Arial, sans-serif, "Segoe UI Emoji", "Segoe UI Symbol"',
  ], darkTokens: [
    "#181818", "#212121", "#282828", "#282828", "#212121", "#303030", "#fff", "#afafaf",
    "#303030", "#414141", "#99ceff", "#40c977", "#ff6764", "#66b5ff", "#ad7bf9",
    "#40c977", "#ff8549", "#ff8cc1", "#ffd240", "#ff6764", "#afafaf", "16px", "12px", "8",
    "0 1px 2px -1px rgb(0 0 0 / 8%)", "0 8px 16px -4px rgb(0 0 0 / 12%)",
    '-apple-system-body, ui-sans-serif, -apple-system, system-ui, "Segoe UI", Helvetica, "Apple Color Emoji", Arial, sans-serif, "Segoe UI Emoji", "Segoe UI Symbol"',
  ] },
  { id: "default", label: "Neutral", tokens: [
    "#f7f7f4", "#fff", "#fff", "#f5f5f5", "#fff", "#f6f6f6", "#1c1c1c", "#787878",
    "#e8e8e8", "#cfcfcf", "#0285ff", "#167642", "#c83737", "#0285ff", "#924ff7",
    "#04b84c", "#fb6a22", "#ff66ad", "#ffc300", "#fa423e", "#8f8f8f", "16px", "10px", "8",
    "0 1px 2px rgb(20 20 20 / 3%)", "0 8px 28px rgb(30 30 30 / 11%)",
    'Georgia, "Times New Roman", serif',
  ], darkTokens: [
    "#171717", "#202020", "#242424", "#2b2b2b", "#292929", "#333", "#f4f4f4", "#a8a8a8",
    "#383838", "#555", "#5aabff", "#78d69a", "#ff9995", "#5aabff", "#aa7bff",
    "#5bd984", "#ff9a64", "#ff8cc2", "#ffcf48", "#ff7774", "#afafaf", "16px", "10px", "8",
    "0 1px 2px rgb(0 0 0 / 20%)", "0 8px 28px rgb(0 0 0 / 36%)",
    'Georgia, "Times New Roman", serif',
  ] },
  { id: "dark-pixel", label: "Dark pixel", darkOnly: true, tokens: [
    "#121315", "#181c18", "#1d221c", "#26321d", "#1b211a", "#26321d", "#e8f0da", "#9aa58f",
    "#3f5138", "#657d59", "#b6ff3b", "#b6ff3b", "#ff5f5f", "#b6ff3b", "#ff4fd8", "#00e6ff",
    "#0aa34f", "#ffce3a", "#ff5f5f", "#9a75ff", "#e8f0da", "0", "0", "0", "4px 4px 0 #000",
    "4px 4px 0 #000", '"Courier New", ui-monospace, monospace',
  ] },
  { id: "scientific-blue", label: "Scientific blue", tokens: [
    "#f7faff", "#fff", "#fff", "#edf4ff", "#fff", "#edf4ff", "#10233f", "#60738d", "#cedcf0",
    "#9db5d5", "#1769e0", "#147a58", "#ba3d4f", "#1769e0", "#05a6c8", "#6b59d3", "#14845f",
    "#d16b2f", "#b84b9b", "#7a8da7", "#78b8ff", "8px", "6px", "2", "0 1px 2px rgb(35 75 125 / 5%)",
    "0 8px 24px rgb(35 75 125 / 10%)", "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
  ], darkTokens: [
    "#101722", "#172131", "#1c293b", "#202f45", "#1c293b", "#263852", "#edf5ff", "#a7bad2",
    "#344862", "#527096", "#70aaff", "#65d6aa", "#ff97a4", "#70aaff", "#48cee2",
    "#a298ff", "#60c9a1", "#f3a26d", "#e984c7", "#a3b7cf", "#78b8ff", "8px", "6px", "2",
    "0 1px 2px rgb(0 0 0 / 18%)", "0 8px 24px rgb(0 0 0 / 28%)",
    "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
  ] },
  { id: "sticker-pop", label: "Sticker pop", tokens: [
    "#fff8fc", "#fff", "#fff", "#fff0f8", "#fff", "#fff0f8", "#261526", "#856f80", "#f2b9da",
    "#df7fba", "#7450ff", "#14824c", "#d43764", "#ff5ea8", "#7450ff", "#00a9c7", "#e47d00",
    "#24a963", "#ee5636", "#c28b00", "#2e76ff", "24px", "16px", "12", "0 4px 0 #f2b9da",
    "0 4px 0 #f2b9da", 'ui-rounded, "SF Pro Rounded", system-ui, sans-serif',
  ], darkTokens: [
    "#20151d", "#2b1d28", "#332131", "#382438", "#2b1d28", "#40263b", "#fff0f8", "#d4aec7",
    "#6c3d60", "#995579", "#a592ff", "#7cdda4", "#ff8cab", "#ff83bb", "#a592ff", "#58d0e1",
    "#ffac57", "#70d9a1", "#ff8a70", "#efc85d", "#78a8ff", "24px", "16px", "12",
    "0 4px 0 #6c3d60", "0 4px 0 #6c3d60", 'ui-rounded, "SF Pro Rounded", system-ui, sans-serif',
  ] },
];

export function dataAppThemePalette(theme, scheme = "light") {
  if (!theme?.tokens) return null;
  return scheme === "dark" && !theme.darkOnly ? theme.darkTokens ?? theme.tokens : theme.tokens;
}

export function syncDataAppBrowserThemeColor() {
  const meta = document.querySelector('meta[name="theme-color"]');
  if (!meta) return;
  // Safari paints the status bar and overscroll area from this color. The page
  // background is opaque even when the sticky app bar uses a translucent fill.
  meta.content = getComputedStyle(document.body).backgroundColor;
}

export function applyDataAppTheme(themeId, preferredScheme) {
  const theme = dataAppThemes.find(({ id }) => id === themeId);
  if (!theme) throw new Error(`Unknown Data app theme: ${themeId}`);
  const root = document.documentElement;
  const scheme = preferredScheme ?? root.dataset.colorScheme ?? "light";
  const tokens = dataAppThemePalette(theme, scheme);
  dataAppThemeTokens.forEach((token, index) => {
    if (tokens) root.style.setProperty(`--${token}`, tokens[index]);
    else root.style.removeProperty(`--${token}`);
  });
  const authoredScheme = theme.id === "original"
    ? getComputedStyle(root).getPropertyValue("--fixed-theme-scheme").trim()
    : "";
  root.style.colorScheme = theme.darkOnly ? "dark" : authoredScheme || scheme;
  root.dataset.appTheme = theme.id;
  syncDataAppBrowserThemeColor();
  return theme;
}
