import React from "react";


export function Switch({
  label,
  checked = false,
  onChange,
  disabled = false,
  fullWidth = false,
  size = "default",
  className = "",
}) {
  return <button type="button" className={["data-switch", className].filter(Boolean).join(" ")}
    role="switch" aria-label={label} aria-checked={checked} disabled={disabled}
    data-full-width={fullWidth || undefined} data-size={size === "compact" ? size : undefined}
    onClick={() => onChange?.(!checked)}>
    <span className="data-switch-label">{label}</span>
    <span className="data-switch-track" aria-hidden="true" />
  </button>;
}
