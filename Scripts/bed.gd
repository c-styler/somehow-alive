extends Interactable
## A bed. Only the player's bed is interactable (sleep); the others are furniture that
## just blocks movement.

@export var is_players_bed := false

func _ready() -> void:
	if not is_players_bed:
		show_indicator = false
		if hitbox:
			hitbox.collision_layer = 0 # not hoverable/clickable, still a pathing blocker
	super()

func interact(_player: Player) -> void:
	if is_players_bed:
		action_requested.emit(&"sleep", self)
