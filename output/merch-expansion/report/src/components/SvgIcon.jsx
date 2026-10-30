import React from "react";

/** Shared rendering for bundled SVG masks, independent of the asset loader. */
export function SvgIcon({ name, src, size = 16, className = "" }) {
  return <span
    className={`dashboard-icon${name === "theme" ? " theme-palette-icon" : ""} ${className}`.trim()}
    aria-hidden="true"
    data-dashboard-icon={name}
    style={{ width: size, height: size, "--dashboard-icon-mask": `url(${JSON.stringify(src)})` }}
  />;
}
