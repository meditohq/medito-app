import React from "react";

import { Tooltip, TruncatedText } from "./ui.jsx";

function normalizeOption(option) {
  return typeof option === "object" && option !== null
    ? option
    : { value: option, label: option };
}

export function SegmentedControl({
  options = [],
  value,
  onChange,
  ariaLabel,
  selectionMode = "single",
  size = "compact",
  disabled = false,
  fullWidth = false,
  className = "",
}) {
  const multiple = selectionMode === "multiple";
  const selectedValues = multiple && Array.isArray(value) ? value : [];
  const tooltipBaseId = `data-segmented-tooltip-${React.useId().replaceAll(":", "")}`;

  return <div className={["data-segmented-control", className].filter(Boolean).join(" ")}
    role="group" aria-label={ariaLabel} data-size={size === "default" ? "default" : "compact"}
    data-selection-mode={multiple ? "multiple" : "single"}
    data-full-width={fullWidth || undefined} data-disabled={disabled || undefined}>
    {options.map((source, index) => {
      const option = normalizeOption(source);
      const tooltipId = option.tooltip ? `${tooltipBaseId}-${index}` : undefined;
      const selected = multiple
        ? selectedValues.some((selectedValue) => Object.is(selectedValue, option.value))
        : Object.is(option.value, value);
      return <button key={option.value} type="button" className="data-segmented-control-button"
        aria-pressed={selected} aria-label={option.ariaLabel}
        aria-describedby={tooltipId} title={option.tooltip ? undefined : option.title}
        disabled={disabled || option.disabled}
        onClick={() => onChange?.(multiple
          ? selected
            ? selectedValues.filter((selectedValue) => !Object.is(selectedValue, option.value))
            : [...selectedValues, option.value]
          : option.value)}>
        {typeof option.label === "string" || typeof option.label === "number"
          ? <TruncatedText className="data-segmented-control-label">{option.label}</TruncatedText> : option.label}
        {option.tooltip && <Tooltip id={tooltipId}
          className="data-segmented-control-tooltip">{option.tooltip}</Tooltip>}
      </button>;
    })}
  </div>;
}
