extends CharacterBody2D

const SPEED = 100.0
const MOUNT_ANIM = "jump_mount_"  # Define the mount animation name
const TRANSLATE_DISTANCE = 200  # Distance to translate the player after mounting
const JUMP_DURATION = 0.5  # Total time for the jump
const JUMP_HEIGHT = 50  # Maximum height of the jump
const PHYSICS_LAYER = 0  # Physics layer to check collisions

@onready var sprite = $AnimatedSprite2D  # Reference to AnimatedSprite2D
@onready var dialog_manager = get_node("/root/DialogManager")  # Reference to the DialogManager
@onready var transport_menu_scene = preload("res://scenes/menu.tscn")
@onready var transport_tree_scene = preload("res://scenes/transport_tree_menu.tscn")


var menu_instance = null  # To track the menu instance
var menu_triggered = false  # Ensure the menu is triggered only once
var last_direction = "down"  # Default idle direction

var is_mounting = false  # Track if the player is mounting
var animation_finished = false  # Track if the animation has finished
var button_released = false  # Track if the spacebar has been released
var lerp_target = null  # Target position for lerping
var jump_elapsed = 0.0  # Time elapsed during the jump
var jump_start_position = Vector2.ZERO  # Starting position for the jump
var attack_tree_in = false
const JSON_PATH = "res://skills.json"  # Path to the JSON file
var skills_data = {}  # Dictionary to hold the JSON data

func load_json() -> Dictionary:
	# Load and parse the JSON file
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if file:
		var data = file.get_as_text()
		file.close()
		var json = JSON.new()  # Create an instance of the JSON class
		var parse_result = json.parse(data)  # Parse the data
		print("returning this", json.get_data())
		return json.get_data()  # Use `get_data()` to access the parsed dictionary
	return {}  # Return an empty dictionary if the file doesn't exist or is invalid
	
	
func _ready() -> void:
	# Connect the animation_finished signal
	sprite.animation_finished.connect(on_animation_finished)
	
func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO

	# Handle jump with curve if active
	if lerp_target != null:
		jump_elapsed += delta
		if jump_elapsed >= JUMP_DURATION:
			global_position = lerp_target  # Snap to target when done
			lerp_target = null
		else:
			# Compute horizontal lerp
			var t = jump_elapsed / JUMP_DURATION
			var horizontal_position = jump_start_position.lerp(lerp_target, t)
			
			# Compute vertical arc using a parabola (-4x^2 + 4x)
			var arc_height = JUMP_HEIGHT * (-4 * t * t + 4 * t)
			var new_position = horizontal_position + Vector2(0, -arc_height)
			
			# Check for collisions
			var motion = new_position - global_position
			var collision = move_and_collide(motion)
			
			if collision:
				# Stop the jump if a collision occurs
				lerp_target = null
			return  # Skip regular input handling while jumping

	# Get input direction
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")
	skills_data = load_json()
	if skills_data["laser"]["valid"] == 1:
		if Input.is_action_pressed("ui_accept"):  # Spacebar is held
			if not is_mounting:
				sprite.play(MOUNT_ANIM + last_direction)  # Play the mount animation
				is_mounting = true
				animation_finished = false  # Reset animation state
				button_released = false  # Reset button release state
		elif is_mounting:  # Spacebar is released
			button_released = true  # Mark that the button has been released
			check_jump_condition()  # Check if both conditions are met

	if not is_mounting:
		if direction != Vector2.ZERO:
			velocity = direction.normalized() * SPEED
			play_movement_animation(direction)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			play_idle_animation()  # Switch to idle animation when no input is detected

	move_and_slide()

# Function to play movement animations based on direction
func play_movement_animation(direction: Vector2) -> void:
	if direction.y < 0:
		sprite.play("run_up")
		last_direction = "up"
	elif direction.y > 0:
		sprite.play("run_down")
		last_direction = "down"
	elif direction.x < 0:
		sprite.play("run_left")
		last_direction = "left"
	elif direction.x > 0:
		sprite.play("run_right")
		last_direction = "right"

# Function to play idle animations based on last direction
func play_idle_animation() -> void:
	sprite.play("idle_" + last_direction)

# Signal handler for animation_finished
func on_animation_finished() -> void:
	animation_finished = true  # Mark the animation as finished
	check_jump_condition()  # Check if both conditions are met

# Function to check if the jump should occur
func check_jump_condition() -> void:
	if animation_finished and button_released:
		start_jump_to_last_direction()
		reset_mounting_state()

# Function to set up the jump
func start_jump_to_last_direction() -> void:
	jump_start_position = global_position  # Record the starting position
	match last_direction:
		"up":
			lerp_target = global_position + Vector2(0, -TRANSLATE_DISTANCE)
		"down":
			lerp_target = global_position + Vector2(0, TRANSLATE_DISTANCE)
		"left":
			lerp_target = global_position + Vector2(-TRANSLATE_DISTANCE, 0)
		"right":
			lerp_target = global_position + Vector2(TRANSLATE_DISTANCE, 0)
	jump_elapsed = 0.0  # Reset jump timer

# Function to reset mounting-related states
func reset_mounting_state() -> void:
	is_mounting = false
	animation_finished = false
	button_released = false

func _input(event: InputEvent) -> void:
	# Close menu on escape key
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		
	if event.is_action_pressed("interact") and attack_tree_in:
		open_transport_menu()


func open_transport_menu() -> void:
	if menu_instance == null:
		menu_instance = transport_tree_scene.instantiate()
		add_child(menu_instance)

func open_laser_menu() -> void:
	if menu_instance == null:
		menu_instance = transport_menu_scene.instantiate()
		add_child(menu_instance)

func close_menu() -> void:
	if menu_instance != null:
		menu_instance.queue_free()
		menu_instance = null
		
func _on_transport_menu_zone_body_entered(body: Node2D) -> void:
	if body == self: 
		if not menu_triggered:
			menu_triggered = true
			open_laser_menu()


func _on_attack_tree_area_body_entered(body: Node2D) -> void:
	if body == self:
		attack_tree_in = true


func _on_attack_tree_area_body_exited(body: Node2D) -> void:
	if body == self:
		attack_tree_in = false
