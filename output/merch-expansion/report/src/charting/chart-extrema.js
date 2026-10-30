/** Preserve Math.min/max semantics without expanding reviewed values into call arguments. */
export function minimumValue(values, initial = Infinity) {
  let result = initial;
  for (const value of values) result = Math.min(result, value);
  return result;
}

export function maximumValue(values, initial = -Infinity) {
  let result = initial;
  for (const value of values) result = Math.max(result, value);
  return result;
}
