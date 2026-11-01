extends Node3D

const ACTOR = preload("res://Actor.gd")
const PLAYER = preload("res://Player.gd")
const PROJECTILE = preload("res://Projectile.gd")
const HUMAN_MODELS := [
	"men/adventurer", "men/beach", "men/casual-2", "men/casual-hoodie", "men/farmer",
	"men/king", "men/punk", "men/spacesuit", "men/suit", "men/swat", "men/worker",
	"women/adventurer", "women/casual", "women/formal", "women/medieval", "women/punk",
	"women/scifi", "women/soldier", "women/suit", "women/witch", "women/worker"
]
const SOUND_PATHS := {
	"shoot": "res://audio/sword-swing.ogg",
	"pickup": "res://audio/pickup.ogg",
	"zombie-spawn": "res://audio/zombie-spawn.ogg",
	"zombie-death": "res://audio/zombie-death.ogg",
	"boss-smash": "res://audio/boss-smash.ogg",
	"gunshot": "res://audio/gunshot.ogg",
	"victory": "res://audio/victory.ogg",
	"death": "res://audio/player-death.ogg"
}

var player: CharacterBody3D
var actors: Array[Node] = []
var rocks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var state := "menu"
var stage := 0
var spawned := 0
var spawn_timer := 0.0
var clear_timer := -1.0
var boss_warning := -1.0
var next_boss_stage := 0
var boss_stage := false
var boss_defeated := false
var boss_count := 0
var score := 0
var best_score := 0
var cures := 0
var kills := 0
var lost := 0
var human_bag: Array[String] = []
var music: AudioStreamPlayer
var music_index := 0
var muted := false
var hud: Label
var hint: Label
var menu_panel: PanelContainer
var pause_panel: PanelContainer
var death_panel: PanelContainer
var touch_layer: Control
var touch_fire: Button
var touch_jump: Button

func _ready() -> void:
	rng.randomize()
	_create_world()
	_create_player()
	_create_ui()
	_create_music()
	var settings := ConfigFile.new()
	if settings.load("user://zombie_doctor.cfg") == OK:
		best_score = int(settings.get_value("scores", "best", 0))
		muted = bool(settings.get_value("audio", "muted", false))
	_show_menu()

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#cfe6f5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#d9f2ff")
	settings.ambient_light_energy = 1.15
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = not OS.has_feature("mobile")
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(84.0, 84.0)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("#68a950")
	grass.roughness = 1.0
	ground.material_override = grass
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(84.0, 1.0, 84.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	var cross_material := StandardMaterial3D.new()
	cross_material.albedo_color = Color("#e9f8dc")
	for size in [Vector3(2.8, 0.03, 0.55), Vector3(0.55, 0.03, 2.8)]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		bar.mesh = box
		bar.position.y = 0.03
		bar.material_override = cross_material
		add_child(bar)
	var rock_asset = load("res://assets/environment/arena-rock.glb")
	for index in range(18):
		for attempt in range(100):
			var angle := rng.randf_range(0.0, TAU)
			var distance := rng.randf_range(10.0, 32.0)
			var point := Vector2(cos(angle), sin(angle)) * distance
			var radius := rng.randf_range(0.85, 1.55)
			var clear := true
			for other in rocks:
				if point.distance_to(other.pos) < radius + float(other.radius) + 2.0:
					clear = false
					break
			if not clear:
				continue
			rocks.append({"pos": point, "radius": radius})
			var body := StaticBody3D.new()
			body.position = Vector3(point.x, 0.0, point.y)
			body.collision_layer = 1
			add_child(body)
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = radius
			cylinder.height = 2.0
			shape.shape = cylinder
			shape.position.y = 1.0
			body.add_child(shape)
			if rock_asset is PackedScene:
				var rock_model = rock_asset.instantiate()
				body.add_child(rock_model)
				rock_model.scale = Vector3.ONE * radius
				rock_model.rotation.y = rng.randf_range(0.0, TAU)
			break

func _create_player() -> void:
	player = PLAYER.new()
	add_child(player)
	player.position = Vector3.ZERO
	player.configure(self)

func _create_music() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.volume_db = -12.0
	music.finished.connect(_next_music)

func _next_music() -> void:
	if state == "menu":
		return
	music_index = (music_index + 1) % 2
	music.stream = load("res://audio/background-music%s.ogg" % ("-2" if music_index else ""))
	music.play()
	music.volume_db = -80.0 if muted else -12.0

func play_sound(sound_name: String, volume_db := -4.0, pitch := 1.0) -> void:
	if muted or not SOUND_PATHS.has(sound_name):
		return
	var stream = load(SOUND_PATHS[sound_name])
	if stream == null:
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = pitch
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	hud = Label.new()
	hud.position = Vector2(20.0, 16.0)
	hud.add_theme_font_size_override("font_size", 22)
	root.add_child(hud)
	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-250.0, 70.0)
	hint.custom_minimum_size.x = 500.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	root.add_child(hint)
	menu_panel = _make_panel(root, "ZOMBIE DOCTOR", "Cure the horde. One bite kills you.")
	_add_button(menu_panel, "START SHIFT", start_run)
	_add_button(menu_panel, "SOUND ON / OFF", toggle_mute)
	pause_panel = _make_panel(root, "PAUSED", "Esc to resume")
	_add_button(pause_panel, "RESUME", toggle_pause)
	_add_button(pause_panel, "RESTART", start_run)
	_add_button(pause_panel, "MENU", _show_menu)
	death_panel = _make_panel(root, "SHIFT OVER", "One bite is enough.")
	_add_button(death_panel, "RETRY", start_run)
	_add_button(death_panel, "MENU", _show_menu)
	touch_layer = Control.new()
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)
	touch_fire = Button.new()
	touch_fire.text = "FIRE"
	touch_fire.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_fire.position = Vector2(-130.0, -120.0)
	touch_fire.size = Vector2(100.0, 75.0)
	touch_fire.button_down.connect(func(): player.set_fire_held(true))
	touch_fire.button_up.connect(func(): player.set_fire_held(false))
	touch_layer.add_child(touch_fire)
	touch_jump = Button.new()
	touch_jump.text = "JUMP"
	touch_jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_jump.position = Vector2(-245.0, -100.0)
	touch_jump.size = Vector2(100.0, 55.0)
	touch_jump.pressed.connect(func(): player.queue_jump())
	touch_layer.add_child(touch_jump)
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-75.0, 18.0)
	pause_button.size = Vector2(55.0, 45.0)
	pause_button.pressed.connect(toggle_pause)
	touch_layer.add_child(pause_button)
	touch_layer.visible = DisplayServer.is_touchscreen_available()

func _make_panel(root: Control, title: String, subtitle: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180.0, -130.0)
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	var detail := Label.new()
	detail.text = subtitle
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	return panel

func _add_button(panel: PanelContainer, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 42.0
	panel.get_child(0).add_child(button)
	button.pressed.connect(callback)

func _show_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for actor in actors:
		if is_instance_valid(actor):
			actor.queue_free()
	actors.clear()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	menu_panel.visible = true
	pause_panel.visible = false
	death_panel.visible = false
	hud.visible = false
	hint.visible = false
	touch_layer.visible = false
	if music:
		music.stop()

func start_run() -> void:
	_show_menu()
	stage = 0
	spawned = 0
	score = 0
	cures = 0
	kills = 0
	lost = 0
	boss_count = 0
	next_boss_stage = rng.randi_range(3, 5)
	human_bag.clear()
	player.global_position = Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.pitch = 0.0
	player.camera.rotation.x = 0.0
	player.shot_cooldown = 0.0
	player.death_timer = -1.0
	state = "playing"
	menu_panel.visible = false
	hud.visible = true
	hint.visible = true
	touch_layer.visible = DisplayServer.is_touchscreen_available()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_VISIBLE
	music_index = rng.randi_range(0, 1)
	music.stream = load("res://audio/background-music%s.ogg" % ("-2" if music_index else ""))
	music.volume_db = -80.0 if muted else -12.0
	music.play()
	_start_stage()

func _start_stage() -> void:
	stage += 1
	spawned = 0
	spawn_timer = 1.4 if stage == 1 else 0.9
	clear_timer = -1.0
	boss_stage = stage == next_boss_stage
	boss_defeated = false
	if boss_stage:
		boss_count = mini(3, boss_count + 1)
		boss_warning = 4.0
		next_boss_stage = stage + rng.randi_range(3, 5)
		hint.text = "BOSS APPROACHING"
	else:
		boss_warning = -1.0
		hint.text = "STAGE %d" % stage

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	if clear_timer >= 0.0:
		clear_timer -= delta
		if clear_timer <= 0.0:
			_start_stage()
		_update_hud()
		return
	if boss_warning > 0.0:
		boss_warning -= delta
		if boss_warning <= 0.0:
			for count in range(boss_count):
				spawn_zombie("boss")
			hint.text = "BOSS ARRIVED"
	spawn_timer -= delta
	var alive := 0
	var bosses_alive := 0
	for actor in actors:
		if is_instance_valid(actor) and actor.faction == "zombie" and actor.death_timer < 0.0:
			alive += 1
			if actor.variant == "boss":
				bosses_alive += 1
	if boss_stage and boss_warning <= 0.0 and bosses_alive == 0:
		if not boss_defeated:
			boss_defeated = true
			for actor in actors:
				if is_instance_valid(actor) and actor.faction == "zombie" and actor.variant != "boss" and actor.death_timer < 0.0:
						actor.death_timer = 0.8
						actor.play_motion("Death")
	if boss_stage and not boss_defeated:
		if spawn_timer <= 0.0 and alive < max_alive():
			spawn_zombie()
			spawn_timer = maxf(1.0, 3.2 - (stage - 1) * 0.12)
	elif not boss_stage and spawned < stage_total() and alive < max_alive() and spawn_timer <= 0.0:
		spawn_zombie()
		spawned += 1
		spawn_timer = maxf(0.3, 1.05 - (stage - 1) * 0.07)
	if (boss_stage and boss_defeated and alive == 0) or (not boss_stage and spawned >= stage_total() and alive == 0):
		clear_timer = 5.0
		score += 100 + stage * 50 + survivor_count() * 25
		best_score = maxi(best_score, score)
		_save_settings()
		play_sound("victory")
		hint.text = "STAGE CLEAR — %d SURVIVORS" % survivor_count()
		var celebration_index := 0
		for actor in actors:
			if is_instance_valid(actor) and actor.faction == "human":
				var survivor = actor
				var delay := float(celebration_index) * 0.15
				get_tree().create_timer(delay).timeout.connect(func():
					if is_instance_valid(survivor) and state == "playing" and clear_timer >= 0.0:
						survivor.play_motion("Interact")
				)
				celebration_index += 1
	_update_hud()

func stage_total() -> int:
	return 12 + (stage - 1) * 8

func max_alive() -> int:
	return mini(24, 6 + int(ceil((stage - 1) * 2.5)))

func zombie_speed() -> float:
	return minf(4.6, 2.6 + (stage - 1) * 0.13)

func runner_chance() -> float:
	return minf(0.8, 0.16 + (stage - 1) * 0.08)

func survivor_count() -> int:
	var count := 0
	for actor in actors:
		if is_instance_valid(actor) and actor.faction == "human" and actor.death_timer < 0.0:
			count += 1
	return count

func spawn_zombie(forced_variant := "", at_position := Vector3.INF) -> void:
	var variant := forced_variant
	if variant.is_empty():
		var roll := rng.randf()
		variant = "green" if roll < 0.5 else ("blue" if roll < 0.8 else "half")
	var model_path := "res://assets/monsters/walking/zombie-%s.glb" % variant
	var model_height := 1.42
	if variant == "blue": model_height = 1.5
	if variant == "half": model_height = 1.0
	if variant == "boss":
		model_path = "res://assets/boss/big-arm.glb"
		model_height = 5.68
	var position_value := at_position
	if position_value == Vector3.INF:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(26.0, 30.0) if variant == "boss" else rng.randf_range(22.0, 36.0)
		position_value = Vector3(cos(angle) * distance, 0.05, sin(angle) * distance)
	var actor = ACTOR.new()
	add_child(actor)
	actor.global_position = position_value
	actor.configure(self, "zombie", variant, model_path, model_height)
	actors.append(actor)
	if variant != "boss":
		play_sound("zombie-spawn", -11.0)

func spawn_human(position_value: Vector3) -> void:
	if human_bag.is_empty():
		for outfit in HUMAN_MODELS:
			human_bag.append(outfit)
		human_bag.shuffle()
	var model_path := "res://assets/characters/%s.gltf" % human_bag.pop_back()
	var actor = ACTOR.new()
	add_child(actor)
	actor.global_position = position_value
	actor.configure(self, "human", "human", model_path, 1.86)
	actors.append(actor)

func fire_syringe(origin: Vector3, direction: Vector3) -> void:
	var shot = PROJECTILE.new()
	add_child(shot)
	shot.add_to_group("projectiles")
	shot.configure(self, "syringe", origin + direction * 0.6, direction * 42.0)
	play_sound("shoot", -9.0)

func spawn_slime(source: Node3D, aim_target: Node3D) -> void:
	if not is_instance_valid(aim_target): return
	var origin := source.global_position + Vector3.UP * 0.8
	var flat := aim_target.global_position - origin
	flat.y = 0.0
	var velocity_value := flat.normalized() * 10.0 + Vector3.UP * (6.0 + flat.length() * 0.22)
	var shot = PROJECTILE.new()
	add_child(shot)
	shot.add_to_group("projectiles")
	shot.configure(self, "slime", origin, velocity_value, source, aim_target)

func cure_zombie(actor: Node3D) -> void:
	if actor.variant == "boss" or actor.death_timer >= 0.0: return
	actor.set_meta("cured", true)
	actor.death_timer = 1.0
	actor.play_motion("Death")
	cures += 1
	score += 25
	play_sound("pickup")

func damage_actor(actor: Node3D, amount: int) -> void:
	if actor == player:
		kill_player("bite")
		return
	if actor.death_timer >= 0.0 or actor.rise_timer > 0.0 or actor.immunity_timer > 0.0:
		return
	actor.take_damage(amount)
	if actor.death_timer >= 0.0:
		if actor.faction == "human":
			lost += 1
			play_sound("death", -10.0)
		elif actor.variant == "boss":
			score += 10000
			kills += 1
			play_sound("zombie-death", 0.0, 0.42)
		else:
			score += 50
			kills += 1
			play_sound("zombie-death", -7.0)

func finish_actor_death(actor: Node3D) -> void:
	if not actors.has(actor): return
	var position_value := actor.global_position
	actors.erase(actor)
	if actor.faction == "human":
		spawn_zombie("", position_value)
	elif actor.has_meta("cured"):
		spawn_human(position_value)
	actor.queue_free()

func human_shoot(actor: Node3D, aim_target: Node3D) -> void:
	if is_instance_valid(aim_target) and has_sight(actor.global_position, aim_target.global_position):
		damage_actor(aim_target, 1)
	play_sound("gunshot", -9.0)

func boss_impact(boss: Node3D) -> void:
	play_sound("boss-smash", 0.0, 0.68)
	for actor in actors:
		if not is_instance_valid(actor) or actor.faction != "human" or actor.death_timer >= 0.0: continue
		if boss.global_position.distance_to(actor.global_position) < 6.2 and has_sight(boss.global_position, actor.global_position):
			damage_actor(actor, 2)
	if boss.global_position.distance_to(player.global_position) < 6.2 and has_sight(boss.global_position, player.global_position):
		kill_player("boss")

func kill_player(cause: String) -> void:
	if state != "playing": return
	state = "dead"
	player.death_timer = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_sound("death")
	best_score = maxi(best_score, score)
	_save_settings()
	death_panel.visible = true
	menu_panel.visible = false
	pause_panel.visible = false
	touch_layer.visible = false
	hint.text = "YOU DIED: %s" % cause.to_upper()

func toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_panel.visible = true
		touch_layer.visible = false
	elif state == "paused":
		state = "playing"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_VISIBLE
		pause_panel.visible = false
		touch_layer.visible = DisplayServer.is_touchscreen_available()

func toggle_mute() -> void:
	muted = not muted
	if music:
		music.volume_db = -80.0 if muted else -12.0
	_save_settings()

func _save_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("scores", "best", best_score)
	settings.set_value("audio", "muted", muted)
	settings.save("user://zombie_doctor.cfg")

func _update_hud() -> void:
	var remaining := maxi(0, stage_total() - spawned) + _alive_zombies()
	var wave_text := "BOSS" if boss_stage else "%d left" % remaining
	hud.text = "STAGE %d  •  %s\nSCORE %d  •  BEST %d\nCURED %d  •  KILLS %d  •  SURVIVORS %d  •  LOST %d" % [stage, wave_text, score, best_score, cures, kills, survivor_count(), lost]

func _alive_zombies() -> int:
	var count := 0
	for actor in actors:
		if is_instance_valid(actor) and actor.faction == "zombie" and actor.death_timer < 0.0:
			count += 1
	return count

func is_playing() -> bool:
	return state == "playing"

func pick_target(actor: Node3D) -> Node3D:
	var candidate: Node3D
	var best_distance := INF
	if actor.faction == "human":
		for other in actors:
			if is_instance_valid(other) and other.faction == "zombie" and other.variant == "boss" and other.death_timer < 0.0 and other.rise_timer <= 0.0:
				return other
		for other in actors:
			if not is_instance_valid(other) or other.faction != "zombie" or other.death_timer >= 0.0 or other.rise_timer > 0.0: continue
			var distance := actor.global_position.distance_squared_to(other.global_position)
			if distance < best_distance:
				best_distance = distance
				candidate = other
	else:
		if state == "playing":
			candidate = player
			best_distance = actor.global_position.distance_squared_to(player.global_position)
		for other in actors:
			if not is_instance_valid(other) or other.faction != "human" or other.death_timer >= 0.0: continue
			var distance := actor.global_position.distance_squared_to(other.global_position)
			if distance < best_distance:
				best_distance = distance
				candidate = other
	return candidate

func has_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP)
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func steer_around_rocks(position_value: Vector3, direction: Vector3, radius: float, bias: float) -> Vector3:
	var current := Vector2(position_value.x, position_value.z)
	var desired := Vector2(direction.x, direction.z)
	for rock in rocks:
		var center: Vector2 = rock.pos
		var to_center := center - current
		var forward := to_center.dot(desired)
		if forward <= 0.0 or forward > 4.0: continue
		var side := absf(to_center.cross(desired))
		if side >= float(rock.radius) + radius + 0.4: continue
		var tangent := Vector2(-to_center.y, to_center.x).normalized() * bias
		var blended := (desired * 0.35 + tangent * 0.9 - to_center.normalized() * 0.35).normalized()
		return Vector3(blended.x, 0.0, blended.y)
	return direction
