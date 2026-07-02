extends Node

# All available roles — one per door you have in the level
var all_roles = ["guard", "janitor", "executive"]

func _ready():
	# Wait one frame so all NPCs are fully initialized
	await get_tree().process_frame
	_assign_random_roles()

func _assign_random_roles():
	# Get every NPC in the scene
	var npcs = get_tree().get_nodes_in_group("npc")
	
	if npcs.size() == 0:
		print("GameManager: no NPCs found — did you add them to the 'npc' group?")
		return
	
	# Shuffle roles so they are different every round
	var roles = all_roles.duplicate()
	roles.shuffle()
	
	# Assign one role per NPC — cycle through roles if more NPCs than roles
	for i in range(npcs.size()):
		var role = roles[i % roles.size()]
		npcs[i].set_role(role)
		print("GameManager: assigned '", role, "' to ", npcs[i].name)