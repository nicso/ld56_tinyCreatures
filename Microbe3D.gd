extends CharacterBody3D

class_name Microbe3D

# Movement properties
@export var mass: float = 1.0
@export var friction: float = 0.1
@export var acceleration: float = 200.0

# Visual properties
@export var base_size: float = 30.0
@export var size_variation: float = 1.5
@export var speed_variation: float = 1.5
@export var color: Color = Color(0, 0, 0, 1)
@export var gravityForce := 0.0 #200

# Internal variables
var _accumulated_force: Vector3 = Vector3.ZERO
var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _pulse_time: float = 0.0

var isGrounded := false
var distanceFromCenter := 0.0

var gravity := 0.0

func _ready():
	# Create the visual representation
	#_mesh_instance = MeshInstance3D.new()
	#_mesh_instance.mesh = _create_microbe_mesh()
	#add_child(_mesh_instance)
	
	# Create collision shape
	_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = base_size / 2
	_collision.shape = sphere_shape
	add_child(_collision)
	
	 #Add random variation to size
	#var size_scale = 1.0 + (randf() * 2 - 1) * size_variation
	#scale = Vector3(size_scale, size_scale, size_scale)
	
	acceleration = acceleration * speed_variation
	
	# Add random phase to pulsing
	_pulse_time = randf() * TAU

func _physics_process(delta):
	var s = 3.0
	scale = Vector3(distanceFromCenter/s, distanceFromCenter/s, distanceFromCenter/s)
	var minScale = 0.2
	var maxScale = 0.5
	
	scale = scale.clamp(Vector3(minScale,minScale,minScale),Vector3(maxScale,maxScale,maxScale))
	# Apply accumulated forces
	if _accumulated_force != Vector3.ZERO:
		# Ensure force is primarily applied on X and Z axes
		velocity += _accumulated_force * (delta / mass)
		_accumulated_force = Vector3.ZERO
	
	# Apply friction on X and Z axes only
	velocity.x = lerp(velocity.x, 0.0, friction * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * delta)
	
	isGrounded = move_and_slide()
	
	# Apply gravity only on Y axis
	if not isGrounded:
		gravity = 150 * delta * distanceFromCenter
		gravity = clamp(gravity, 0, gravityForce)
		velocity.y -= gravity
	else:
		velocity.y = 0  # Reset vertical velocity when grounded
	
	# Update pulsing animation
	#_pulse_time += delta * 3.0
	#var pulse_scale = 1.0 + sin(_pulse_time) * 0.1
	#_mesh_instance.scale = Vector3(pulse_scale, pulse_scale, pulse_scale)

func apply_force(force: Vector3):
	# Apply force with distance modifier
	_accumulated_force += force * (distanceFromCenter * 0.002) * acceleration

func _create_microbe_mesh() -> Mesh:
	var mesh = SphereMesh.new()
	mesh.radius = base_size / 2
	mesh.height = base_size
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	
	return mesh

func set_color(new_color: Color):
	color = new_color
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.mesh.material = material

func get_size() -> float:
	return base_size * scale.x
