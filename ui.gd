extends Label
var first_names = ["Alden", "Beatrice", "Cora", "Dion"]
var last_names = ["Smith", "Jones", "Williams"]
var rng = RandomNumberGenerator.new()
var time = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$".".text = "123123123"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time += delta
	if time > 1:
		$".".text = first_names[rng.randi() % first_names.size()] + " " + last_names[rng.randi() % last_names.size()]
		time = 0
	
