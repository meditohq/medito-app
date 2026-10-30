import { useRef } from "react";

// Radix opens dropdown triggers on pointerdown. A touch that starts a scroll must
// remain a scroll; open only after a stationary finger is released.
export function useTouchReleaseTrigger(setOpen) {
  const touch = useRef(null);
  return {
    onPointerDownCapture(event) {
      if (event.pointerType !== "touch") return;
      touch.current = { id: event.pointerId, x: event.clientX, y: event.clientY, moved: false };
      // Radix toggles on pointerdown. Keep touch scrolling intact, and let
      // pointerup be the only toggle for this gesture.
      event.preventDefault();
      event.stopPropagation();
    },
    onPointerMove(event) {
      const start = touch.current;
      if (start?.id === event.pointerId && Math.hypot(event.clientX - start.x, event.clientY - start.y) > 8)
        start.moved = true;
    },
    onPointerCancel(event) {
      if (touch.current?.id === event.pointerId) touch.current = null;
    },
    onPointerUp(event) {
      const start = touch.current;
      if (start?.id !== event.pointerId) return;
      touch.current = null;
      if (!start.moved && !event.currentTarget.disabled) setOpen(current => !current);
    },
  };
}
