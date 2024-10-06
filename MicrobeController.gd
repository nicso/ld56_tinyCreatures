extends Node2D

class_name MicrobeController

# Properties for blob behavior
@export var max_separation_distance: float = 100.0
@export var cohesion_strength: float = 0.5
@export var separation_strength: float = 1.0
@export var alignment_strength: float = 0.3
@export var max_speed: float = 200.0
@export var steering_force: float = 150.0

# Movement properties
@export var acceleration: float = 1000.0  # How quickly the blob accelerates
@export var deceleration: float = 0.85    # How quickly the blob slows down (0-1)
@export var max_move_speed: float = 300.0 # Maximum movement speed from input

# Visual connection properties
@export var connection_distance: float = 80.0
@export var connection_color: Color = Color(0.2, 0.8, 0.3, 0.3)
@export var connection_width: float = 2.0
@export var connection_fade_distance: float = 70.0
var center := Vector2.ZERO
# Internal variables
var microbes: Array = []
var connections_node: Node2D
var connection_lines: Dictionary = {}
var movement_velocity: Vector2 = Vector2.ZERO  # Current movement velocity

var numOfMicrobeFloating := 0
var input_direction
@export var microbes_number := 60
@export var max_distance_from_center := 300



func spawn_microbe():
	var microbe = preload("res://microbe.tscn").instantiate()
	if microbes.size() > 10 :
		var part = microbe.get_child(2) as GPUParticles2D
		part.emitting = false
	microbe.position = center
	add_child(microbe)
	for child in get_children():
			if child.has_method("apply_force"):
				if not microbes.has(child):
					microbes.append(child)
	connections_node = Node2D.new()
	connections_node.name = "Connections"
	add_child(connections_node)

func _ready():
	for n in microbes_number:
		spawn_microbe()

func _process(_delta):
	if Input.is_action_just_pressed("spawn"):
		spawn_microbe()
	if Input.is_action_pressed("regroup"):
		cohesion_strength = 0.3
		max_separation_distance = 20
	else:
		cohesion_strength = 0.15
		max_separation_distance = 90
	update_connections()
	print(microbes.size())

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
				var line = Line2D.new()
				
				# Set line properties
				line.width = connection_width
				line.default_color = connection_color
				line.z_index = 10
				line.y_sort_enabled = true
				
				# Calculate opacity based on distance
				var opacity = 1.0 - (distance / connection_fade_distance)
				opacity = clamp(opacity, 0.0, 1.0)
				line.default_color.a = connection_color.a * opacity
				
				
				# Add subtle curve to make it more organic
				var points = _calculate_curved_line(microbe1.position, microbe2.position)
				line.points = points
				
				connections_node.add_child(line)
				connection_lines[connection_id] = line

func _calculate_curved_line(start: Vector2, end: Vector2) -> Array:
	var mid_point = (start + end) / 2
	var perpendicular = (end - start).rotated(PI/2).normalized()
	var distance = start.distance_to(end)
	var curve_strength = distance * 0.2
	mid_point += perpendicular * curve_strength * (sin(Time.get_ticks_msec() * 0.001) * 0.5)
	return [start, mid_point, end]

func _physics_process(delta):
	if microbes.size() == 0:
		return
	
	# Get input direction
	input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Apply smooth acceleration
	if input_direction != Vector2.ZERO:
		movement_velocity += input_direction * acceleration * delta
		movement_velocity = movement_velocity.limit_length(max_move_speed)
	else:
		# Apply smooth deceleration
		movement_velocity = movement_velocity.lerp(Vector2.ZERO, 1.0 - pow(deceleration, delta * 60))
	
	# Calculate center of mass
	center = Vector2.ZERO
	for microbe in microbes:
		center += microbe.position
	center /= microbes.size()
	
	numOfMicrobeFloating = 0
	# Update each microbe
	for microbe in microbes:
		var forces = Vector2.ZERO
		
		# Basic flocking behavior
		forces += _calculate_cohesion(microbe, center) * cohesion_strength
		forces += _calculate_separation(microbe) * separation_strength
		forces += _calculate_alignment(microbe) * alignment_strength
		
		# Add movement velocity as a force
		forces += movement_velocity
		#forces.x += (randf() - 0.5) * 3000.0
		#forces.y += (randf() - 0.5) * 3000.0
		
		if not microbe.isGrounded:
			numOfMicrobeFloating += 1
		
		microbe.distanceFromCenter = microbe.position.distance_to(center+(input_direction*3)) 
		if microbe.distanceFromCenter > max_distance_from_center:
			killMicrobe(microbe)
		
		# Apply combined forces to microbe
		microbe.apply_force(forces)
		
		
		
		# Limit speed
		if microbe.velocity.length() > max_speed:
			microbe.velocity = microbe.velocity.normalized() * max_speed

func _calculate_cohesion(microbe: CharacterBody2D, center: Vector2) -> Vector2:
	var desired_velocity = center - microbe.position
	if not microbe.move_and_slide():
		desired_velocity.x = (center.x - microbe.position.x) * 0.4 + (randf() - 0.5) * 40
		desired_velocity.y = (center.y - microbe.position.y) * 0.9 + (randf() - 0.5) * 40
		desired_velocity += input_direction * 50
	return (desired_velocity - microbe.velocity) * steering_force

func _calculate_separation(microbe: CharacterBody2D) -> Vector2:
	var separation_force = Vector2.ZERO
	
	for other in microbes:
		if other == microbe:
			continue
			
		var distance = microbe.position.distance_to(other.position)
		if distance < max_separation_distance:
			var repulsion = microbe.position - other.position
			separation_force += repulsion.normalized() / max(distance * 0.5, 0.1)
		
	return separation_force

func _calculate_alignment(microbe: CharacterBody2D) -> Vector2:
	var average_velocity = Vector2.ZERO
	
	for other in microbes:
		if other == microbe:
			continue
		average_velocity += other.velocity
	
	if microbes.size() > 1:
		average_velocity /= (microbes.size() - 1)
		return (average_velocity - microbe.velocity) * steering_force
	return Vector2.ZERO

func killMicrobe(microbe: CharacterBody2D):
	microbes.remove_at(microbes.rfind(microbe))
	microbe.queue_free()
	
