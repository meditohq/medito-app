import React, { createContext, useContext, useMemo } from "react";

const CustomBlockContext = createContext(null);

export function useCustomBlock() {
  const context = useContext(CustomBlockContext);
  if (!context) throw new Error("Custom blocks must render inside CustomBlockHost.");
  return context;
}

class CustomBlockBoundary extends React.Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    return this.state.failed
      ? <div className="custom-block-fallback" role="status">Custom visualization unavailable.</div>
      : this.props.children;
  }
}

export function CustomBlockHost({ blockId, title, data, filters, accessibilitySummary, openSource, children }) {
  const context = useMemo(() => ({
    blockId, title, data, filters, accessibilitySummary, openSource,
  }), [blockId, title, data, filters, accessibilitySummary, openSource]);

  return (
    <CustomBlockBoundary>
      <CustomBlockContext.Provider value={context}>
        <div className="custom-block" data-custom-block-id={blockId}>{children}</div>
      </CustomBlockContext.Provider>
    </CustomBlockBoundary>
  );
}
