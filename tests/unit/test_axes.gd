extends TestCase
## Convenzioni di coordinate (D-004).


func test_cella_da_punto() -> void:
	check_eq(Axes.world_to_cell(Vector3(96.5, 28.0, 96.5)), Vector3i(96, 28, 96), "spawn")
	check_eq(Axes.world_to_cell(Vector3(-0.1, 0.0, 0.99)), Vector3i(-1, 0, 0), "floor negativo")
	check_eq(Axes.cell_center(Vector3i(1, 2, 3)), Vector3(1.5, 2.5, 3.5), "centro")


func test_forward_godot() -> void:
	check_eq(Axes.FORWARD, Vector3(0, 0, -1), "forward -Z")
	check_eq(Axes.UP.cross(Vector3.RIGHT), Vector3(0, 0, -1), "sistema destrorso")
