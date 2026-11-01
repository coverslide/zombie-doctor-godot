extends CharacterBody3D

var game: Node3D
var camera: Camera3D
var pitch := 0.0
var shot_cooldown := 0.0
var left_touch := -1
var right_touch := -1
var left_origin := Vector2.ZERO
var touch_move := Vector2.ZERO
var fire_held := false
var jump_queued := false
var death_timer := -1.0

func configure(owner_game: Node3D) -> void:
	game = owner_game
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 74.0
	camera.current = true
	add_child(camera)
	var slingshot = load("res://assets/slingshot.glb")
	if slingshot is PackedScene:
		var weapon = slingshot.instantiate()
		camera.add_child(weapon)
		weapon.position = Vector3(0.35, -0.38, -0.7)
		weapon.scale = Vector3.ONE * 0.24

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative * 0.0022)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			game.toggle_pause()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_F:
			jump_queued = true
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var half := get_viewport().get_visible_rect().size.x * 0.5
		if touch_event.pressed:
			if touch_event.position.x < half and left_touch < 0:
				left_touch = touch_event.index
				left_origin = touch_event.position
			elif right_touch < 0:
				right_touch = touch_event.index
		else:
			if touch_event.index == left_touch:
				left_touch = -1
				touch_move = Vector2.ZERO
			if touch_event.index == right_touch:
				right_touch = -1
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == left_touch:
			touch_move = (drag_event.position - left_origin).limit_length(75.0) / 75.0
		elif drag_event.index == right_touch:
			_rotate_view(drag_event.relative * 0.008)

func _rotate_view(delta: Vector2) -> void:
	rotation.y -= delta.x
	pitch = clampf(pitch - delta.y, -1.43, 1.43)
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not game or not game.is_playing():
		return
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	var move_input := Vector2.ZERO
	move_input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move_input.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	move_input += touch_move
	if Input.get_connected_joypads().size() > 0:
		move_input += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if look.length() > 0.16:
			_rotate_view(look * delta * 2.4)
		if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
			jump_queued = true
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var desired := (right * move_input.x + forward * -move_input.y) * 5.4
	velocity.x = move_toward(velocity.x, desired.x, 55.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 55.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
		if jump_queued:
			velocity.y = 8.4
	else:
		velocity.y -= 24.0 * delta
	jump_queued = false
	move_and_slide()
	var radial := Vector2(global_position.x, global_position.z)
	if radial.length() > 41.64:
		radial = radial.normalized() * 41.64
		global_position.x = radial.x
		global_position.z = radial.y
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) or fire_held or (Input.get_connected_joypads().size() > 0 and Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3):
		if shot_cooldown <= 0.0:
			shot_cooldown = 0.48
			game.fire_syringe(camera.global_position, -camera.global_transform.basis.z)

func set_fire_held(value: bool) -> void:
	fire_held = value

func queue_jump() -> void:
	jump_queued = true
