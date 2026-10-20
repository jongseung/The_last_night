class_name LevelBuilder
extends RefCounted
## 데이터(사각형·텍스처·종류)만으로 스테이지 지오메트리를 만드는 도우미.
##
## 벽은 WORLD + VISION_BLOCKER 레이어, 높은 엄폐물은 WORLD, 낮은 엄폐물은 LOW_COVER 레이어에 놓인다.
## 엄폐물 네 면 바깥에는 CoverPoint 가 자동 생성되어 적 AI 가 사용한다.
## 모든 좌표는 레벨 로컬 픽셀 좌표이며 (0,0) 이 좌상단이다.

const TEX_FLOOR: Texture2D = preload("res://assets/sprites/floor_concrete.png")
const TEX_WALL: Texture2D = preload("res://assets/sprites/wall_block.png")

enum PropKind { SOLID, HIGH_COVER, LOW_COVER, DECOR }

var level: Node2D
var walls: Node2D
var props: Node2D
var floor_node: Node2D
var lights: Node2D
var _obstructions: Array[PackedVector2Array] = []
var _bounds: Rect2


func _init(level_: Node2D) -> void:
	level = level_
	floor_node = _ensure("Floor")
	walls = _ensure("Walls")
	props = _ensure("Props")
	props.y_sort_enabled = true
	lights = _ensure("Lights")


func _ensure(name: String) -> Node2D:
	if level.has_node(name):
		return level.get_node(name)
	var n := Node2D.new()
	n.name = name
	level.add_child(n)
	return n


func set_bounds(rect: Rect2) -> void:
	_bounds = rect


# -- 바닥 ---------------------------------------------------------------------

func add_floor(rect: Rect2, texture: Texture2D = TEX_FLOOR, modulate: Color = Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.position = rect.position
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.modulate = modulate
	s.z_index = -10
	floor_node.add_child(s)
	return s


func add_decal(pos: Vector2, texture: Texture2D, rotation: float = 0.0, scale: float = 1.0, z: int = -9) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = pos
	s.rotation = rotation
	s.scale = Vector2.ONE * scale
	s.z_index = z
	floor_node.add_child(s)
	return s


# -- 벽 -----------------------------------------------------------------------

func add_wall(rect: Rect2, texture: Texture2D = TEX_WALL, name: String = "", register_obstruction: bool = true) -> StaticBody2D:
	var body := _make_body(rect, Layers.WORLD | Layers.VISION_BLOCKER)
	if name != "":
		body.name = name
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.position = -rect.size * 0.5
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	body.add_child(s)
	body.z_index = 2
	walls.add_child(body)
	if register_obstruction:
		_obstructions.append(_rect_outline(rect))
	return body


## 사각형 방을 두께 thickness 의 벽으로 둘러싼다. openings: 벽에 뚫을 구간 [Rect2...]
func add_room_walls(rect: Rect2, thickness: float, openings: Array = []) -> void:
	var segments := [
		Rect2(rect.position.x, rect.position.y, rect.size.x, thickness),                          # top
		Rect2(rect.position.x, rect.end.y - thickness, rect.size.x, thickness),                   # bottom
		Rect2(rect.position.x, rect.position.y, thickness, rect.size.y),                          # left
		Rect2(rect.end.x - thickness, rect.position.y, thickness, rect.size.y),                   # right
	]
	for seg in segments:
		for piece in split_wall(seg, openings):
			add_wall(piece)


## 벽 사각형에서 openings 와 겹치는 구간을 잘라낸 조각들을 돌려준다.
func split_wall(seg: Rect2, openings: Array) -> Array[Rect2]:
	var pieces: Array[Rect2] = [seg]
	for op in openings:
		var next: Array[Rect2] = []
		for p in pieces:
			var o: Rect2 = op
			if not p.intersects(o):
				next.append(p)
				continue
			var horizontal := p.size.x > p.size.y
			if horizontal:
				if o.position.x > p.position.x:
					next.append(Rect2(p.position.x, p.position.y, o.position.x - p.position.x, p.size.y))
				if o.end.x < p.end.x:
					next.append(Rect2(o.end.x, p.position.y, p.end.x - o.end.x, p.size.y))
			else:
				if o.position.y > p.position.y:
					next.append(Rect2(p.position.x, p.position.y, p.size.x, o.position.y - p.position.y))
				if o.end.y < p.end.y:
					next.append(Rect2(p.position.x, o.end.y, p.size.x, p.end.y - o.end.y))
		pieces = next
	return pieces


# -- 소품 / 엄폐물 --------------------------------------------------------------

func add_prop(rect: Rect2, texture: Texture2D, kind: PropKind, name: String = "", rotation_deg: float = 0.0) -> Node2D:
	var node: Node2D
	match kind:
		PropKind.DECOR:
			node = Node2D.new()
			node.position = rect.get_center()
		PropKind.LOW_COVER:
			node = _make_body(rect, Layers.LOW_COVER)
		_:
			node = _make_body(rect, Layers.WORLD | (Layers.VISION_BLOCKER if kind == PropKind.SOLID else 0))
	if name != "":
		node.name = name
	var s := Sprite2D.new()
	s.texture = texture
	s.rotation = deg_to_rad(rotation_deg)
	node.add_child(s)
	node.z_index = 0
	props.add_child(node)
	if kind != PropKind.DECOR:
		_obstructions.append(_rect_outline(rect))
	if kind == PropKind.HIGH_COVER or kind == PropKind.LOW_COVER:
		_add_cover_points(node as PhysicsBody2D, rect, kind == PropKind.LOW_COVER)
	return node


func _add_cover_points(body: PhysicsBody2D, rect: Rect2, is_low: bool) -> void:
	var gap := 16.0
	var c := rect.get_center()
	var candidates := [
		Vector2(c.x, rect.position.y - gap),
		Vector2(c.x, rect.end.y + gap),
		Vector2(rect.position.x - gap, c.y),
		Vector2(rect.end.x + gap, c.y),
	]
	for pos in candidates:
		if _bounds.size != Vector2.ZERO and not _bounds.grow(-14.0).has_point(pos):
			continue
		var cp := CoverPoint.new()
		cp.position = pos
		cp.prop_body = body
		cp.is_low = is_low
		props.add_child(cp)


func _make_body(rect: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	return body


# -- 조명 ---------------------------------------------------------------------

func add_light(pos: Vector2, color: Color, energy: float, scale: float, name: String = "", shadows: bool = true) -> PointLight2D:
	var light := Fx.make_light(lights, pos, color, energy, scale)
	light.shadow_enabled = shadows
	if name != "":
		light.name = name
	return light


# -- 내비게이션 -----------------------------------------------------------------

## 경계 안쪽을 이동 가능 영역으로, 등록된 모든 벽·소품을 장애물로 하는 내비 영역을 만든다.
func build_navigation(agent_radius: float = 10.0) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	region.name = "NavRegion"
	var poly := NavigationPolygon.new()
	poly.agent_radius = agent_radius
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect_outline(_bounds))
	for ob in _obstructions:
		source.add_obstruction_outline(ob)
	NavigationServer2D.bake_from_source_geometry_data(poly, source)
	region.navigation_polygon = poly
	level.add_child(region)
	return region


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
