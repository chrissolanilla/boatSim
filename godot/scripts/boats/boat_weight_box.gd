extends Resource
class_name BoatWeightBox

@export var name: String = "Weight Box"
@export var enabled: bool = true
@export_range(0.0, 5000.0) var mass: float = 0.0
@export var local_position: Vector3 = Vector3.ZERO
