#!/usr/bin/env python3
"""Synthesises FrancNumero's four sound effects as small 16-bit mono WAV files.

    python3 Tools/make_sounds.py

Writes into FrancNumero/Sounds/. The files are synthesised from filtered noise and sine waves, so
there is nothing to license. They were designed without being able to listen, so tune by ear:
every sound has a few obvious knobs in its function (band edges, stroke timing, decay rates, peak
level). Edit, re-run, rebuild the app.

Needs: numpy, scipy.
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(2026)


# ---------- helpers ----------

def axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def noise(n):
    return rng.standard_normal(n)


def bandpass(x, lo, hi, order=3):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=3):
    sos = signal.butter(order, f, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, f, order=3):
    sos = signal.butter(order, f, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def fade_edges(x, fade_in=0.004, fade_out=0.02):
    """Short fades so the file never starts or ends with a click."""
    n = len(x)
    a = max(1, int(fade_in * SR))
    b = max(1, int(fade_out * SR))
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[-b:] = np.linspace(1, 0, b)
    return x * env


def normalize(x, peak):
    return x / np.max(np.abs(x)) * peak


# ---------- the four sounds ----------

def strike():
    """A red pen scribbling an answer out: three quick strokes, each lighter than the last."""
    dur = 0.42
    n = int(SR * dur)
    t = axis(dur)
    base = noise(n)
    low = bandpass(base, 1400, 3500)       # knob: where the scratch sits
    high = bandpass(base, 3500, 8000)
    out = np.zeros(n)
    # (start s, length s, loudness, direction)
    strokes = [(0.00, 0.12, 1.00, +1), (0.13, 0.12, 0.85, -1), (0.26, 0.13, 0.65, +1)]
    for start, length, amp, direction in strokes:
        i0 = int(start * SR)
        i1 = min(n, i0 + int(length * SR))
        k = np.linspace(0, 1, i1 - i0)
        env = np.sin(np.pi * k) ** 0.7     # quick attack, softer release
        w = k if direction > 0 else 1 - k  # the brightness sweeps with the stroke direction
        out[i0:i1] += (low[i0:i1] * (1 - w) + high[i0:i1] * w) * env * amp
    out *= 1 + 0.35 * np.sin(2 * np.pi * 95 * t)   # scratchy texture
    return normalize(fade_edges(out), 0.55)


def circle():
    """A pen circling the mark. Lasts 0.95 s to match the circle being drawn on screen."""
    dur = 0.95
    n = int(SR * dur)
    t = axis(dur)
    base = noise(n)
    low = bandpass(base, 1200, 3200)
    high = bandpass(base, 3200, 7000)
    w = 0.5 + 0.5 * np.sin(2 * np.pi * 1.7 * t)             # knob: swirl speed
    swirl = low * (1 - w) + high * w
    env = smoothstep(t / 0.14) * (1 - smoothstep((t - (dur - 0.22)) / 0.22))
    stroke = 1 + 0.22 * np.sin(2 * np.pi * 6.5 * t)         # the hand's slight rhythm
    return normalize(fade_edges(swirl * env * stroke), 0.40)


def tear():
    """Paper ripping: irregular pulses of fibre noise, a low body, and crackle that thins out."""
    dur = 0.80
    n = int(SR * dur)
    t = axis(dur)
    base = noise(n)
    body = bandpass(base, 150, 450) * 0.5
    fibre = highpass(base, 900)
    pulses = lowpass(noise(n), 28)
    pulses = (pulses - pulses.min()) / (pulses.max() - pulses.min())
    pulses = 0.35 + 0.65 * pulses                            # irregular rip rhythm
    env = smoothstep(t / 0.015) * np.exp(-np.maximum(0, t - 0.35) * 5.0)
    density = 0.006 * np.exp(-t * 3.0) + 0.0008              # knob: crackle amount
    clicks = (rng.random(n) < density) * rng.uniform(0.4, 1.0, n) * rng.choice([-1, 1], n)
    kernel = np.exp(-np.arange(int(0.0025 * SR)) / (0.0007 * SR))
    crackle = highpass(np.convolve(clicks, kernel, mode="same"), 1200)
    out = (fibre * 0.55 + body * 0.45) * pulses * env + crackle * 2.2 * env
    return normalize(fade_edges(out, 0.003, 0.05), 0.65)


def stamp():
    """A rubber date stamp landing: a short low thump with a small click on top.

    A phone speaker can't reproduce much below ~150 Hz, so the thump carries harmonics
    (2x to 4x its pitch) that stay audible on a small speaker.
    """
    dur = 0.28
    n = int(SR * dur)
    t = axis(dur)
    freq = 70 + 80 * np.exp(-t * 35)                          # knob: pitch falls from ~150 Hz to 70 Hz
    phase = 2 * np.pi * np.cumsum(freq) / SR
    thump = (0.6 * np.sin(phase) + 1.0 * np.sin(2 * phase) + 0.8 * np.sin(3 * phase)
             + 0.4 * np.sin(4 * phase)) * np.exp(-t * 20)
    click = bandpass(noise(n), 1000, 6000) * np.exp(-t * 260)
    body = lowpass(noise(n), 500) * np.exp(-t * 30) * 0.35
    out = thump * 0.8 + click * 0.9 + body
    return normalize(fade_edges(out, 0.001, 0.03), 0.75)


SOUNDS = {
    "pen_strike": strike,
    "pen_circle": circle,
    "page_tear": tear,
    "stamp": stamp,
}


def save(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FrancNumero", "Sounds")
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in SOUNDS.items():
        samples = fn()
        save(os.path.join(out_dir, name + ".wav"), samples)
        print(f"{name}.wav  {len(samples) / SR:.2f}s  peak {np.max(np.abs(samples)):.2f}")
