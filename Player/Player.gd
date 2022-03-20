extends KinematicBody

const ACCEL_DEFAULT: float = 7.0
const ACCEL_AIR: float = 1.0
var accel: float = ACCEL_DEFAULT
const SPEED_DEFAULT: float = 7.0
const SPEED_ON_STAIRS: float = 5.0
var speed: float = SPEED_DEFAULT
var gravity: float = 9.8
var jump: float = 5.0
const stairs_feeling_coefficient: float = 2.0

var mouse_sense: float = 0.1
var snap: Vector3 = Vector3.ZERO

var direction: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var gravity_vec: Vector3 = Vector3.ZERO
var movement: Vector3 = Vector3.ZERO

onready var body = $Body
onready var head = $Body/Head
onready var camera = $Body/Head/Camera
onready var head_position: Vector3 = head.translation
onready var body_euler_y = body.global_transform.basis.get_euler().y

var head_offset: Vector3 = Vector3.ZERO
var head_lerp_coefficient: float = 0.0
var is_step: bool = false

const WALL_MARGIN: float = 0.001
const STEP_HEIGHT_DEFAULT: Vector3 = Vector3(0, 0.6, 0)
const STEP_MAX_SLOPE_DEGREE: float = 0.0
const STEP_CHECK_COUNT: int = 2

var step_check_height: Vector3 = STEP_HEIGHT_DEFAULT / STEP_CHECK_COUNT

var camera_target_position : Vector3 = Vector3()


func _ready():
	#hides the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera_target_position = head.translation
	camera.set_as_toplevel(true)
	camera.set_physics_interpolated(false)
	camera.translation = camera_target_position
	camera.rotation = head.rotation

func _process(delta: float) -> void:
	# Find the current interpolated transform of the target
	var tr : Transform = head.get_global_transform_interpolated()

	# Provide some delayed smoothed lerping towards the target position 
	camera_target_position = lerp(camera_target_position, tr.origin, delta * speed * stairs_feeling_coefficient)

	#camera.translation = camera_target_position
	camera.translation.x = tr.origin.x
	camera.translation.y = camera_target_position.y
	camera.translation.z = tr.origin.z
	camera.rotation.x = head.rotation.x
	camera.rotation.y = body.rotation.y + body_euler_y

func _input(event):
	#get mouse input for camera rotation
	if event is InputEventMouseMotion:
		body.rotate_y(deg2rad(-event.relative.x * mouse_sense))
		head.rotate_x(deg2rad(-event.relative.y * mouse_sense))
		head.rotation.x = clamp(head.rotation.x, deg2rad(-89), deg2rad(89))

func _physics_process(delta):
	is_step = false
	
	#get keyboard input
	direction = Vector3.ZERO
	var h_rot: float = body.global_transform.basis.get_euler().y
	var f_input: float = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var h_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()

	#jumping and gravity
	if is_on_floor():
		snap = -get_floor_normal()
		accel = ACCEL_DEFAULT
		gravity_vec = Vector3.ZERO
	else:
		snap = Vector3.DOWN
		accel = ACCEL_AIR
		gravity_vec += Vector3.DOWN * gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		snap = Vector3.ZERO
		gravity_vec = Vector3.UP * jump

	#make it move
	velocity = velocity.linear_interpolate(direction * speed, accel * delta)
	
	if gravity_vec.y >= 0:
		for i in range(STEP_CHECK_COUNT):
			var test_motion_result: PhysicsTestMotionResult = PhysicsTestMotionResult.new()
			
			var step_height: Vector3 = STEP_HEIGHT_DEFAULT - i * step_check_height
			var transform3d: Transform = global_transform
			var motion: Vector3 = step_height
			var is_player_collided: bool = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
			
			if test_motion_result.collision_normal.y < 0:
				continue
				
			if not is_player_collided:
				transform3d.origin += step_height
				motion = velocity * delta
				is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
				if not is_player_collided:
					transform3d.origin += motion
					motion = -step_height
					is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
					if is_player_collided:
						if test_motion_result.collision_normal.angle_to(Vector3.UP) <= deg2rad(STEP_MAX_SLOPE_DEGREE):
							head_offset = -test_motion_result.motion_remainder
							is_step = true
							global_transform.origin += -test_motion_result.motion_remainder
							break
				else:
					var wall_collision_normal: Vector3 = test_motion_result.collision_normal

					transform3d.origin += test_motion_result.collision_normal * WALL_MARGIN
					motion = (velocity * delta).slide(wall_collision_normal)
					is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
					if not is_player_collided:
						transform3d.origin += motion
						motion = -step_height
						is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
						if is_player_collided:
							if test_motion_result.collision_normal.angle_to(Vector3.UP) <= deg2rad(STEP_MAX_SLOPE_DEGREE):
								head_offset = -test_motion_result.motion_remainder
								is_step = true
								global_transform.origin += -test_motion_result.motion_remainder
								break
			else:
				var wall_collision_normal: Vector3 = test_motion_result.collision_normal
				transform3d.origin += test_motion_result.collision_normal * WALL_MARGIN
				motion = step_height
				is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
				if not is_player_collided:
					transform3d.origin += step_height
					motion = (velocity * delta).slide(wall_collision_normal)
					is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
					if not is_player_collided:
						transform3d.origin += motion
						motion = -step_height
						is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
						if is_player_collided:
							if test_motion_result.collision_normal.angle_to(Vector3.UP) <= deg2rad(STEP_MAX_SLOPE_DEGREE):
								head_offset = -test_motion_result.motion_remainder
								is_step = true
								global_transform.origin += -test_motion_result.motion_remainder
								break

	var is_falling: bool = false
	
	if not is_step and is_on_floor():
		var test_motion_result: PhysicsTestMotionResult = PhysicsTestMotionResult.new()
		var step_height: Vector3 = STEP_HEIGHT_DEFAULT
		var transform3d: Transform = global_transform
		var motion: Vector3 = velocity * delta
		var is_player_collided: bool = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
			
		if not is_player_collided:
			transform3d.origin += motion
			motion = -step_height
			is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
			if is_player_collided:
				if test_motion_result.collision_normal.angle_to(Vector3.UP) <= deg2rad(STEP_MAX_SLOPE_DEGREE):
					head_offset = test_motion_result.motion
					is_step = true
					global_transform.origin += test_motion_result.motion
			else:
				is_falling = true
		else:
			if test_motion_result.collision_normal.y == 0:
				var wall_collision_normal: Vector3 = test_motion_result.collision_normal
				transform3d.origin += test_motion_result.collision_normal * WALL_MARGIN
				motion = (velocity * delta).slide(wall_collision_normal)
				is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
				if not is_player_collided:
					transform3d.origin += motion
					motion = -step_height
					is_player_collided = PhysicsServer.body_test_motion(self.get_rid(), transform3d, motion, false, test_motion_result)
					if is_player_collided:
						if test_motion_result.collision_normal.angle_to(Vector3.UP) <= deg2rad(STEP_MAX_SLOPE_DEGREE):
							head_offset = test_motion_result.motion
							is_step = true
							global_transform.origin += test_motion_result.motion
					else:
						is_falling = true
		
	if is_step:
		speed = SPEED_ON_STAIRS
		head.translation -= head_offset
		head_lerp_coefficient = clamp(velocity.length() * 0.4, 2, speed * 0.4)
	else:
		head_offset = head_offset.linear_interpolate(Vector3.ZERO, accel * delta * head_lerp_coefficient)
		head.translation = head_position - head_offset
		
		if abs(head_offset.y) <= 0.01:
			speed = SPEED_DEFAULT
	
	movement = velocity + gravity_vec

	if is_falling:
		snap = Vector3.ZERO
		
# warning-ignore:return_value_discarded
	move_and_slide_with_snap(movement, snap, Vector3.UP, false, 4, deg2rad(46), false)
