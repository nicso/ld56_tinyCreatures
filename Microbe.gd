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

var gravity := 0.0

func _ready():
	# Create the visual representation
	_sprite = Sprite2D.new()
	_sprite.texture = _create_microbe_texture()
	_sprite.y_sort_enabled = true
	_sprite.z_index = 3
	add_child(_sprite)
	
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
	gravity = 0
	if not isGrounded :
		gravity = 150 * delta * distanceFromCenter
	gravity = clamp(gravity,0, gravityForce)
	velocity.y += gravity
	# Move the microbe
	move_and_slide()
	
	# Update pulsing animation
	_pulse_time += delta * 3.0
	var pulse_scale = 1.0 + sin(_pulse_time) * 0.1
	_sprite.scale = Vector2(pulse_scale, pulse_scale)

func apply_force(force: Vector2):
	_accumulated_force += force * (distanceFromCenter * 0.002) * acceleration

func _create_microbe_texture() -> Texture2D:
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	# Draw the main body with a softer gradient
	var center = Vector2(50, 50)
	var radius = 25
	
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos = Vector2(x, y)
			var distance = pos.length()
			if distance <= radius:
				var alpha = pow(1.0 - (distance / radius), 18) * color.a  # Squared falloff for softer edges
				var pixel_color = color
				pixel_color.a = alpha
				image.set_pixel(
					center.x + x,
					center.y + y,
					pixel_color
				)
	
	# Create and return the texture
	var texture = ImageTexture.create_from_image(image)
	return texture

func set_color(new_color: Color):
	color = new_color
	_sprite.texture = _create_microbe_texture()

func get_size() -> float:
	return base_size * scale.x
