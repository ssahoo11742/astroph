extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$SubViewportContainer/SubViewport/mini/player/Camera2D.zoom = Vector2(0.75,0.75)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
