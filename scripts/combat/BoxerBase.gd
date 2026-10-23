
extends CharacterBody2D
class_name BoxerBase

signal stats_changed(boxer: BoxerBase)
signal knocked_out(boxer: BoxerBase)
signal attack_started(boxer: BoxerBase, attack_name: StringName)
signal attack_finished(boxer: BoxerBase, attack_name: StringName)

# ============================================================
# CONFIGURACION
# ============================================================

@export_group("Identidad")
@export var boxer_name: String = "Boxeador"
@export var is_player: bool = true
@export var sprite_faces_left: bool = false
@export var sprite_scale: float = 1.0

@export_group("Estadisticas")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0

@export_group("Movimiento")
@export var move_speed: float = 190.0
@export var air_control: float = 0.85
@export var jump_velocity: float = -500.0
@export var gravity: float = 1200.0

@export_group("Bloqueo")
@export var block_stamina_drain: float = 12.0
@export var stamina_regen_rate: float = 22.0
@export var stamina_regen_delay: float = 1.1

@export_group("Combate")
@export var jab_damage: float = 6.0
@export var crouch_jab_damage: float = 6.0
@export var heavy_attack_damage: float = 16.0
@export var jump_jab_damage: float = 6.0
@export var kick_damage: float = 12.0
@export var special_damage: float = 25.0

@export var jab_cost: float = 8.0
@export var crouch_jab_cost: float = 8.0
@export var heavy_attack_cost: float = 20.0
@export var jump_jab_cost: float = 10.0
@export var kick_cost: float = 15.0
@export var special_cost: float = 30.0

@export var jab_active_time: float = 0.12
@export var crouch_jab_active_time: float = 0.12
@export var heavy_attack_active_time: float = 0.20
@export var jump_jab_active_time: float = 0.12
@export var kick_active_time: float = 0.18
@export var special_active_time: float = 0.25

# ============================================================
# ANIMACIONES
# ============================================================

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_WALK_BACKWARDS: StringName = &"walk_backwards"
const ANIM_CROUCH_WALK: StringName = &"crouch_walk"
const ANIM_CROUCH_WALK_BACKWARDS: StringName = &"crouch_walk_backwards"
const ANIM_JUMP: StringName = &"jump"
const ANIM_SPECIAL: StringName = &"special"
const ANIM_JAB: StringName = &"jab"
const ANIM_JUMP_JAB: StringName = &"jump_jab"
const ANIM_CROUCH_JAB: StringName = &"crouch_jab"
const ANIM_HEAVY_ATTACK: StringName = &"heavy_attack"
const ANIM_KICK: StringName = &"kick"
const ANIM_BLOCK: StringName = &"block"
const ANIM_CROUCH_BLOCK: StringName = &"crouch_block"
const ANIM_JUMP_BLOCK: StringName = &"jump_block"
const ANIM_HIT: StringName = &"hit"
const ANIM_CROUCH_HIT: StringName = &"crouch_hit"
const ANIM_JUMP_HIT: StringName = &"jump_hit"
const ANIM_KO: StringName = &"ko"
const ANIM_CROUCH_KO: StringName = &"crouch_ko"
const ANIM_JUMP_KO: StringName = &"jump_ko"

# ============================================================
# NODOS
# ============================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

@onready var hitbox_jab: Area2D = $HitboxJab
@onready var hurtbox: Area2D = $Hurtbox
@onready var push_box: Area2D = $PushBox

@onready var hitbox_crouch_jab: Area2D = $HitboxCrouchJab
@onready var hitbox_heavy_attack: Area2D = $HitboxHeavyAttack
@onready var hitbox_jump_jab: Area2D = $HitboxJumpJab
@onready var hitbox_kick: Area2D = $HitboxKick
@onready var hitbox_special: Area2D = $HitboxSpecial

# ============================================================
# ESTADO
# ============================================================

var health: float = 100.0
var stamina: float = 100.0

var opponent: BoxerBase = null
var facing: int = 1

var guarding: bool = false
var crouching: bool = false
var is_out: bool = false
var is_attacking: bool = false
var is_receiving_hit: bool = false
var _jump_key_was_pressed: bool = false

var current_animation: StringName = &""
var current_attack: StringName = &""

var regen_wait: float = 0.0
var hit_stun_time: float = 0.0
var attack_id: int = 0

var knockback_velocity: Vector2 = Vector2.ZERO
var active_hitbox: Area2D = null
var hit_targets: Dictionary = {}
var attack_data: Dictionary = {}

var _attack_key_was_pressed: bool = false
var _heavy_key_was_pressed: bool = false
var _kick_key_was_pressed: bool = false
var _special_key_was_pressed: bool = false

# Posiciones originales de las colisiones.
var _hitbox_original_positions: Dictionary = {}
var _hitbox_shape_original_positions: Dictionary = {}

var _pushbox_original_position: Vector2
var _hurtbox_original_position: Vector2
var _body_shape_original_position: Vector2

var _collision_positions_initialized: bool = false

# ============================================================
# INICIALIZACION
# ============================================================

func _ready() -> void:
	health = max_health
	stamina = max_stamina

	add_to_group("boxers")

	# Conservar la escala configurada en la escena.
	if animated_sprite.sprite_frames == null:
		push_error(boxer_name + ": falta asignar SpriteFrames.")
		set_physics_process(false)
		return

	# Evitar que las animaciones KO se repitan.
	var ko_animations: Array[StringName] = [
		ANIM_KO,
		ANIM_CROUCH_KO,
		ANIM_JUMP_KO
	]

	for anim in ko_animations:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)

	# Detectar cuándo termina una animación.
	if not animated_sprite.animation_finished.is_connected(
		_on_animated_sprite_animation_finished
	):
		animated_sprite.animation_finished.connect(
			_on_animated_sprite_animation_finished
		)

	_validate_animations()
	_connect_hitboxes()
	_save_collision_positions()
	_disable_all_hitboxes()

	hurtbox.monitoring = true
	_update_facing()
	_play_animation(ANIM_IDLE)
	stats_changed.emit(self)

func _validate_animations() -> void:
	var required: Array[StringName] = [
		ANIM_IDLE, ANIM_WALK, ANIM_WALK_BACKWARDS,
		ANIM_CROUCH_WALK, ANIM_CROUCH_WALK_BACKWARDS,
		ANIM_JUMP, ANIM_SPECIAL, ANIM_JAB, ANIM_JUMP_JAB,
		ANIM_CROUCH_JAB, ANIM_HEAVY_ATTACK, ANIM_KICK,
		ANIM_BLOCK, ANIM_CROUCH_BLOCK, ANIM_JUMP_BLOCK,
		ANIM_HIT, ANIM_CROUCH_HIT, ANIM_JUMP_HIT,
		ANIM_KO, ANIM_CROUCH_KO, ANIM_JUMP_KO
	]

	for anim in required:
		if not animated_sprite.sprite_frames.has_animation(anim):
			push_warning(boxer_name + ": falta la animacion " + String(anim))


func _get_all_hitboxes() -> Array[Area2D]:
	return [
		hitbox_jab,
		hitbox_crouch_jab,
		hitbox_heavy_attack,
		hitbox_jump_jab,
		hitbox_kick,
		hitbox_special
	]


func _connect_hitboxes() -> void:
	for hitbox in _get_all_hitboxes():
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)

		hitbox.monitoring = false


# ============================================================
# GUARDAR Y GIRAR HITBOXES
# ============================================================

func _save_collision_positions() -> void:
	_hitbox_original_positions.clear()
	_hitbox_shape_original_positions.clear()

	for hitbox in _get_all_hitboxes():
		if not is_instance_valid(hitbox):
			continue

		_hitbox_original_positions[hitbox] = hitbox.position

		var shape_node := hitbox.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

		if shape_node != null:
			_hitbox_shape_original_positions[hitbox] = shape_node.position

	if is_instance_valid(push_box):
		_pushbox_original_position = push_box.position

	if is_instance_valid(hurtbox):
		_hurtbox_original_position = hurtbox.position

	if is_instance_valid(body_shape):
		_body_shape_original_position = body_shape.position

	_collision_positions_initialized = true
	_update_collision_directions()


func _update_collision_directions() -> void:
	if not _collision_positions_initialized:
		return

	var sprite_x: float = animated_sprite.position.x

	for hitbox in _get_all_hitboxes():
		if not is_instance_valid(hitbox):
			continue

		if not _hitbox_original_positions.has(hitbox):
			continue

		var area_origin: Vector2 = _hitbox_original_positions[hitbox]

		# Mantener el Area2D en su posición original.
		hitbox.position = area_origin

		var shape_node := hitbox.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

		if shape_node == null:
			continue

		if not _hitbox_shape_original_positions.has(hitbox):
			continue

		var shape_origin: Vector2 = (
			_hitbox_shape_original_positions[hitbox]
		)

		# Reflejar el CollisionShape2D respecto al sprite.
		var total_x: float = area_origin.x + shape_origin.x

		var target_x: float = (
			sprite_x + (total_x - sprite_x) * facing
		)

		shape_node.position = Vector2(
			target_x - area_origin.x,
			shape_origin.y
		)

	# Las colisiones corporales conservan su posición original.
	if is_instance_valid(push_box):
		push_box.position = _pushbox_original_position

	if is_instance_valid(hurtbox):
		hurtbox.position = _hurtbox_original_position

	if is_instance_valid(body_shape):
		body_shape.position = _body_shape_original_position


# ============================================================
# FISICA Y MOVIMIENTO
# ============================================================

func _physics_process(delta: float) -> void:
	if is_out:
		_apply_gravity(delta)
		move_and_slide()
		return

	regen_wait = maxf(0.0, regen_wait - delta)
	hit_stun_time = maxf(0.0, hit_stun_time - delta)

	_update_facing()

	if hit_stun_time > 0.0:
		guarding = false
		crouching = false
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)

	elif is_attacking:
		guarding = false
		crouching = false

		if current_attack != ANIM_JUMP_JAB:
			velocity.x = 0.0

	elif is_player:
		_read_player_input()

	else:
		_read_ai_input(delta)

	_apply_gravity(delta)
	_update_stamina(delta)
	_apply_knockback(delta)

	move_and_slide()

	_update_movement_animation()
	stats_changed.emit(self)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _read_player_input() -> void:
	var horizontal: float = 0.0

	if Input.is_key_pressed(KEY_A):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal += 1.0

	crouching = Input.is_key_pressed(KEY_S) and is_on_floor()
	guarding = Input.is_key_pressed(KEY_I) and stamina > 0.0

	if guarding and crouching:
		velocity.x = 0.0

		_attack_key_was_pressed = Input.is_key_pressed(KEY_J)
		_heavy_key_was_pressed = Input.is_key_pressed(KEY_K)
		_kick_key_was_pressed = Input.is_key_pressed(KEY_L)
		_special_key_was_pressed = Input.is_key_pressed(KEY_U)
		_jump_key_was_pressed = Input.is_key_pressed(KEY_W)
		return

	var speed: float = move_speed

	if not is_on_floor():
		speed *= air_control

	velocity.x = horizontal * speed

	var jump_key_pressed: bool = Input.is_key_pressed(KEY_W)

	if jump_key_pressed and not _jump_key_was_pressed:
		if is_on_floor() and not guarding and not is_attacking:
			velocity.y = jump_velocity

	_jump_key_was_pressed = jump_key_pressed

	if guarding:
		_attack_key_was_pressed = Input.is_key_pressed(KEY_J)
		_heavy_key_was_pressed = Input.is_key_pressed(KEY_K)
		_kick_key_was_pressed = Input.is_key_pressed(KEY_L)
		_special_key_was_pressed = Input.is_key_pressed(KEY_U)
		return

	if Input.is_key_pressed(KEY_J) and not _attack_key_was_pressed:
		if not is_on_floor():
			_start_attack(ANIM_JUMP_JAB)
		elif crouching:
			_start_attack(ANIM_CROUCH_JAB)
		else:
			_start_attack(ANIM_JAB)

	elif Input.is_key_pressed(KEY_K) and not _heavy_key_was_pressed:
		if is_on_floor() and not crouching:
			_start_attack(ANIM_HEAVY_ATTACK)

	elif Input.is_key_pressed(KEY_L) and not _kick_key_was_pressed:
		if is_on_floor() and not crouching:
			_start_attack(ANIM_KICK)

	elif Input.is_key_pressed(KEY_U) and not _special_key_was_pressed:
		if is_on_floor() and not crouching:
			_start_attack(ANIM_SPECIAL)

	_attack_key_was_pressed = Input.is_key_pressed(KEY_J)
	_heavy_key_was_pressed = Input.is_key_pressed(KEY_K)
	_kick_key_was_pressed = Input.is_key_pressed(KEY_L)
	_special_key_was_pressed = Input.is_key_pressed(KEY_U)


func _read_ai_input(_delta: float) -> void:
	guarding = false
	crouching = false
	velocity.x = 0.0


# ============================================================
# ORIENTACION
# ============================================================

func _update_facing() -> void:
	if opponent == null or not is_instance_valid(opponent):
		return

	if opponent.is_out:
		return

	var new_facing: int = 1

	if opponent.global_position.x < global_position.x:
		new_facing = -1

	if new_facing != facing:
		facing = new_facing
		_update_sprite_direction()

	_update_collision_directions()


func _update_sprite_direction() -> void:
	animated_sprite.flip_h = ((facing < 0) != sprite_faces_left)


func _is_moving_backwards() -> bool:
	if opponent == null or not is_instance_valid(opponent):
		return false

	return signf(velocity.x) != float(facing) and absf(velocity.x) > 8.0


# ============================================================
# ANIMACIONES
# ============================================================

func _play_animation(anim: StringName) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(anim):
		return

	if current_animation == anim and animated_sprite.is_playing():
		return

	current_animation = anim
	_update_sprite_direction()
	animated_sprite.play(anim)

func _update_movement_animation() -> void:
	if is_out or is_attacking or hit_stun_time > 0.0:
		return

	if guarding:
		if not is_on_floor():
			_play_animation(ANIM_JUMP_BLOCK)
		elif crouching:
			_play_animation(ANIM_CROUCH_BLOCK)
		else:
			_play_animation(ANIM_BLOCK)
		return

	if not is_on_floor():
		_play_animation(ANIM_JUMP)
		return

	if crouching:
		if absf(velocity.x) > 8.0:
			_play_animation(
				ANIM_CROUCH_WALK_BACKWARDS
				if _is_moving_backwards()
				else ANIM_CROUCH_WALK
			)
		else:
			if (
				current_animation != ANIM_CROUCH_WALK
				and current_animation != ANIM_CROUCH_WALK_BACKWARDS
			):
				_play_animation(ANIM_CROUCH_WALK)
			else:
				animated_sprite.pause()
		return

	if absf(velocity.x) > 8.0:
		_play_animation(
			ANIM_WALK_BACKWARDS
			if _is_moving_backwards()
			else ANIM_WALK
		)
	else:
		_play_animation(ANIM_IDLE)


# ============================================================
# ATAQUES
# ============================================================

func _start_attack(anim: StringName) -> void:
	if is_out or is_attacking or hit_stun_time > 0.0:
		return

	var selected_hitbox: Area2D
	var damage: float
	var cost: float
	var active_time: float

	match anim:
		ANIM_JAB:
			selected_hitbox = hitbox_jab
			damage = jab_damage
			cost = jab_cost
			active_time = jab_active_time

		ANIM_CROUCH_JAB:
			selected_hitbox = hitbox_crouch_jab
			damage = crouch_jab_damage
			cost = crouch_jab_cost
			active_time = crouch_jab_active_time

		ANIM_JUMP_JAB:
			selected_hitbox = hitbox_jump_jab
			damage = jump_jab_damage
			cost = jump_jab_cost
			active_time = jump_jab_active_time

		ANIM_HEAVY_ATTACK:
			selected_hitbox = hitbox_heavy_attack
			damage = heavy_attack_damage
			cost = heavy_attack_cost
			active_time = heavy_attack_active_time

		ANIM_KICK:
			selected_hitbox = hitbox_kick
			damage = kick_damage
			cost = kick_cost
			active_time = kick_active_time

		ANIM_SPECIAL:
			selected_hitbox = hitbox_special
			damage = special_damage
			cost = special_cost
			active_time = special_active_time

		_:
			return

	if not animated_sprite.sprite_frames.has_animation(anim):
		push_warning(boxer_name + ": falta " + String(anim))
		return

	if stamina < cost:
		return

	var fps: float = animated_sprite.sprite_frames.get_animation_speed(anim)
	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(anim)

	if fps <= 0.0 or frame_count <= 0:
		push_warning("Animacion sin frames o FPS validos: " + String(anim))
		return

	stamina -= cost
	regen_wait = stamina_regen_delay

	is_attacking = true
	guarding = false
	crouching = false
	current_attack = anim
	attack_id += 1

	var this_attack_id: int = attack_id
	var animation_duration: float = float(frame_count) / fps

	attack_data = {"damage": damage}
	_disable_all_hitboxes()

	current_animation = &""
	_play_animation(anim)
	attack_started.emit(self, anim)

	_run_attack(
		this_attack_id,
		selected_hitbox,
		active_time,
		animation_duration
	)


func _run_attack(
	this_attack_id: int,
	selected_hitbox: Area2D,
	active_time: float,
	animation_duration: float
) -> void:
	active_hitbox = selected_hitbox
	hit_targets.clear()
	selected_hitbox.set_deferred("monitoring", true)

	await get_tree().create_timer(active_time).timeout

	if not is_inside_tree() or this_attack_id != attack_id:
		return

	selected_hitbox.set_deferred("monitoring", false)
	active_hitbox = null

	var remaining_time: float = maxf(0.0, animation_duration - active_time)

	if remaining_time > 0.0:
		await get_tree().create_timer(remaining_time).timeout

	if not is_inside_tree() or this_attack_id != attack_id:
		return

	_disable_all_hitboxes()
	is_attacking = false

	var finished_attack: StringName = current_attack
	current_attack = &""
	current_animation = &""

	attack_finished.emit(self, finished_attack)
	_play_animation(ANIM_IDLE)


func _disable_all_hitboxes() -> void:
	for hitbox in _get_all_hitboxes():
		if is_instance_valid(hitbox):
			hitbox.set_deferred("monitoring", false)

	active_hitbox = null
	hit_targets.clear()


# ============================================================
# DETECCION DE GOLPES
# ============================================================

func _on_hitbox_area_entered(area: Area2D) -> void:
	if active_hitbox == null or not is_attacking or is_out:
		return

	if not is_instance_valid(area):
		return

	if not area.is_in_group("hurtboxes"):
		return

	var target := area.get_parent() as BoxerBase

	if target == null or target == self or target.is_out:
		return

	if opponent != null and target != opponent:
		return

	var target_id: int = target.get_instance_id()

	if hit_targets.has(target_id):
		return

	hit_targets[target_id] = true

	target.receive_hit(
		float(attack_data.get("damage", 0.0)),
		global_position
	)


# ============================================================
# RECIBIR DAÑO
# ============================================================

func receive_hit(amount: float, attacker_position: Vector2) -> void:
	if is_out:
		return

	if guarding:
		amount *= 0.25
		stamina = maxf(0.0, stamina - amount)

		if stamina <= 0.0:
			guarding = false
	else:
		var was_crouching: bool = crouching
		var was_airborne: bool = not is_on_floor()

		attack_id += 1
		_disable_all_hitboxes()

		is_attacking = false
		current_attack = &""
		guarding = false
		crouching = false

		var direction: float = signf(global_position.x - attacker_position.x)

		if direction == 0.0:
			direction = -float(facing)

		knockback_velocity.x = direction * 180.0
		hit_stun_time = 0.25
		is_receiving_hit = true

		var hit_animation: StringName = ANIM_HIT

		if was_airborne:
			hit_animation = ANIM_JUMP_HIT
		elif was_crouching:
			hit_animation = ANIM_CROUCH_HIT

		_play_animation(hit_animation)

	health = maxf(0.0, health - amount)
	stats_changed.emit(self)

	if health <= 0.0:
		_knock_out()


# ============================================================
# KO
# ============================================================

func _knock_out() -> void:
	if is_out:
		return

	var was_crouching: bool = crouching
	var was_airborne: bool = not is_on_floor()

	is_out = true
	attack_id += 1

	_disable_all_hitboxes()

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	guarding = false
	crouching = false
	is_attacking = false
	is_receiving_hit = false
	current_attack = &""

	var ko_animation: StringName = ANIM_KO

	if was_airborne:
		ko_animation = ANIM_JUMP_KO
	elif was_crouching:
		ko_animation = ANIM_CROUCH_KO

	current_animation = &""

	if animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation(ko_animation):
			# Evitar que la animación de KO se repita.
			animated_sprite.sprite_frames.set_animation_loop(
				ko_animation,
				false
			)

			animated_sprite.play(ko_animation)
			current_animation = ko_animation
		else:
			push_warning(
				boxer_name + ": missing KO animation " + String(ko_animation)
			)

	knocked_out.emit(self)


# ============================================================
# ESTAMINA Y RETROCESO
# ============================================================

func _update_stamina(delta: float) -> void:
	if guarding:
		stamina = maxf(0.0, stamina - block_stamina_drain * delta)
		regen_wait = stamina_regen_delay

		if stamina <= 0.0:
			guarding = false

	elif regen_wait <= 0.0 and not is_attacking:
		stamina = minf(
			max_stamina,
			stamina + stamina_regen_rate * delta
		)


func _apply_knockback(delta: float) -> void:
	if absf(knockback_velocity.x) > 1.0:
		velocity.x = knockback_velocity.x
		knockback_velocity.x = move_toward(
			knockback_velocity.x,
			0.0,
			900.0 * delta
		)
	else:
		knockback_velocity.x = 0.0


# ============================================================
# REINICIO DE RONDA
# ============================================================

func reset_for_round() -> void:
	attack_id += 1
	_disable_all_hitboxes()

	health = max_health
	stamina = max_stamina

	guarding = false
	crouching = false
	is_out = false
	is_attacking = false
	is_receiving_hit = false

	regen_wait = 0.0
	hit_stun_time = 0.0
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO

	current_attack = &""
	current_animation = &""

	_update_facing()
	_update_collision_directions()
	_play_animation(ANIM_IDLE)
	stats_changed.emit(self)
	
func _on_animated_sprite_animation_finished() -> void:
	if not is_out:
		return

	var ko_animations: Array[StringName] = [
		ANIM_KO,
		ANIM_CROUCH_KO,
		ANIM_JUMP_KO
	]

	if current_animation not in ko_animations:
		return

	# Mantener visible el último fotograma de la caída.
	animated_sprite.pause()
