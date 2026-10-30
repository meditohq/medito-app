import React, { useState } from "react";
import * as Dropdown from "@radix-ui/react-dropdown-menu";
import { ControlIcon as Icon } from "./ControlIcon.jsx";
import { dropdownModel } from "./dropdown-model.js";
import { useTouchReleaseTrigger } from "./touch-release-trigger.js";

export function Select({
  label,
  describedBy,
  value,
  choices,
  onChange,
  showLabel = false,
  allLabel = "All",
  formatChoice,
  renderChoice,
  triggerClassName = "filter-trigger",
  contentClassName = "",
  align = "start",
  modal = true,
  disabled = false,
  scrollToSelected = false,
  groups,
  multiple = false,
  portalContainer,
}) {
  const { display, displayedValue, isSelected, select } = dropdownModel({ value, multiple, allLabel, formatChoice });
  const [open, setOpen] = useState(false);
  const release = useTouchReleaseTrigger(setOpen);
  const optionGroups = groups ?? [{ choices }];
  const native = !multiple && (
    <span className={`${triggerClassName} select-trigger native-filter-shell`}>
      {showLabel && <span className="filter-label" aria-hidden="true">{label}</span>}
      <span className="select-value" aria-hidden="true">{renderChoice && !multiple ? renderChoice(value) : displayedValue}</span>
      <Icon name="chevronDown" className="chevron" />
      <select className="native-filter-control" aria-label={label} aria-describedby={describedBy}
        value={value ?? optionGroups[0]?.choices[0] ?? ""} disabled={disabled}
        onChange={event => onChange?.(event.currentTarget.value)}
        onPointerDown={event => { event.currentTarget.dataset.pointerFocus = "true"; }}
        onBlur={event => { delete event.currentTarget.dataset.pointerFocus; }}
        onKeyDown={event => { delete event.currentTarget.dataset.pointerFocus; if (event.key === "Escape") event.stopPropagation(); }}>
        {optionGroups.map((group, index) => group.label
          ? <optgroup key={group.label} label={group.label}>{group.choices.map(choice =>
            <option key={choice} value={choice}>{display(choice)}</option>)}</optgroup>
          : <React.Fragment key={index}>{group.choices.map(choice =>
            <option key={choice} value={choice}>{display(choice)}</option>)}</React.Fragment>)}
      </select>
    </span>
  );

  return (
    <>
    {native}
    <span className={multiple ? "custom-select-host" : "custom-select-host has-native-picker"}>
    <Dropdown.Root modal={modal} open={open} onOpenChange={setOpen}>
      <Dropdown.Trigger className={`${triggerClassName} select-trigger`} aria-label={label} aria-describedby={describedBy} disabled={disabled}
        {...release}
        onPointerEnter={event => {
          const valueLabel = event.currentTarget.querySelector(".select-value");
          event.currentTarget.title = valueLabel?.scrollWidth > valueLabel?.clientWidth ? valueLabel.textContent : "";
        }}>
        {showLabel && <span className="filter-label">{label}</span>}
        <span className="select-value">{renderChoice && !multiple ? renderChoice(value) : displayedValue}</span>
        <Icon name="chevronDown" className="chevron" />
      </Dropdown.Trigger>
      <Dropdown.Portal container={portalContainer}>
        <Dropdown.Content
          align={align}
          className={["popover", "select-content", contentClassName].filter(Boolean).join(" ")}
          collisionPadding={12}
          sideOffset={7}
          onOpenAutoFocus={(event) => {
            if (!scrollToSelected) return;
            const content = event.currentTarget;
            requestAnimationFrame(() =>
              content.querySelector('[data-state="checked"]')?.scrollIntoView({ block: "center" }),
            );
          }}
        >
          {multiple ? optionGroups.map((group, index) => (
            <React.Fragment key={group.label ?? index}>
              {group.label && (
                <Dropdown.Label className="menu-group-label select-group-label">{group.label}</Dropdown.Label>
              )}
              {group.choices.map((choice) => {
                const checked = isSelected(choice);
                return <Dropdown.CheckboxItem className="menu-item" key={choice || "none"}
                  checked={checked} onCheckedChange={() => onChange?.(select(choice))}
                  onSelect={(event) => event.preventDefault()}>
                  <span className="menu-item-label">{renderChoice ? renderChoice(choice) : display(choice)}</span>
                  <Dropdown.ItemIndicator className="menu-check"><Icon name="check" /></Dropdown.ItemIndicator>
                </Dropdown.CheckboxItem>;
              })}
            </React.Fragment>
          )) : <Dropdown.RadioGroup value={value} onValueChange={onChange}>
            {optionGroups.map((group, index) => (
              <React.Fragment key={group.label ?? index}>
                {group.label && (
                  <Dropdown.Label className="menu-group-label select-group-label">{group.label}</Dropdown.Label>
                )}
                {group.choices.map((choice) => (
                  <Dropdown.RadioItem className="menu-item" key={choice || "none"} value={choice}>
                    <span className="menu-item-label">{renderChoice ? renderChoice(choice) : display(choice)}</span>
                    <Dropdown.ItemIndicator className="menu-check">
                      <Icon name="check" />
                    </Dropdown.ItemIndicator>
                  </Dropdown.RadioItem>
                ))}
              </React.Fragment>
            ))}
          </Dropdown.RadioGroup>}
        </Dropdown.Content>
      </Dropdown.Portal>
    </Dropdown.Root>
    </span>
    </>
  );
}
