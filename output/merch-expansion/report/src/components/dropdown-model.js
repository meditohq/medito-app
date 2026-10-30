// Both dropdown presentations use the same labels and controlled selection rules.
export function dropdownModel({ value, multiple = false, allLabel = "All", formatChoice } = {}) {
  const selectedValues = new Set((multiple
    ? Array.isArray(value) ? value : [value]
    : []).filter(choice => choice != null && choice !== "" && choice !== "all"));
  const display = choice => choice === "all" ? allLabel
    : choice == null || choice === "" ? "No series" : formatChoice?.(choice) ?? String(choice);
  const displayedValue = multiple
    ? selectedValues.size === 0 ? allLabel
      : selectedValues.size === 1 ? display([...selectedValues][0]) : `${selectedValues.size} selected`
    : display(value);
  const isSelected = choice => multiple
    ? choice === "all" ? selectedValues.size === 0 : selectedValues.has(choice)
    : choice === value;
  const select = choice => {
    if (!multiple) return choice;
    if (choice === "all") return [];
    const next = new Set(selectedValues);
    if (next.has(choice)) next.delete(choice);
    else next.add(choice);
    return [...next];
  };
  return { display, displayedValue, isSelected, select };
}
