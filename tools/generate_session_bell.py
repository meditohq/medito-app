"""Generate Medito's original, deterministic meditation bell (no samples).
Run: python3 tools/generate_session_bell.py
"""
import math
import struct
import wave
from pathlib import Path

rate = 44100
seconds = 6
# An octave lower, with inharmonic partials and a gently beating fundamental.
partials = [(220, 1.0, 2.0), (220.65, .28, 2.1), (594, .24, 1.2),
            (1155, .09, .7), (1870, .025, .35)]
# Smoothly reach zero at 5.5 seconds, leaving half a second of true silence.
fade_start = 3.5
fade_end = 5.5
# A broad, smooth swell avoids a percussive strike at session boundaries.
attack_duration = .65
samples = []
for i in range(rate * seconds):
    t = i / rate
    attack_progress = min(1.0, t / attack_duration)
    attack = .5 * (1 - math.cos(math.pi * attack_progress))
    fade_progress = max(0.0, min(1.0, (t - fade_start) / (fade_end - fade_start)))
    fade = .5 * (1 + math.cos(math.pi * fade_progress))
    value = sum(a * math.exp(-t / decay) * math.sin(2 * math.pi * hz * t)
                for hz, a, decay in partials) * attack * fade
    samples.append(value)
scale = .65 * 32767 / max(abs(s) for s in samples)
path = Path(__file__).resolve().parents[1] / 'assets/audio/session_bell_v2.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(b''.join(struct.pack('<h', round(s * scale)) for s in samples))
print(path)
