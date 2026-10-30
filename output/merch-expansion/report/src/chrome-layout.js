function finite(value, fallback = 0) {
  return Number.isFinite(value) ? value : fallback;
}

function pixels(value) {
  return `${Math.round(Math.max(0, value) * 1000) / 1000}px`;
}

export function dataAppChromeLayout({
  viewportWidth, paddingLeft = 0, paddingRight = 0,
}) {
  const width = Math.max(0, finite(viewportWidth));
  const defaultGutter = width <= 650 ? 16 : 32;
  const startGutter = Math.max(0, finite(paddingLeft)) || defaultGutter;
  const endGutter = Math.max(0, finite(paddingRight)) || defaultGutter;
  const maximumInset = Math.max(0, (width - Math.min(240, width)) / 2);

  return {
    "--data-app-safe-chrome-width": "100%",
    "--data-app-safe-chrome-margin": "0px",
    "--data-app-safe-chrome-inset-start": pixels(Math.min(startGutter, maximumInset)),
    "--data-app-safe-chrome-inset-end": pixels(Math.min(endGutter, maximumInset)),
  };
}


export function stickyFilterState({ scrollY, top, bottom, headerBottom }) {
  const stuck = scrollY > 0 && top <= headerBottom + 1 && bottom > headerBottom + 1;
  return { stuck };
}
