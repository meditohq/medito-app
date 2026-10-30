import React from "react";

export function EditableText({ as: Element = "p", children, ...props }) {
  return <Element {...props} data-editable-narrative>{children}</Element>;
}
