extends CharacterBody2D

const SPEED = 100.0
const MOUNT_ANIM = "jump_mount_"  # Define the mount animation name
const TRANSLATE_DISTANCE = 200  # Distance to translate the player after mounting
const JUMP_DURATION = 0.5  # Total time for the jump
const JUMP_HEIGHT = 50  # Maximum height of the jump
const PHYSICS_LAYER = 0  # Physics layer to check collisions
const autopickup = ["tile074"]
@onready var sprite = $AnimatedSprite2D  # Reference to AnimatedSprite2D
@onready var dialog_manager = get_node("/root/DialogManager")  # Reference to the DialogManager
@onready var transport_menu_scene = preload("res://scenes/menu.tscn")
@onready var int_menu_scene = preload("res://scenes/int_menu.tscn")
@onready var transport_tree_scene = preload("res://scenes/transport_tree_menu.tscn")
@onready var intel_tree_scene = preload("res://scenes/intel_tree_menu.tscn")
@onready var msg_scene = preload("res://scenes/msg.tscn")
@onready var inv_scene = preload("res://scenes/inv.tscn")


var menu_instance = null  # To track the menu instance
var menu_triggered = false  # Ensure the meFnu is triggered only once
var last_direction = "down"  # Default idle direction

var is_mounting = false  # Track if the player is mounting
var animation_finished = false  # Track if the animation has finished
var button_released = false  # Track if the spacebar has been released
var lerp_target = null  # Target position for lerping
var jump_elapsed = 0.0  # Time elapsed during the jump
var jump_start_position = Vector2.ZERO  # Starting position for the jump
var attack_tree_in = false
var intel_tree_in = false
const JSON_PATH_SKILLS = "res://data/skills.json"  # Path to the JSON file
const JSON_PATH_INV = "res://data/inv.json" 
var skills_data = {}  # Dictionary to hold the JSON data

var msg_important_in = 0
var msg_tutorial_in = 0

func add_to_inv(name, sprite, amount):
	var inv = load_json(JSON_PATH_INV)
	print("inved here")
	for i in range(1,26):
		if(inv["inv"][str(i)]["name"] == "NULL"):
			print("not null")
			inv["inv"][str(i)]["name"] = name
			inv["inv"][str(i)]["sprite"] = sprite
			inv["inv"][str(i)]["amount"] = amount
			break
	
	save_json(JSON_PATH_INV, inv)

func save_json(PATH, data) -> void:
	# Save the updated JSON data back to the file
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		
func load_json(PATH) -> Dictionary:
	# Load and parse the JSON file
	var file = FileAccess.open(PATH, FileAccess.READ)
	if file:
		var data = file.get_as_text()
		file.close()
		var json = JSON.new()  # Create an instance of the JSON class
		var parse_result = json.parse(data)  # Parse the data
		return json.get_data()  # Use `get_data()` to access the parsed dictionary
	return {}  # Return an empty dictionary if the file doesn't exist or is invalid
	
	
func _ready() -> void:
	# Connect the animation_finished signal
	sprite.animation_finished.connect(on_animation_finished)
	
	
	var game_node = get_node("/root/Game")  # Update path if different

	# Initialize a list to store Area2D nodes
	var area2d_nodes = []

	# Recursively collect all Area2D nodes
	_find_area2d_nodes(game_node, area2d_nodes)

	# Print or use the collected Area2D nodes
	for area in area2d_nodes:
		var sprite = area.get_parent().get_node("Sprite2D")
		if sprite:
			if sprite.texture.resource_path.get_file() in autopickup:
				print("connected")
				#area.connect("body_entered", Callable(self, "_autopickup"))

func _autopickup():
	print("green")
	Input.action_press("interact")
 
func _find_area2d_nodes(node: Node, area2d_list: Array):
	if node is Area2D:
		area2d_list.append(node)
	for child in node.get_children():
		_find_area2d_nodes(child, area2d_list)
	
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
	skills_data = load_json(JSON_PATH_SKILLS)
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
	
	if event.is_action_pressed("inv"):
		# Instantiate the menu scene
		menu_instance = inv_scene.instantiate()
		
		# Add it to the current scene
		add_child(menu_instance)
		
		var inventory_data = load_json(JSON_PATH_INV)["inv"]
		
		# Iterate over all children in the menu instance
		for index in range(menu_instance.get_child_count()):
			var button = menu_instance.get_child(index)
			
			# Check if the child is a Button (or TextureButton)
			if button is Button:
				var icon = "res://assets/sprites/icons/icons/" + inventory_data[str(index)]["sprite"] + ".png"
				var icon_texture = load(icon)  # Assumes the images are named 0.png, 1.png, etc.
				button.icon = icon_texture
				# Define the function name dynamically
				var function_name = "_on_"+inventory_data[str(index)]["name"]

				# Check if the function exists
				if has_method(function_name):
					button.connect("pressed", Callable(self, function_name))
				else:
					print("Function", function_name, "does not exist. Skipping connection.")

	if event.is_action_pressed("interact"):
		if attack_tree_in:
			open_transport_menu()
		elif intel_tree_in:
			if menu_instance == null:
				menu_instance = intel_tree_scene.instantiate()
				add_child(menu_instance)
		elif msg_important_in:
			var msg_important_node = get_node("../msg_important") # Adjust the path if needed
			if msg_important_node:
				msg_important_node.get_parent().remove_child(msg_important_node)
				msg_important_node.queue_free()
				add_to_inv("msg_important", "tile074", 1)
		
		elif msg_tutorial_in:
			var msg_tutorial_node = get_node("../msg_tutorial") # Adjust the path if needed
			if msg_tutorial_node:
				msg_tutorial_node.get_parent().remove_child(msg_tutorial_node)
				msg_tutorial_node.queue_free()
				add_to_inv("msg_tutorial", "tile074", 1)
				
func _on_msg_tutorial():
	close_menu()
	if menu_instance == null:
		menu_instance = msg_scene.instantiate()
		add_child(menu_instance)
	
	var label = menu_instance.get_node("Label")
	if label and label is Label:
		label.text = "This is a test item to test your auto-pick up! "
	else:
		print("Label node not found or not of type Label")

func _on_msg_important():
	close_menu()
	if menu_instance == null:
		menu_instance = msg_scene.instantiate()
		add_child(menu_instance)
	
	var label = menu_instance.get_node("Label")
	if label and label is Label:
		label.text = "54 6F 20 66 69 78 20 79 6F 75 72 20 71 75 61 6E 74 75 6D 20 74 65 6C 65 70 6F 72 74 65 72 2C 20 79 6F 75 20 68 61 76 65 20 74 6F 20 65 78 70 6C 6F 72 65 20 74 68 65 20 77 6F 72 6C 64 21 20 54 61 6C 6B 20 74 6F 20 61 6C 6C 20 74 68 72 65 65 20 56 6F 6C 75 6D 65 74 72 69 63 20 44 69 73 70 6C 61 79 20 53 74 61 74 75 65 73 20 74 6F 20 75 6E 6C 6F 63 6B 20 74 68 65 20 77 61 79 20 6F 75 74 21 0A 0A 49 74 20 77 6F 75 6C 64 20 62 65 20 6D 75 63 68 20 65 61 73 69 65 72 20 74 6F 20 72 65 61 64 20 74 68 69 73 20 69 66 20 79 6F 75 20 68 61 64 20 61 20 46 65 65 64 66 6F 72 77 61 72 64 20 4E 65 75 72 61 6C 20 4E 65 74 77 6F 72 6B 20 28 46 46 4E 29 20 74 6F 20 74 72 61 6E 73 6C 61 74 65 20 66 6F 72 20 79 6F 75 20 3A 29 "
	else:
		print("Label node not found or not of type Label")

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


func _on_msg_tutorial_area_body_entered(body: Node2D) -> void:
	if body == self:
		msg_tutorial_in = true


func _on_msg_tutorial_area_body_exited(body: Node2D) -> void:
	if body == self:
		if load_json(JSON_PATH_SKILLS)["ID3"]["valid"]:
			collect("../msg_tutorial", "msg_tutorial", "tile074.png", 1)
		else:
			msg_important_in = true

func collect(path, name, tile, amount):
	var node = get_node(path)
	if node:
		node.get_parent().remove_child(node)
		node.queue_free()
		add_to_inv(name,tile,amount)

func _on_msg_important_area_body_entered(body: Node2D) -> void:
	if body == self:
		if load_json(JSON_PATH_SKILLS)["ID3"]["valid"]:
			collect("../msg_important", "msg_important", "tile074.png", 1)
		else:
			msg_important_in = true

func _on_msg_important_area_body_exited(body: Node2D) -> void:
	if body == self:
		msg_important_in = false


func _on_intel_tree_area_body_entered(body: Node2D) -> void:
	if body == self:
		intel_tree_in = true
	


func _on_intel_tree_area_body_exited(body: Node2D) -> void:
	if body == self:
		intel_tree_in = false

var intzn = 1
func _on_int_menu_zone_body_entered(body: Node2D) -> void:
	if body == self: 
		if intzn:
			intzn = 0
			if menu_instance == null:
				menu_instance = int_menu_scene.instantiate()
				add_child(menu_instance)
