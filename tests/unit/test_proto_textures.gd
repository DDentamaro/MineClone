extends TestCase


func test_mulberry32_come_javascript() -> void:
	# Primi valori di mulberry32(7) calcolati con Node.
	var r := ProtoTextures.Mulberry32.new(7)
	var got := [r.next(), r.next(), r.next()]
	var seq: Array = [0.011704753153026104, 0.06195825757458806, 0.97690763277933]
	for i in 3:
		check(absf(float(got[i]) - float(seq[i])) < 1e-15, "valore %d: %s" % [i, got[i]])


func test_atlante_identico() -> void:
	var b := ProtoTextures.atlas_bytes()
	check_eq(WorldFixture.sha256_hex(b), str(RenderFixture.manifest()["files"]["atlas.rgba"]["sha256"]), "atlante 256x32")


func test_ciuffo_erba_identico() -> void:
	var b := ProtoTextures.leaf_bytes()
	check_eq(WorldFixture.sha256_hex(b), str(RenderFixture.manifest()["files"]["leaf.rgba"]["sha256"]), "ciuffo 32x16")
