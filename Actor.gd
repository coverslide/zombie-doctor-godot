extends CharacterBody3D

var game: Node3D
var faction := "zombie"
var variant := "green"
var hp := 1
var max_hp := 1
var damage := 1
var speed := 2.6
var radius := 0.37
var attack_range := 1.35
var cooldown := 0.0
var attack_timer := -1.0
var rise_timer := 0.8
var death_timer := -1.0
var immunity_timer := 0.0
var attack_lock_timer := 0.0
var ranged := false
var ammo := 0
var target: Node3D
var model: Node3D
var animation_player: AnimationPlayer
var current_motion := ""
var move_bias := 1.0

func configure(owner_game: Node3D, side: String, type_name: String, model_path: String, model_height: float) -> void:
	game = owner_game
	faction = side
	variant = type_name
	move_bias = -1.0 if get_instance_id() % 2 == 0 else 1.0
	if faction == "human":
		hp = 2
		max_hp = 2
		speed = 4.15
		radius = 0.34
		attack_range = 1.45
		immunity_timer = 1.0
		attack_lock_timer = 1.0
		ranged = randf() < 0.1
		ammo = 8 if ranged else 0
	elif variant == "boss":
		hp = 50 + max(0, game.stage - 1) * 15
		max_hp = hp
		speed = 3.5
		radius = 1.5
		attack_range = 6.2
		rise_timer = 1.8
	elif variant == "blue":
		hp = 2
		max_hp = 2
		damage = 2
		radius = 0.39
		speed = game.zombie_speed() * 0.94
	elif variant == "half":
		hp = 1
		max_hp = 1
		radius = 0.31
		speed = game.zombie_speed() * 1.16
		attack_range = 20.0
		cooldown = randf_range(1.5, 4.5)
	else:
		speed = game.zombie_speed()
	if faction == "zombie" and variant != "boss" and randf() < game.runner_chance():
		speed *= 1.28
	collision_layer = 4
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = max(radius * 2.0 + 0.1, model_height * 0.85)
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	body_shape.position.y = capsule.height * 0.5
	add_child(body_shape)
	var resource = load(model_path)
	if resource is PackedScene:
		model = resource.instantiate() as Node3D
		add_child(model)
		_normalize_model(model_height)
		animation_player = _find_animation_player(model)
		if animation_player:
			play_motion("Death", true)
	if faction == "human":
		game.play_sound("pickup")
	elif variant == "boss":
		game.play_sound("zombie-spawn", 0.0, 0.42)

func _physics_process(delta: float) -> void:
	if not game or not game.is_playing():
		return
	if death_timer >= 0.0:
		death_timer -= delta
		if death_timer <= 0.0:
			game.finish_actor_death(self)
		return
	if rise_timer > 0.0:
		rise_timer -= delta
		if rise_timer <= 0.0:
			play_motion("Idle")
		return
	cooldown = maxf(0.0, cooldown - delta)
	immunity_timer = maxf(0.0, immunity_timer - delta)
	attack_lock_timer = maxf(0.0, attack_lock_timer - delta)
	if attack_timer >= 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_resolve_attack()
		return
	target = game.pick_target(self)
	if not is_instance_valid(target):
		play_motion("Idle")
		return
	var flat := Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z)
	var distance := flat.length()
	if distance > 0.01:
		look_at(global_position + flat, Vector3.UP)
	var visible_target = game.has_sight(global_position, target.global_position)
	if faction == "human":
		_update_human(flat, distance, visible_target, delta)
	elif variant == "half":
		if distance <= 20.0 and visible_target and cooldown <= 0.0:
			game.spawn_slime(self, target)
			cooldown = 3.0 + randf() * 0.8
			play_motion("HitReact")
		elif distance > 15.0 or not visible_target:
			_move_toward(flat, delta)
		else:
			play_motion("Idle")
	elif distance <= attack_range and visible_target and cooldown <= 0.0:
		attack_timer = 0.55 if variant == "boss" else 0.42
		cooldown = 3.6 if variant == "boss" else (1.35 if variant == "blue" else 0.65)
		play_motion("Punch")
	elif distance > attack_range * 0.8 or not visible_target:
		_move_toward(flat, delta)
	else:
		play_motion("Idle")

func _update_human(flat: Vector3, distance: float, visible_target: bool, delta: float) -> void:
	if ranged and ammo > 0:
		if distance <= 18.0 and visible_target and cooldown <= 0.0 and attack_lock_timer <= 0.0:
			ammo -= 1
			cooldown = 1.0
			game.human_shoot(self, target)
			play_motion("Gun_Shoot")
		elif distance > 12.0 or not visible_target:
			_move_toward(flat, delta)
		else:
			play_motion("Idle_Gun")
		return
	if distance <= attack_range and visible_target and cooldown <= 0.0 and attack_lock_timer <= 0.0:
		attack_timer = 0.2
		cooldown = 0.78
		play_motion("Punch_Left")
	elif distance > attack_range * 0.85 or not visible_target:
		_move_toward(flat, delta)
	else:
		play_motion("Idle")

func _move_toward(flat: Vector3, delta: float) -> void:
	if flat.length_squared() < 0.01:
		return
	var direction: Vector3 = game.steer_around_rocks(global_position, flat.normalized(), radius, move_bias)
	velocity = direction * speed
	velocity.y = -1.0
	move_and_slide()
	var offset := Vector2(global_position.x, global_position.z)
	if offset.length() > 42.0 - radius:
		offset = offset.normalized() * (42.0 - radius)
		global_position.x = offset.x
		global_position.z = offset.y
	play_motion("Run")

func _resolve_attack() -> void:
	attack_timer = -1.0
	if not is_instance_valid(target) or target.get("death_timer") >= 0.0:
		return
	var distance := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if not game.has_sight(global_position, target.global_position):
		return
	if faction == "human":
		if distance <= attack_range * 1.3:
			game.damage_actor(target, 1)
	elif variant == "boss":
		game.boss_impact(self)
	elif distance <= attack_range * 1.3:
		game.damage_actor(target, damage)

func take_damage(amount: int) -> void:
	if death_timer >= 0.0 or rise_timer > 0.0 or immunity_timer > 0.0:
		return
	hp -= amount
	if hp <= 0:
		death_timer = 1.0
		play_motion("Death")
	else:
		play_motion("Hit")

func play_motion(token: String, backwards := false) -> void:
	if not animation_player:
		return
	var chosen := ""
	for name in animation_player.get_animation_list():
		if name.to_lower().contains(token.to_lower()):
			chosen = name
			break
	if chosen.is_empty():
		return
	if current_motion == chosen and animation_player.is_playing() and not backwards:
		return
	current_motion = chosen
	if backwards:
		animation_player.play_backwards(chosen)
	else:
		animation_player.play(chosen)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _normalize_model(height: float) -> void:
	var bounds := AABB()
	var found := false
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		var box: AABB = mesh.get_aabb()
		var local_transform: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		for corner in range(8):
			var point := local_transform * box.get_endpoint(corner)
			if not found:
				bounds = AABB(point, Vector3.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	if not found or bounds.size.y < 0.01:
		return
	var scale_factor := height / bounds.size.y
	model.scale = Vector3.ONE * scale_factor
	model.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5), -bounds.position.y, -(bounds.position.z + bounds.size.z * 0.5)) * scale_factor
