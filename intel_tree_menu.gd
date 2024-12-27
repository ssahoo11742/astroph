extends Control

@onready var skill_buttons = [$laser_btn]  # Replace with your button nodes
var skills_data = {}  # Dictionary to hold the JSON data
const JSON_PATH = "res://data/skills.json"  # Path to the JSON file

func _ready():
	# Load the JSON file on start
	skills_data = load_json()
	for i in range(skill_buttons.size()):
		var button = skill_buttons[i]
	print("READY")



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

func save_json() -> void:
	# Save the updated JSON data back to the file
	var file = FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(skills_data))
		file.close()




func _on_laser_btn_button_down() -> void:
	var skill_name = "ID3"  # Define skill keys like "skill_0", "skill_1", etc.
	print("we come here")
	if skills_data.has(skill_name):
		skills_data[skill_name]["valid"] = 1  # Update "valid" to 1
		print("here lies the new data", skills_data)
		save_json()  # Save the changes to the file
		skill_buttons[0].modulate = Color.GOLD  # Change to gold color
		print("Acquired skill:", skill_name)
