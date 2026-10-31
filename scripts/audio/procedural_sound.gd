class_name ProceduralSound
extends RefCounted
## Sons provisoires générés par code à partir d'une recette (SoundCueDefinition) : coup tonal glissant, souffle
## filtré, clic. Calculés une fois au chargement (trois niveaux d'intensité), jamais pendant le match.
## Déterministe : même recette, même niveau → mêmes échantillons (bruit pseudo-aléatoire à graine fixe, sans hasard).
## Le pic est toujours ramené sous PEAK_LIMIT (−1 dBFS) : pas de saturation.

const MIX_RATE := 22050
const PEAK_LIMIT := 0.891   # −1 dBFS
## Niveaux d'intensité précalculés : un son mou est aussi plus sourd (souffle moins brillant, clic plus faible).
const TIERS: Array[float] = [0.25, 0.6, 1.0]


## Échantillons (−1 → 1) d'une recette pour un niveau d'intensité (0 → 1).
static func samples(cue: SoundCueDefinition, tier: float) -> PackedFloat32Array:
	var n := maxi(1, int(cue.duration_s * MIX_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var brightness := clampf(cue.noise_brightness * (0.45 + 0.55 * tier), 0.01, 1.0)
	var click_gain := cue.click_gain * (0.3 + 0.7 * tier)
	var seed := 0x2545F491 + cue.id.hash() % 9973
	var lp := 0.0
	var phase := 0.0
	var peak := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.0
		if cue.tone_s > 0.0 and t < cue.tone_s * 3.0:
			var u := clampf(t / maxf(cue.tone_s, 1e-4), 0.0, 1.0)
			var freq := cue.tone_start_hz * pow(cue.tone_end_hz / cue.tone_start_hz, u)
			phase += TAU * freq / MIX_RATE
			v += cue.tone_gain * sin(phase) * _env(t, 0.002, cue.tone_s / 3.0)
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var white := float(seed) / float(0x3fffffff) - 1.0
		lp += brightness * (white - lp)
		if t < cue.noise_s * 4.0:
			v += cue.noise_gain * lp * _env(t, 0.0005, maxf(cue.noise_s, 1e-4) / 2.0)
		v += click_gain * sin(TAU * cue.click_hz * t) * _env(t, 0.0002, 0.003)
		v *= clampf((cue.duration_s - t) / 0.01, 0.0, 1.0)   # fin sans clic
		out[i] = v
		peak = maxf(peak, absf(v))
	if peak > PEAK_LIMIT:
		var g := PEAK_LIMIT / peak
		for i in n:
			out[i] *= g
	return out


static func _env(t: float, attack: float, tau: float) -> float:
	var a := clampf(t / attack, 0.0, 1.0) if attack > 0.0 else 1.0
	return a * exp(-t / maxf(tau, 1e-5))


## Flux audio 16 bits mono à partir d'échantillons.
static func to_stream(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(round(clampf(data[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Pic absolu d'un jeu d'échantillons (pour les tests et le diagnostic).
static func peak_of(data: PackedFloat32Array) -> float:
	var peak := 0.0
	for v in data:
		peak = maxf(peak, absf(v))
	return peak
