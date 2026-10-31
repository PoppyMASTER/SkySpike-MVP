class_name MatchConfig
extends RefCounted
## Composition des équipes. Les persos sont répartis par poste : le 1er de chaque poste (ordre alphabétique
## des identifiants) joue à gauche (équipe du joueur, bleue), le 2e à droite (équipe adverse, rouge).
## Ordre des slots : attaquant, passeur, défenseur pour chaque équipe.


## Six définitions (slots 0-2 puis 3-5), ou un tableau incomplet si le dépôt n'a pas assez de persos.
static func default_lineup(repo: CharacterRepository) -> Array[CharacterDefinition]:
	var by_role: Dictionary = {Enums.Role.ATTACKER: [], Enums.Role.SETTER: [], Enums.Role.DEFENDER: []}
	for id: String in repo.ids():
		var c := repo.get_character(id)
		by_role[c.role].append(c)
	var out: Array[CharacterDefinition] = []
	for team in 2:
		for role: int in [Enums.Role.ATTACKER, Enums.Role.SETTER, Enums.Role.DEFENDER]:
			var list: Array = by_role[role]
			if team < list.size():
				out.append(list[team])
	return out
