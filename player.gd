extends CharacterBody2D

@export var move_speed: float = 78.0
@export var jump_velocity: float = -176.0
@export var gravity: float = 1025.0
@export var climb_speed: float = 70.0
@export var coyote_time: float = 0.04
@export var jump_buffer_time: float = 0.04

enum State { GROUND, AIR, LADDER, DEAD }
var state: State = State.GROUND

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var on_ladder_zone: bool = false
var ladder_x: float = 0.0
var ladder_top_y: float = 0.0
var ladder_entry_y: float = 0.0
var default_collision_mask: int = 1
var is_climbing_off_top: bool = false
var did_jump: bool = false
var last_walk_frame := -1

var spawn_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk_sound: AudioStreamPlayer2D = $WalkSound
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var die_sound: AudioStreamPlayer2D = $DieSound


func _ready() -> void:
	spawn_position = global_position
	default_collision_mask = collision_mask
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_update_timers(delta)

	match state:
		State.GROUND:
			_process_ground()
		State.AIR:
			_process_air(delta)
		State.LADDER:
			_process_ladder()

	move_and_slide()


func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)


func _process_ground() -> void:
	_apply_horizontal_movement()
	velocity.y = 0.0

	if on_ladder_zone and (
		Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	):
		_enter_ladder()
		return

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_sound.play()
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		state = State.AIR
		did_jump = true
		_update_animation()
		return

	if not is_on_floor():
		state = State.AIR
		did_jump = false
		velocity.x = 0.0

	_update_animation()


func _process_air(delta: float) -> void:
	velocity.y += gravity * delta

	if on_ladder_zone and (
		Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	):
		_enter_ladder()
		return

	if is_on_floor():
		state = State.GROUND

	_update_animation()


func _process_ladder() -> void:
	print("state=LADDER | player.x=", global_position.x, " ladder_x=", ladder_x, " | player.y=", global_position.y, " ladder_top_y=", ladder_top_y, " entry_y=", ladder_entry_y)

	if is_climbing_off_top:
		velocity = Vector2.ZERO
		return

	position.x = ladder_x
	velocity.x = 0.0

	var climb_input := Input.get_axis("move_up", "move_down")
	velocity.y = climb_input * climb_speed

	if climb_input < 0 and global_position.y <= ladder_top_y and ladder_entry_y > ladder_top_y:
		_start_end_climb()
		return

	if not on_ladder_zone:
		state = State.AIR
		collision_mask = default_collision_mask
		_update_animation()
		return

	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * 0.6
		jump_sound.play()
		state = State.AIR
		collision_mask = default_collision_mask
		did_jump = true

	_update_animation()


func _update_animation() -> void:
	if is_climbing_off_top:
		return

	if state != State.LADDER:
		sprite.speed_scale = 1.0

	match state:

		State.GROUND:
			if velocity.x != 0:
				if sprite.animation != "walk":
					sprite.play("walk")

				if (sprite.frame == 0 or sprite.frame == 2) and sprite.frame != last_walk_frame:
					last_walk_frame = sprite.frame
					walk_sound.play()

			else:
				sprite.play("idle")
				last_walk_frame = -1

		State.AIR:
			last_walk_frame = -1

			if did_jump:
				sprite.play("jump")
			else:
				if velocity.x != 0:
					sprite.play("walk")
				else:
					sprite.play("idle")
#ignore#
		State.LADDER:
			sprite.speed_scale = -1.0 if velocity.y > 0 else 1.0
			if velocity.y != 0:
				if not sprite.is_playing() or sprite.animation != "climb":
					sprite.play("climb")

				if sprite.frame != last_walk_frame:
					last_walk_frame = sprite.frame
					walk_sound.play()
			else:
				sprite.stop()
				last_walk_frame = -1
func _start_end_climb() -> void:
	is_climbing_off_top = true
	velocity = Vector2.ZERO
	collision_mask = default_collision_mask
	sprite.speed_scale = 1.0
	sprite.play("endclimb")


func die() -> void:
	if state == State.DEAD:
		return  # already dying — don't restart the sequence
	state = State.DEAD
	velocity = Vector2.ZERO
	die_sound.play()
	sprite.speed_scale = 1.0
	sprite.play("die")


func _on_animation_finished() -> void:
	if sprite.animation == "endclimb":
		is_climbing_off_top = false
		state = State.GROUND
		_update_animation()
	elif sprite.animation == "die":
		_respawn()


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	did_jump = false
	is_climbing_off_top = false
	on_ladder_zone = false
	collision_mask = default_collision_mask
	state = State.GROUND
	_update_animation()


func _apply_horizontal_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0:
		sprite.flip_h = direction < 0


func _enter_ladder() -> void:
	state = State.LADDER
	velocity = Vector2.ZERO
	collision_mask = 0
	ladder_entry_y = global_position.y
	_update_animation()


func set_ladder_zone(active: bool, ladder_center_x: float = 0.0, top_y: float = 0.0) -> void:
	on_ladder_zone = active
	if active:
		ladder_x = ladder_center_x
		ladder_top_y = top_y


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.die()
