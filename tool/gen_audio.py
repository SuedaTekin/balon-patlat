"""Balon Patlat ses efektleri ve müzik döngüleri (sentezlenmiş, telifsiz).

Çalıştırma: python tool/gen_audio.py  → assets/audio/*.wav
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
random.seed(7)


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    k = 0.89 / peak if peak > 0.89 else 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def env(t, a, d, total):
    if t < a:
        return t / a
    return max(0.0, 1 - (t - a) / max(1e-6, d)) if t < total else 0.0


def tone(freq_fn, dur, a=0.005, wave_fn=math.sin, vol=1.0):
    out, ph = [], 0.0
    n = int(dur * SR)
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * freq_fn(t) / SR
        out.append(wave_fn(ph) * env(t, a, dur - a, dur) * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def tri(ph):
    return 2 / math.pi * math.asin(math.sin(ph))


def sq(ph):
    return 0.6 if math.sin(ph) >= 0 else -0.6


def noise(dur, vol=1.0, decay=1.0):
    n = int(dur * SR)
    return [random.uniform(-1, 1) * vol * (1 - i / n) ** decay for i in range(n)]


def lowpass(x, a=0.15):
    y, p = [], 0.0
    for s in x:
        p += a * (s - p)
        y.append(p)
    return y


# ---------- efektler ----------
def pop(pitch):
    body = tone(lambda t: pitch * (1.6 - t * 9), 0.11, a=0.002)
    click = lowpass(noise(0.03, 0.5, 2), 0.5)
    return mix(body, click)


for i, p in enumerate([520, 620, 740, 880]):
    save(f"pop{i}", pop(p))

save("shoot", mix(tone(lambda t: 300 + t * 2200, 0.09, wave_fn=tri, vol=0.5), lowpass(noise(0.08, 0.25, 1.5), 0.3)))
save("bounce", tone(lambda t: 900, 0.04, wave_fn=tri, vol=0.35))
save("stick", mix(tone(lambda t: 180 - t * 400, 0.07, vol=0.6), lowpass(noise(0.04, 0.3, 2), 0.2)))
save("drop", tone(lambda t: 700 - t * 1500, 0.28, wave_fn=tri, vol=0.5))
save("stone", lowpass(mix(noise(0.22, 0.9, 2.5), tone(lambda t: 90, 0.2, vol=0.6)), 0.25))
save("click", tone(lambda t: 1200, 0.035, wave_fn=tri, vol=0.4))
save("coin", mix(tone(lambda t: 1318, 0.08, wave_fn=sq, vol=0.3), [0] * int(0.07 * SR) + tone(lambda t: 1760, 0.22, wave_fn=sq, vol=0.3)))
save("fire", lowpass([s * (0.4 + 0.6 * math.sin(i / SR * 30)) for i, s in enumerate(noise(0.5, 0.9, 0.8))], 0.12))
save("laser", tone(lambda t: 1800 - t * 3000, 0.35, wave_fn=sq, vol=0.35))
save("rainbow", mix(*[[0] * int(k * 0.05 * SR) + tone(lambda t, f=f: f, 0.25, wave_fn=tri, vol=0.35) for k, f in enumerate([523, 659, 784, 1046, 1318])]))
save("bomb", lowpass(mix(tone(lambda t: 140 * (1 - t * 1.4), 0.6, a=0.003, vol=1.0), noise(0.55, 0.9, 1.6)), 0.09))
save("row", tone(lambda t: 160 + 30 * math.sin(t * 60), 0.3, wave_fn=tri, vol=0.5))


def arp(notes, step, length, wave_fn=tri, vol=0.4):
    tracks = []
    for k, f in enumerate(notes):
        tracks.append([0] * int(k * step * SR) + tone(lambda t, f=f: f, length, wave_fn=wave_fn, vol=vol))
    return mix(*tracks)


save("win", mix(arp([523, 659, 784, 1046], 0.11, 0.35), [0] * int(0.48 * SR) + arp([784, 1046, 1318], 0.0, 0.7, vol=0.3)))
save("lose", arp([392, 349, 311, 262], 0.18, 0.4, wave_fn=tri, vol=0.4))
save("star", arp([1046, 1568], 0.06, 0.25, wave_fn=sq, vol=0.25))
save("combo", arp([659, 880, 1174], 0.05, 0.18, wave_fn=sq, vol=0.25))
save("tier", arp([784, 988, 1175, 1568], 0.07, 0.3, wave_fn=tri, vol=0.32))


# ---------- müzik ----------
def note_hz(n):  # n: MIDI
    return 440 * 2 ** ((n - 69) / 12)


def music(name, bpm, chords, melody, lead_wave, bass_vol=0.32, lead_vol=0.22):
    beat = 60 / bpm
    total = int(len(chords) * 4 * beat * SR)
    buf = [0.0] * total

    def add(start, samples):
        s0 = int(start * SR)
        for i, v in enumerate(samples):
            if s0 + i < total:
                buf[s0 + i] += v

    for bar, ch in enumerate(chords):
        t0 = bar * 4 * beat
        # bas: kök nota, 8'lik
        for k in range(8):
            f = note_hz(ch[0] - 12 + (12 if k % 4 == 3 else 0))
            add(t0 + k * beat / 2, tone(lambda t, f=f: f, beat / 2 * 0.9, wave_fn=tri, vol=bass_vol))
        # akor arpeji
        for k in range(16):
            f = note_hz(ch[k % len(ch)] + 12)
            add(t0 + k * beat / 4, tone(lambda t, f=f: f, beat / 4 * 0.8, wave_fn=sq, vol=0.05))
        # vuruş: tık + hi-hat
        for k in range(4):
            add(t0 + k * beat, lowpass(noise(0.06, 0.35 if k % 2 == 0 else 0.2, 3), 0.08))
            add(t0 + k * beat + beat / 2, noise(0.025, 0.08, 4))
    for start, n, length in melody:
        f = note_hz(n)
        add(start * beat, tone(lambda t, f=f: f * (1 + 0.004 * math.sin(t * 30)), length * beat * 0.92, a=0.01, wave_fn=lead_wave, vol=lead_vol))
    # döngü ucu yumuşat
    fade = int(0.01 * SR)
    for i in range(fade):
        buf[i] *= i / fade
        buf[-1 - i] *= i / fade
    save(name, buf)


C, F, G, Am, Dm, Em = [60, 64, 67], [65, 69, 72], [67, 71, 74], [57, 60, 64], [62, 65, 69], [64, 67, 71]

# menü: sakin, neşeli
menu_mel = []
phrase = [(0, 72, 1), (1, 76, 1), (2, 79, 2), (4, 77, 1), (5, 76, 1), (6, 74, 2),
          (8, 72, 1), (9, 74, 1), (10, 76, 1), (11, 72, 1), (12, 69, 2), (14, 71, 2)]
for rep in range(2):
    for s, n, l in phrase:
        menu_mel.append((s + rep * 16, n, l))
music("music_menu", 96, [C, Am, F, G, C, Am, Dm, G], menu_mel, math.sin, lead_vol=0.25)

# oyun: daha hızlı, enerjik
game_mel = []
riff = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 84, 1), (2, 83, 0.5), (2.5, 79, 0.5), (3, 76, 1),
        (4, 77, 0.5), (4.5, 81, 0.5), (5, 84, 1), (6, 83, 1), (7, 79, 1)]
for rep in range(4):
    for s, n, l in riff:
        game_mel.append((s + rep * 8, n + (0 if rep % 2 == 0 else -2), l))
music("music_game", 124, [C, G, Am, F, C, G, F, G], game_mel, tri, lead_vol=0.2)
print("ok")
