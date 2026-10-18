#!/usr/bin/env python3
"""Deterministic original wooden four-note completion cue; no sampled system audio."""
from pathlib import Path
import math, struct, wave
RATE = 44100
DURATION = 1.12
NOTES = [(0.00, 523.251), (0.18, 659.255), (0.36, 783.991), (0.62, 1046.502)]
samples = []
for frame in range(round(RATE * DURATION)):
    t = frame / RATE
    value = 0.0
    for onset, pitch in NOTES:
        age = t - onset
        if 0 <= age < 0.50:
            attack = min(1.0, age / 0.005)
            release = min(1.0, (0.50 - age) / 0.06)
            body = math.sin(2 * math.pi * pitch * age) * math.exp(-age * 12)
            wood = 0.20 * math.sin(2 * math.pi * pitch * 2.76 * age) * math.exp(-age * 28)
            overtone = 0.08 * math.sin(2 * math.pi * pitch * 5.4 * age) * math.exp(-age * 44)
            value += (body + wood + overtone) * attack * release
    samples.append(value)
peak = max(abs(s) for s in samples)
output = Path(__file__).resolve().parent / 'assets' / 'completion-marimba.wav'
output.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(output), 'wb') as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(RATE)
    audio.writeframes(b''.join(struct.pack('<h', round(s / peak * 0.32 * 32767)) for s in samples))
print('Generated original completion-marimba.wav (1.12s, 44.1kHz, mono PCM16)')
