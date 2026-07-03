extends Node

var all_roles = ["guard", "janitor", "executive"]

func _ready():
	# Wait 2 frames — instanced scenes need extra time to call their own _ready
	await get_tree().process_frame
	await get_tree().process_frame
	_assign_random_roles()

func _assign_random_roles():
	var npcs = get_tree().get_nodes_in_group("npc")
	print("GameManager found ", npcs.size(), " NPCs")

	if npcs.size() == 0:
		print("ERROR: No NPCs found in group 'npc' — check npc.gd has add_to_group('npc') in _ready()")
		return

	var roles = all_roles.duplicate()
	roles.shuffle()

	for i in range(npcs.size()):
		var assigned = roles[i % roles.size()]
		npcs[i].set_role(assigned)
		print("Assigned role '", assigned, "' to ", npcs[i].name)