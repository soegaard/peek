import React from "react";

export function Button({ kind, children }) {
  return <button className={kind}>{children}</button>;
}
