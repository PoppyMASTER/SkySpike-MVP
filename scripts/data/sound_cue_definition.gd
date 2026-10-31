class_name SoundCueDefinition
extends RefCounted
## Un son de frappe (data/audio/cues.json) : fichier facultatif, sinon recette de synthèse provisoire.
## Purement présentation : rien ici n'est lu par la simulation.

var id := ""
## Fichier WAV ou OGG (res:// ou user://). Vide ou introuvable = synthèse par recette.
var file := ""
var volume_db := 0.0
## Variation de hauteur (± fraction), tirée du numéro de tick : pas de hasard.
var pitch_jitter := 0.0
## Recette de synthèse : coup tonal (sinus glissant), souffle filtré, clic.
var duration_s := 0.2
var tone_start_hz := 200.0
var tone_end_hz := 120.0
var tone_s := 0.1
var tone_gain := 0.8
var noise_s := 0.02
var noise_gain := 0.3
## Clarté du souffle : 1 = brut et brillant, proche de 0 = étouffé.
var noise_brightness := 0.5
var click_hz := 2000.0
var click_gain := 0.2
