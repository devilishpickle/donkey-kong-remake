extends Area2D
class_name Ladder

## Reusable ladder trigger zone. Attach this script to the Area2D root of a
## Ladder scene (with a CollisionShape2D child sized to the ladder's bounds).
## Instance that scene wherever you want a ladder — no per-ladder signal
## wiring or player-script edits needed.

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_ladder_zone"):
		var top_y: float = shape.global_position.y - (shape.shape.size.y / 2.0)
		body.set_ladder_zone(true, shape.global_position.x, top_y)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_ladder_zone"):
		body.set_ladder_zone(false)
