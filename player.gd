extends CharacterBody2D

const SPEED = 300.0
const TRANSFORM_COOLDOWN = 1.0

enum CharacterForm { FORM_W, FORM_GA }

var current_form = CharacterForm.FORM_W
var can_transform = true
var transform_timer = 0.0

@onready var vector_character = $VectorCharacter
@onready var transform_particles = $TransformEffect

func _ready():
	print("Player ready - instance: ", get_instance_id())
	update_character_visuals()

func _physics_process(delta):
	# Movement
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * SPEED
	move_and_slide()
	
	# Transform input (press T)
	if Input.is_action_just_pressed("transform") and can_transform:
		transform_character()

	# Cooldown timer
	if not can_transform:
		transform_timer -= delta
		if transform_timer <= 0:
			can_transform = true

func transform_character():
	if not can_transform:
		return
	
	can_transform = false
	transform_timer = TRANSFORM_COOLDOWN
	
	# Play particle effect
	if transform_particles:
		transform_particles.emitting = true
	
	# Animate scale pulse
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale up and down morph effect
	tween.tween_property(vector_character, "scale", Vector2(1.3, 1.3), 0.5)
	tween.tween_property(vector_character, "scale", Vector2(0.7, 0.7), 0.5).set_delay(0.5)
	tween.tween_property(vector_character, "scale", Vector2(1.1, 1.1), 0.5).set_delay(1.0)
	tween.tween_property(vector_character, "scale", Vector2(1.0, 1.0), 0.5).set_delay(1.5)
	
	# Rotate during morph
	tween.tween_property(vector_character, "rotation", PI * 2, 2.0)
	
	# Fade out and in
	tween.tween_property(vector_character, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_property(vector_character, "modulate", Color.WHITE, 1.0).set_delay(2.0)
	
	# Switch form halfway through animation
	await get_tree().create_timer(1.5).timeout
	
	# Switch form
	match current_form:
		CharacterForm.FORM_W:
			current_form = CharacterForm.FORM_GA
		CharacterForm.FORM_GA:
			current_form = CharacterForm.FORM_W
	
	# Wait for animation to finish
	await tween.finished
	
	# Reset transform cooldown timer starts already running
	can_transform = false
	transform_timer = TRANSFORM_COOLDOWN
	
	# Switch form
	match current_form:
		CharacterForm.FORM_W:
			current_form = CharacterForm.FORM_GA
			print("Switched to FORM_GA")
		CharacterForm.FORM_GA:
			current_form = CharacterForm.FORM_W
			print("Switched to FORM_W")
	
	update_character_visuals()
	print("Visuals updated")
	
	# Optional: play particle effect
	if transform_particles:
		transform_particles.emitting = true

func set_form_value(value: float):
	$VectorCharacter.set_form(value)

func update_character_visuals():
	# Clear ALL drawing-related nodes
	for child in vector_character.get_children():
		child.call_deferred("queue_free")
	
	# Small delay to ensure deletion
	await get_tree().process_frame
	
	match current_form:
		CharacterForm.FORM_W:
			draw_ga_character()
		CharacterForm.FORM_GA:
			draw_w_character()
	for child in vector_character.get_children():
		child.queue_free()
	
func draw_w_character():
	# Draw a stylized 'W' using vector lines
	var line_color = Color.WHITE
	var line_width = 4.0
	
	# Create points for 'W'
	var points = PackedVector2Array([
		Vector2(0, 20),  # bottom left
		Vector2(8, 0),   # top left peak
		Vector2(16, 15), # middle dip
		Vector2(24, 0),  # top right peak
		Vector2(32, 20)  # bottom right
	])
	
	draw_line_path(points, line_color, line_width)


func draw_ga_character():
	# Draw 'が' (GA) - simplified vector representation
	var line_color = Color(0.3, 0.8, 0.5)  # soft green
	var line_width = 4.0
	
	# Main 'か' shape (simplified)
	var ka_points = PackedVector2Array([
		Vector2(10, 20),  # bottom
		Vector2(10, 5),   # vertical line up
		Vector2(25, 5),   # horizontal top
		Vector2(10, 12),  # crossbar
		Vector2(25, 20)   # diagonal finish
	])
	draw_line_path(ka_points, line_color, line_width)
	

func draw_line_path(points: PackedVector2Array, color: Color, width: float):
	var line = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.antialiased = true
	vector_character.add_child(line)
