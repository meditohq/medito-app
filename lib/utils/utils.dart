String blankIfNull(String s) {
  if (s == null)
    return "";
  else
    return s;
}

formatDuration(Duration d) {
  var s = d.toString().split('.').first;
  if (s.startsWith('0.0')) {
    s = s.replaceFirst('0:0', '');
  }
  return s;
}
