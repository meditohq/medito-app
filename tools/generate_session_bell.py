"""Generate Medito's original, deterministic singing-bowl bell (no samples).
Run: python3 tools/generate_session_bell.py

The file must stay exactly 6 seconds long: the end-of-session bell is
scheduled 6 seconds before the track ends (see session_bell_schedule.dart).
"""
import math
import struct
import wave
from pathlib import Path

rate = 44100
seconds = 6
fundamental = 256.0

# Modes of a struck metal bowl. The overtones sit at the inharmonic ratios of
# a bowl's flexural modes (roughly 1 : 2.8 : 5.3 : 8.4 : 12), which is what
# makes it read as a bowl rather than a plain tone.
# (ratio, level, decay seconds, beat Hz, attack seconds)
modes = [
    (1.00, 1.000, 3.20, 0.50, .050),
    (2.82, 0.500, 2.40, 0.95, .022),
    (5.31, 0.200, 1.50, 1.70, .012),
    (8.43, 0.065, 0.90, 2.60, .008),
    (12.05, 0.022, 0.50, 3.60, .006),
]
# No bowl is perfectly round, so every mode rings as two close frequencies.
# Their slow beating is the "singing" shimmer; a weaker twin keeps it a gentle
# wobble instead of a full tremolo.
twin_level = .6

# The file has to be silent by its end, but a short fade there sounds like
# the bowl was cut off. So the fade is spread over most of the file: it bends
# the natural ring-out gradually and the bell is already quiet (about -40 dB)
# a second before it reaches zero at 5.75 seconds.
fade_start = 1.5
fade_end = 5.75


def mode_value(t, ratio, level, decay, beat, attack):
    hz = fundamental * ratio
    # A soft-mallet strike: low modes bloom a little later than the high ones,
    # so the onset is a rounded "bong" with no click.
    progress = min(1.0, t / attack)
    onset = .5 * (1 - math.cos(math.pi * progress))
    tone = (math.sin(2 * math.pi * (hz - beat / 2) * t)
            + twin_level * math.sin(2 * math.pi * (hz + beat / 2) * t))
    return level * onset * math.exp(-t / decay) * tone


samples = []
for i in range(rate * seconds):
    t = i / rate
    fade_progress = max(0.0, min(1.0, (t - fade_start) / (fade_end - fade_start)))
    fade = .5 * (1 + math.cos(math.pi * fade_progress))
    samples.append(sum(mode_value(t, *mode) for mode in modes) * fade)
scale = .8 * 32767 / max(abs(s) for s in samples)
path = Path(__file__).resolve().parents[1] / 'assets/audio/session_bell_v2.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(b''.join(struct.pack('<h', round(s * scale)) for s in samples))
print(path)
