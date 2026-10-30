import React from "react";
import { SvgIcon } from "./SvgIcon.jsx";
import check from "./icons/dashboard-icon-check.svg";
import chevronDown from "./icons/dashboard-icon-chevronDown.svg";

// Explicit assets let small control consumers use the same icons without a Vite glob.
const icons = { check, chevronDown };
export function ControlIcon({ name, ...props }) {
  if (!icons[name]) throw new Error(`Unknown control icon: ${name}`);
  return <SvgIcon name={name} src={icons[name]} {...props} />;
}
