extends Node3D

var game: Node3D
var projectile_kind := "syringe"
var source: Node3D
var velocity := Vector3.ZERO
var age := 0.0
var target: Node3D
var mesh: MeshInstance3D

func configure(owner_game: Node3D, kind: String, origin: Vector3, initial_velocity: Vector3, owner_actor: Node3D = null, aim_target: Node3D = null) -> void:
	game = owner_game
	projectile_kind = kind
	source = owner_actor
	target = aim_target
	global_position = origin
	velocity = initial_velocity
	mesh = MeshInstance3D.new()
	if kind == "syringe":
		var asset = load("res://assets/syringe.glb")
		if asset is PackedScene:
			var visual = asset.instantiate()
			visual.scale = Vector3.ONE * 0.15
			add_child(visual)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.24
		sphere.height = 0.48
		mesh.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#416d1c")
		material.emission_enabled = true
		material.emission = Color("#173b0f")
		mesh.material_override = material
		add_child(mesh)

func _physics_process(delta: float) -> void:
	if not game or not game.is_playing():
		return
	age += delta
	if age > (2.4 if projectile_kind == "syringe" else 4.0):
		queue_free()
		return
	var previous := global_position
	velocity.y -= (6.4 if projectile_kind == "syringe" else 16.0) * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)
	if global_position.y <= 0.0 or Vector2(global_position.x, global_position.z).length() > 44.0:
		queue_free()
		return
	var query := PhysicsRayQueryParameters3D.create(previous, global_position)
	query.collision_mask = 1
	if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	if projectile_kind == "syringe":
		for actor in game.actors:
			if not is_instance_valid(actor) or actor.faction != "zombie" or actor.death_timer >= 0.0 or actor.rise_timer > 0.0:
				continue
			if _segment_hits(previous, global_position, actor.global_position + Vector3.UP * 0.85, actor.radius + 0.55):
				if actor.variant == "boss":
					velocity *= -0.08
				else:
					game.cure_zombie(actor)
					queue_free()
				return
	else:
		if game.is_playing() and _segment_hits(previous, global_position, game.player.global_position + Vector3.UP, 0.65):
			game.kill_player("slime")
			queue_free()
			return
		for actor in game.actors:
			if not is_instance_valid(actor) or actor.faction != "human" or actor.death_timer >= 0.0 or actor.immunity_timer > 0.0:
				continue
			if _segment_hits(previous, global_position, actor.global_position + Vector3.UP, actor.radius + 0.5):
				game.damage_actor(actor, 2)
				queue_free()
				return

func _segment_hits(start: Vector3, end: Vector3, center: Vector3, hit_radius: float) -> bool:
	var segment := end - start
	var length_squared := segment.length_squared()
	var progress := 0.0 if length_squared < 0.0001 else clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	return (start + segment * progress).distance_squared_to(center) <= hit_radius * hit_radius
