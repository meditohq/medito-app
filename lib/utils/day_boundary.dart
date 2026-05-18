/// Returns the user-perceived calendar day that contains [t], honouring
/// an optional [offset].
///
/// `offset` shifts when a new day begins relative to local midnight:
///   - `Duration.zero` (default) — day starts at 00:00 (legacy behaviour).
///   - `Duration(hours: 4)` — day starts at 04:00; a session at 02:00 still
///     counts toward the previous calendar day.
///   - `Duration(hours: -2)` — day starts at 22:00 the prior evening; a
///     session at 23:00 counts toward the next calendar day.
///
/// The returned value is always at local midnight (`hour=minute=second=ms=0`).
DateTime dayOf(DateTime t, [Duration offset = Duration.zero]) {
  final shifted = t.subtract(offset);
  return DateTime(shifted.year, shifted.month, shifted.day);
}
