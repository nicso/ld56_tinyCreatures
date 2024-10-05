extends Node3D

class_name MicrobeController3D

# Properties for blob behavior
@export var max_separation_distance: float = 100.0
@export var cohesion_strength: float = 0.5
@export var separation_strength: float = 1.0
@export var alignment_strength: float = 0.3
@export var max_speed: float = 200.0
@export var steering_force: float = 150.0

# Movement properties
@export var acceleration: float = 1000.0
@export var deceleration: float = 0.85
@export var max_move_speed: float = 300.0

# Visual connection properties
@export var connection_distance: float = 80.0
@export var connection_color: Color = Color(0.2, 0.8, 0.3, 0.3)
@export var connection_width: float = 0.2
@export var connection_fade_distance: float = 70.0

# Internal variables
var microbes: Array = []
var connections_node: Node3D
var connection_lines: Dictionary = {}
var movement_velocity: Vector3 = Vector3.ZERO

var numOfMicrobeFloating := 0
var gravity := 0.0
@export var gravityForce := 0.0 #1000

func _ready():
	for child in get_children():
		if child.has_method("apply_force"):
			microbes.append(child)
	
	#connections_node = Node3D.new()
	#connections_node.name = "Connections"
	#add_child(connections_node)
#
#func _process(_delta):
	#update_connections()

func update_connections():
	# Clear old connections
	for line in connection_lines.values():
		line.queue_free()
	connection_lines.clear()
	
	# Create new connections
	for i in range(microbes.size()):
		for j in range(i + 1, microbes.size()):
			var microbe1 = microbes[i]
			var microbe2 = microbes[j]
			var distance = microbe1.position.distance_to(microbe2.position)
			
			if distance <= connection_distance:
				var connection_id = str(i) + "_" + str(j)
				var connection = _create_connection_mesh(microbe1.position, microbe2.position, distance)
				connections_node.add_child(connection)
				connection_lines[connection_id] = connection

func _create_connection_mesh(start: Vector3, end: Vector3, distance: float) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = connection_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = connection_color
	
	# Calculate opacity based on distance
	var opacity = 1.0 - (distance / connection_fade_distance)
	opacity = clamp(opacity, 0.0, 1.0)
	material.albedo_color.a = connection_color.a * opacity
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()
	
	return mesh_instance

func _physics_process(delta):
	if microbes.size() == 0:
		return
	
	# Get input direction (X and Z axes only)
	var input_direction = Vector3.ZERO
	input_direction.x = Input.get_axis("ui_left", "ui_right")
	input_direction.z = Input.get_axis("ui_up", "ui_down")
	
	# Normalize only X and Z components
	if input_direction.length_squared() > 0:
		input_direction = input_direction.normalized()
	
	# Apply smooth acceleration on X and Z only
	if input_direction != Vector3.ZERO:
		movement_velocity.x += input_direction.x * acceleration * delta
		movement_velocity.z += input_direction.z * acceleration * delta
		
		# Limit horizontal speed
		var horizontal_velocity = Vector2(movement_velocity.x, movement_velocity.z)
		if horizontal_velocity.length() > max_move_speed:
			horizontal_velocity = horizontal_velocity.normalized() * max_move_speed
			movement_velocity.x = horizontal_velocity.x
			movement_velocity.z = horizontal_velocity.y
	else:
		# Apply smooth deceleration on X and Z only
		movement_velocity.x = lerp(movement_velocity.x, 0.0, 1.0 - pow(deceleration, delta * 60))
		movement_velocity.z = lerp(movement_velocity.z, 0.0, 1.0 - pow(deceleration, delta * 60))
	
	# Calculate center of mass
	var center = Vector3.ZERO
	for microbe in microbes:
		center += microbe.position
	center /= microbes.size()
	
	numOfMicrobeFloating = 0
	# Update each microbe
	for microbe in microbes:
		var forces = Vector3.ZERO
		
		# Basic flocking behavior
		forces += _calculate_cohesion(microbe, center) * cohesion_strength
		forces += _calculate_separation(microbe) * separation_strength
		forces += _calculate_alignment(microbe) * alignment_strength
		
		# Add movement velocity as a force
		forces += movement_velocity
		
		if not microbe.isGrounded:
			numOfMicrobeFloating += 1
		
		# Calculate distance from center on X-Z plane only
		var horizontal_offset = Vector2(
			microbe.position.x - (center.x + input_direction.x),
			microbe.position.z - (center.z + input_direction.z)
		)
		microbe.distanceFromCenter = lerp(microbe.distanceFromCenter, horizontal_offset.length(), delta)
		
		
		# Apply gravity
		gravity = 1600 * (numOfMicrobeFloating / (microbes.size() / 2))
		gravity = clamp(gravity, 0, gravityForce)
		forces.y -= gravity
		
		# Apply combined forces to microbe
		microbe.apply_force(forces)
		
		# Limit speed (separately for horizontal and vertical movement)
		var horizontal_velocity = Vector2(microbe.velocity.x, microbe.velocity.z)
		if horizontal_velocity.length() > max_speed:
			horizontal_velocity = horizontal_velocity.normalized() * max_speed
			microbe.velocity.x = horizontal_velocity.x
			microbe.velocity.z = horizontal_velocity.y

func _calculate_cohesion(microbe: CharacterBody3D, center: Vector3) -> Vector3:
	var desired_velocity = center - microbe.position
	if not microbe.move_and_slide():
		desired_velocity = (center - microbe.position) * 0.2
	return (desired_velocity - microbe.velocity) * steering_force

func _calculate_separation(microbe: CharacterBody3D) -> Vector3:
	var separation_force = Vector3.ZERO
	
	for other in microbes:
		if other == microbe:
			continue
			
		var distance = microbe.position.distance_to(other.position)
		if distance < max_separation_distance:
			var repulsion = microbe.position - other.position
			separation_force += repulsion.normalized() / max(distance * 0.5, 0.1)
	
	return separation_force

func _calculate_alignment(microbe: CharacterBody3D) -> Vector3:
	var average_velocity = Vector3.ZERO
	
	for other in microbes:
		if other == microbe:
			continue
		average_velocity += other.velocity
	
	if microbes.size() > 1:
		average_velocity /= (microbes.size() - 1)
		return (average_velocity - microbe.velocity) * steering_force
	return Vector3.ZERO
