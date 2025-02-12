extends CharacterBody3D

# Player nodes
@onready var eyes: Node3D = $Neck/Head/Eyes
@onready var head: Node3D = $Neck/Head
@onready var neck: Node3D = $Neck
@onready var standing_col_shape: CollisionShape3D = $standing_col_shape
@onready var crouching_col_shape: CollisionShape3D = $crouching_col_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera: Camera3D = $Neck/Head/Eyes/Camera3D

# Speed Vars
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var crouch_speed = 3.0
var current_speed = 5.0

# States
var walking = false
var sprinting = false
var crouching = false
var freelooking = false
var sliding = false

# Slide Vars
@export var slide_timer = 0.0
@export var slide_timer_max = 1.0
@export var slide_speed = 10.0
var slide_vector = Vector2.ZERO

# Input Vars
var direction := Vector3.ZERO
@export var mouse_sens = 0.2

# Movement Vars
@export var jump_vel = 4.5
@export var freelook_enabled = true
const FREELOOK_TILT = -6
const lerp_speed = 10.0
var crouching_depth = -0.5

# Headbob Vars
@export var bob_enabled = true
const SPRINT_BOB_SPEED = 22.0
const WALK_BOB_SPEED = 14.0
const CROUCH_BOB_SPEED = 10.0
const CROUCH_BOB_INTENSITY = 0.05
const SPRINT_BOB_INTENSITY = 0.2
const WALK_BOB_INTENSITY = 0.1

var bob_vector = Vector2.ZERO
var bob_index = 0.0
var current_bob = 0.0

# Functions
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse Look
	if event is InputEventMouseMotion:
		if freelooking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y  * mouse_sens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	# Get movement input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_vel
		sliding = false

	# Handle movement states.
	if Input.is_action_pressed("crouch") and is_on_floor():
		# Crouch
		current_speed = crouch_speed
		head.position.y = lerp(head.position.y, 0.0 + crouching_depth, delta * lerp_speed)
		standing_col_shape.disabled = true
		crouching_col_shape.disabled = false
		
		if sprinting and input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			freelooking = true
			# print('Begin slide.')

		walking = false
		sprinting = false
		crouching = true
	elif !ray_cast_3d.is_colliding():
		# Standing
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		standing_col_shape.disabled = false
		crouching_col_shape.disabled = true
		crouching = false
		if Input.is_action_pressed("sprint") and is_on_floor():
			# Sprinting
			current_speed = sprint_speed
			sprinting = true
			walking = false
			crouching = false
		else:
			# Walking
			current_speed = walk_speed
			walking = true
			sprinting = false
			crouching = false

	# Handle Free-look
	if  freelook_enabled:
		if Input.is_action_pressed("freelook") or sliding:
			freelooking = true
			camera.rotation.z = deg_to_rad(neck.rotation.y * FREELOOK_TILT)
		else:
			freelooking = false
			neck.rotation.y = lerp(neck.rotation.y, 0.0, lerp_speed * delta)
			camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)

	# Handle slide
	if sliding:
		slide_timer -= delta
		# print(slide_timer)
		if slide_timer < 0:
			sliding = false
			freelooking = false
			# print('End Slide')
		elif Input.is_action_just_released("crouch"):
			sliding = false
			freelooking = false

	# Handle Headbob
	match true:
		sprinting:
			current_bob = SPRINT_BOB_INTENSITY
			bob_index += delta * SPRINT_BOB_SPEED
		walking:
			current_bob = WALK_BOB_INTENSITY
			bob_index += delta * WALK_BOB_SPEED
		crouching:
			current_bob = CROUCH_BOB_INTENSITY
			bob_index += delta * CROUCH_BOB_SPEED
		_:
			current_bob = 0.0
	
	if is_on_floor() and !sliding and input_dir != Vector2.ZERO:
		bob_vector.y = sin(bob_index)
		bob_vector.x = sin(bob_index/2) * 0.5
		eyes.position.y = lerp(eyes.position.y, bob_vector.y * (current_bob / 2), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, bob_vector.x * current_bob, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if sliding:
			velocity.x = direction.x * (slide_timer + 0.1) * slide_speed
			velocity.z = direction.z * (slide_timer + 0.1) * slide_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
