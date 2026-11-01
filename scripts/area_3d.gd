extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

# check later for sheep entering the area
func _on_body_entered(body: Node3D):
	if body is CharacterBody3D:
		print("Body entered")
