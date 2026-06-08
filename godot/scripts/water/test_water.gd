[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/water/advanced_water_physics.gd" id="1"]
[ext_resource type="Shader" path="res://shaders/water_wave.gdshader" id="2"]

[sub_resource type="PlaneMesh" id="PlaneMesh_1"]
size = Vector2(50, 50)
subdivide_width = 100
subdivide_depth = 100

[node name="WaterTest" type="Node3D"]

[node name="Water" type="MeshInstance3D" parent="."]
mesh = SubResource("PlaneMesh_1")
material_override = SubResource("ShaderMaterial_1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.5, -0.866025, 0, 0.866025, 0.5, 0, 15, 20)
current = true

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 10, 0)
light_energy = 1.5

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment")

[sub_resource type="Environment" id="Environment"]
background_mode = 2
sky_sky_material = SubResource("Sky")

[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("SkyMaterial")

[sub_resource type="SkyMaterial" id="SkyMaterial"]
sky_top_color = Color(0.2, 0.4, 0.8, 1)
sky_horizon_color = Color(0.5, 0.7, 1, 1)
ground_bottom_color = Color(0.1, 0.2, 0.3, 1)

[sub_resource type="ShaderMaterial" id="ShaderMaterial_1"]
shader = ExtResource("2")
shader_parameter/time = 0.0
shader_parameter/wave_amplitude = 0.5
shader_parameter/wave_frequency = 0.8
shader_parameter/wave_speed = 2.0
