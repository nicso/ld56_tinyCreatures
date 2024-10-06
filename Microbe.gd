extends CharacterBody2D

class_name Microbe

# Movement properties
@export var mass: float = 1.0
@export var friction: float = 0.1
@export var acceleration: float = 200.0

# Visual properties
@export var base_size: float = 30.0  # Reduced from 10.0
@export var size_variation: float = 1.5  # Reduced from 2.0
@export var speed_variation: float = 1.5  # Reduced from 2.0
@export var color: Color = Color(0, 0, 0,1 )  # More transparent
@export var gravityForce := 0 #200

# Internal variables
var _accumulated_force: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _collision: CollisionShape2D
var _pulse_time: float = 0.0

var isGrounded := false
var distanceFromCenter := 0.0


func _ready():
	
	# Create collision shape
	_collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = base_size / 2
	_collision.shape = circle_shape
	add_child(_collision)
	
	# Add random variation to size
	var size_scale = 1.0 + (randf() * 2 - 1) * size_variation
	scale = Vector2(size_scale, size_scale)
	
	acceleration = acceleration * speed_variation
	
	# Add random phase to pulsing
	_pulse_time = randf() * TAU

func _physics_process(delta):
	# Apply accumulated forces
	if _accumulated_force != Vector2.ZERO:
		velocity += _accumulated_force * (delta / mass)
		_accumulated_force = Vector2.ZERO
	
	# Apply friction
	velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	
	isGrounded = move_and_slide()
	# Move the microbe
	move_and_slide()
	

func apply_force(force: Vector2):
	_accumulated_force += force * (distanceFromCenter * 0.0025) * acceleration


func get_size() -> float:
	return base_size * scale.x
