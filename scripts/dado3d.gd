class_name Dado3D
extends SubViewportContainer
## Il dado originale della marcia (modello del modulo), mostrato in un riquadro 3D: rotola e si ferma
## con la faccia uscita verso l'alto.

var vp: SubViewport
var dado: MeshInstance3D
var cam: Camera3D
var tw: Tween
## Correzione per marcia: tutti i dadi riempiono il riquadro allo stesso modo (misurato con tests/misura_dadi.gd).
const GRANDEZZA := {1: 1.51, 2: 1.07, 3: 1.6, 4: 1.38, 5: 1.42, 6: 1.24}

func _init(lato := 150) -> void:
	stretch = true
	custom_minimum_size = Vector2(lato, lato)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(lato * 2, lato * 2)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	cam = Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 6.4, 2.3)
	vp.add_child(cam)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-60, 25, 0)
	vp.add_child(luce)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.8
	env.environment = e
	vp.add_child(env)
	dado = MeshInstance3D.new()
	vp.add_child(dado)

func _ready() -> void:
	cam.look_at(Vector3(0, 0.2, 0), Vector3.UP)

static func rotazione(marcia: int, faccia: int) -> Quaternion:
	var f: Array = Dati.DADI[marcia][faccia]
	# le rotazioni del modulo sono in convenzione Unity (mano sinistra): x resta, y e z cambiano segno
	var b := Basis.from_euler(Vector3(deg_to_rad(f[1]), -deg_to_rad(f[2]), -deg_to_rad(f[3])), EULER_ORDER_YXZ)
	return b.get_rotation_quaternion()

## rotola: il dado entra da destra (lo sposta chi lo contiene) e gira come una ruota verso sinistra.
func mostra(marcia: int, faccia: int, durata := 0.6, rotola := false) -> void:
	var nome: String = Dati.MODELLI_DADI[marcia]
	dado.mesh = load("res://assets/modelli/%s.obj" % nome)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/modelli/%s.jpg" % nome)
	m.roughness = 0.4
	dado.material_override = m
	var bb := dado.mesh.get_aabb()
	dado.scale = Vector3.ONE * (1.05 / max(0.1, bb.get_longest_axis_size() * 0.5)) * float(GRANDEZZA.get(marcia, 1.0))
	# il dado a sei facce si legge dritto guardandolo dall'altro lato
	cam.position.z = -2.3 if marcia == 2 else 2.3
	cam.look_at(Vector3(0, 0.2, 0), Vector3.UP)
	var q := rotazione(marcia, faccia)
	if tw != null and tw.is_valid():
		tw.kill()
	if durata <= 0.0:
		dado.quaternion = q
		return
	if rotola:
		# qualche giro attorno all'asse verso la camera (rotola verso sinistra) e si posa sulla faccia uscita
		var giri := 2 + randi() % 2
		tw = create_tween()
		tw.tween_method(func(t: float):
			var resto := 1.0 - t
			var spin := Quaternion(Vector3(0, 0, 1), resto * TAU * giri)
			dado.quaternion = spin * q
			dado.position = Vector3(0, abs(sin(t * PI * 3.0)) * 0.35 * resto, 0), 0.0, 1.0, durata).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		await tw.finished
		dado.quaternion = q
		dado.position = Vector3.ZERO
		return
	dado.quaternion = Quaternion(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), randf() * TAU)
	dado.position = Vector3(0, 1.2, 0)
	tw = create_tween()
	tw.tween_property(dado, "quaternion", q, durata).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dado, "position", Vector3.ZERO, durata).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
