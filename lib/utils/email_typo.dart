import 'dart:math' as math;

/// Suggests a fix for a mistyped email domain ("gmil.com", "gmail.con"), or
/// null when the address looks fine. Advisory only: callers show it as a
/// tappable hint and never block on it, since a false positive must cost the
/// user nothing more than ignoring the hint.
String? suggestEmailCorrection(String input) {
  final email = input.trim();
  final at = email.lastIndexOf('@');
  if (at <= 0 || at == email.length - 1) return null;
  final local = email.substring(0, at);
  final domain = email.substring(at + 1).toLowerCase();
  // Wait for a dot so half-typed domains ("gm") don't flash suggestions.
  if (!domain.contains('.') || domain.endsWith('.')) return null;
  if (_knownDomains.contains(domain)) return null;

  final tldFixed = _fixTld(domain);
  if (_knownDomains.contains(tldFixed)) return '$local@$tldFixed';

  final maxDistance = tldFixed.length >= 9 ? 2 : 1;
  String? best;
  var bestDistance = maxDistance + 1;
  for (final known in _knownDomains) {
    // Cheap length prefilter before the O(n*m) distance.
    if ((known.length - tldFixed.length).abs() > maxDistance) continue;
    final d = _osaDistance(tldFixed, known);
    if (d < bestDistance) {
      best = known;
      bestDistance = d;
    }
  }
  if (best != null) return '$local@$best';
  if (tldFixed != domain) return '$local@$tldFixed';
  return null;
}

/// Splits [suggestion] into runs, flagging the domain labels that differ from
/// what was [typed] ("gmil.con" -> "gmail" and "com") so the hint can
/// emphasise the fix. Whole labels, not single letters: a lone bold "a" in
/// "gmail" is hard to spot. If the label count changed, the whole domain is
/// flagged.
List<({String text, bool changed})> emailCorrectionSegments(
  String typed,
  String suggestion,
) {
  final at = suggestion.lastIndexOf('@');
  final typedAt = typed.trim().lastIndexOf('@');
  final prefix = suggestion.substring(0, at + 1);
  final labels = suggestion.substring(at + 1).split('.');
  final typedLabels = typedAt < 0
      ? const <String>[]
      : typed.trim().substring(typedAt + 1).toLowerCase().split('.');
  if (labels.length != typedLabels.length) {
    return [
      (text: prefix, changed: false),
      (text: labels.join('.'), changed: true),
    ];
  }

  final segments = <({String text, bool changed})>[];
  void add(String text, bool changed) {
    if (segments.isNotEmpty && segments.last.changed == changed) {
      segments.last = (text: segments.last.text + text, changed: changed);
    } else {
      segments.add((text: text, changed: changed));
    }
  }

  add(prefix, false);
  for (var i = 0; i < labels.length; i++) {
    if (i > 0) add('.', false);
    add(labels[i], labels[i] != typedLabels[i]);
  }
  return segments;
}

/// Swaps a mistyped final label for the TLD it almost certainly meant. Only
/// labels that are not real TLDs are listed: ".co", ".cm" and ".om" are real
/// countries, so they are fixed only via a known-domain match above.
String _fixTld(String domain) {
  final dot = domain.lastIndexOf('.');
  final tld = domain.substring(dot + 1);
  final fixed = _tldTypos[tld];
  return fixed == null ? domain : '${domain.substring(0, dot + 1)}$fixed';
}

const _tldTypos = {
  'con': 'com',
  'cmo': 'com',
  'ocm': 'com',
  'comm': 'com',
  'coom': 'com',
  'conm': 'com',
  'cpm': 'com',
  'vom': 'com',
  'xom': 'com',
  'c0m': 'com',
  'cim': 'com',
  'nte': 'net',
  'nett': 'net',
  'ogr': 'org',
  'orgg': 'org',
};

/// Popular providers, most popular first so ties resolve to the likelier one.
/// Legit near-neighbours ("mail.com", "ymail.com", "gmx.net") are listed too
/// so they match exactly instead of being "corrected".
const _knownDomains = {
  'gmail.com',
  'yahoo.com',
  'hotmail.com',
  'outlook.com',
  'icloud.com',
  'live.com',
  'aol.com',
  'msn.com',
  'me.com',
  'mac.com',
  'googlemail.com',
  'protonmail.com',
  'proton.me',
  'pm.me',
  'mail.com',
  'ymail.com',
  'rocketmail.com',
  'gmx.com',
  'gmx.net',
  'gmx.de',
  'web.de',
  'yandex.ru',
  'mail.ru',
  'qq.com',
  '163.com',
  'comcast.net',
  'verizon.net',
  'att.net',
  'sbcglobal.net',
  'btinternet.com',
  'yahoo.co.uk',
  'hotmail.co.uk',
  'outlook.co.uk',
  'live.co.uk',
  'yahoo.es',
  'hotmail.es',
  'outlook.es',
  'yahoo.fr',
  'hotmail.fr',
  'orange.fr',
  'free.fr',
  'hotmail.it',
  'libero.it',
  'hotmail.de',
  'ziggo.nl',
  'kpnmail.nl',
  'hotmail.nl',
  'live.nl',
  'yahoo.com.br',
  'hotmail.com.br',
  'bol.com.br',
  'yahoo.com.mx',
  'hotmail.com.ar',
  // Country variants that sit within two edits of a .com above.
  'email.com',
  'yahoo.ca',
  'hotmail.ca',
  'live.ca',
  'yahoo.com.au',
  'hotmail.com.au',
  'yahoo.co.in',
  'yahoo.de',
  'yahoo.it',
  'outlook.de',
  'outlook.fr',
  'hotmail.be',
  'hotmail.se',
  'live.se',
  't-online.de',
};

/// Levenshtein distance that also counts an adjacent swap ("gmial") as one.
int _osaDistance(String a, String b) {
  final rows = List.generate(
    a.length + 1,
    (i) => List<int>.filled(b.length + 1, 0)..[0] = i,
  );
  for (var j = 0; j <= b.length; j++) {
    rows[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var d = math.min(
        math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1),
        rows[i - 1][j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d = math.min(d, rows[i - 2][j - 2] + 1);
      }
      rows[i][j] = d;
    }
  }
  return rows[a.length][b.length];
}
