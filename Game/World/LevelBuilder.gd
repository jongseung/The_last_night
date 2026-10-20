class_name LevelBuilder
extends RefCounted
## 데이터(사각형·텍스처·종류)만으로 3/4 뷰 스테이지를 만드는 도우미.
##
## 좌표 규약은 ViewSpace 참고. 모든 사각형은 '바닥면(footprint)' 이다.
##  - 바닥: TileMapLayer (Game/World/Tiles/floor_tileset.tres, 48px). 에디터에서 덧칠할 수 있다.
##  - 벽: 바닥면이 충돌, 그림은 윗면(바닥면을 WALL_HEIGHT 만큼 올린 것) + 앞면(남쪽 면).
##        세로 벽은 y-sort 가 맞도록 반 타일 단위로 쪼개 그린다.
##  - 소품: 원점 = 바닥면 아랫변 중앙, 스프라이트 아랫변 = 바닥면 아랫변.
##  - 플레이어를 가리는 벽·높은 소품은 occluders 에 등록되어 Level 이 반투명하게 만든다.
## 레이어: 벽 WORLD+VISION_BLOCKER, 높은 엄폐물 WORLD, 낮은 엄폐물 LOW_COVER.

const TILESET: TileSet = preload("res://Game/World/Tiles/floor_tileset.tres")
const TEX_WALL_TOP: Texture2D = preload("res://assets/sprites/props/wall_top.png")
const TEX_WALL_FRONT: Texture2D = preload("res://assets/sprites/props/wall_front.png")

enum PropKind { SOLID, HIGH_COVER, LOW_COVER, DECOR }
enum FloorTile { CONCRETE, CONCRETE_DARK, CONCRETE_CRACKED, WET_STREET, OFFICE_TILE, CARPET, CARPET_EDGE, GRATING }

var level: Node2D
var floor_layer: TileMapLayer
var floor_decals: Node2D
var walls: Node2D
var props: Node2D
var lights: Node2D
var occluders: Array[Dictionary] = []      ## [{node: CanvasItem, rect: Rect2(전역 그림 영역)}]
var minimap_rects: Array[Rect2] = []
var _obstructions: Array[PackedVector2Array] = []
var _bounds: Rect2
var _rng := RandomNumberGenerator.new()


func _init(level_: Node2D) -> void:
	level = level_
	_rng.seed = 5281
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = TILESET
	floor_layer.z_index = -10
	level.add_child(floor_layer)
	floor_decals = _ensure("FloorDecals", false, -9)
	walls = _ensure("Walls", true, 0)
	props = _ensure("Props", true, 0)
	lights = _ensure("Lights", false, 6)


func _ensure(name: String, y_sort: bool, z: int) -> Node2D:
	if level.has_node(name):
		return level.get_node(name)
	var n := Node2D.new()
	n.name = name
	n.y_sort_enabled = y_sort
	n.z_index = z
	level.add_child(n)
	return n


func set_bounds(rect: Rect2) -> void:
	_bounds = rect


# -- 바닥 ---------------------------------------------------------------------

## 타일 좌표 사각형을 칠한다. alt_tile 이 있으면 variation 확률로 섞는다.
func paint_floor(cells: Rect2i, tile: FloorTile, alt_tile: int = -1, variation: float = 0.0) -> void:
	for x in range(cells.position.x, cells.end.x):
		for y in range(cells.position.y, cells.end.y):
			var t: int = tile
			if alt_tile >= 0 and _rng.randf() < variation:
				t = alt_tile
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))


func add_decal(pos: Vector2, texture: Texture2D, rotation: float = 0.0, scale: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = pos
	s.rotation = rotation
	s.scale = Vector2.ONE * scale
	floor_decals.add_child(s)
	return s


# -- 벽 -----------------------------------------------------------------------

func add_wall(rect: Rect2, front_texture: Texture2D = TEX_WALL_FRONT, name: String = "", register_obstruction: bool = true, draw: bool = true) -> StaticBody2D:
	var body := StaticBody2D.new()
	if name != "":
		body.name = name
	body.position = Vector2(rect.get_center().x, rect.end.y)
	body.collision_layer = Layers.WORLD | Layers.VISION_BLOCKER
	body.collision_mask = 0
	body.y_sort_enabled = true
	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	cs.shape = box
	cs.position = Vector2(0, -rect.size.y * 0.5)
	body.add_child(cs)
	walls.add_child(body)
	if draw:
		_wall_visual(body, rect, front_texture)
		minimap_rects.append(rect)
	if register_obstruction:
		_obstructions.append(_rect_outline(rect))
	return body


## 보이지 않는 경계 (거리 끝, 화면 밖)
func add_barrier(rect: Rect2) -> StaticBody2D:
	return add_wall(rect, TEX_WALL_FRONT, "", true, false)


func _wall_visual(body: Node2D, rect: Rect2, front_texture: Texture2D) -> void:
	var h := float(ViewSpace.WALL_HEIGHT)
	var chunks: Array[Rect2] = []
	if rect.size.x >= rect.size.y:
		chunks.append(rect)
	else:
		var y := rect.position.y
		var step := ViewSpace.TILE * 0.5
		while y < rect.end.y - 0.5:
			var ch := minf(step, rect.end.y - y)
			chunks.append(Rect2(rect.position.x, y, rect.size.x, ch))
			y += ch
	for i in chunks.size():
		var c := chunks[i]
		var last := i == chunks.size() - 1
		var chunk := Node2D.new()
		chunk.position = Vector2(c.position.x, c.end.y) - body.position
		body.add_child(chunk)
		chunk.add_child(_tiled(TEX_WALL_TOP, Rect2(0, -c.size.y - h, c.size.x, c.size.y)))
		var vis := Rect2(c.position.x, c.position.y - h, c.size.x, c.size.y)
		if last:
			chunk.add_child(_tiled(front_texture, Rect2(0, -h, c.size.x, h)))
			vis.size.y += h
		occluders.append({"node": chunk, "rect": vis})


func _tiled(texture: Texture2D, rect: Rect2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.position = rect.position
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return s


## 사각형 방을 두께 thickness 의 벽으로 둘러싼다. openings: 벽에 뚫을 구간 [Rect2...]
func add_room_walls(rect: Rect2, thickness: float, openings: Array = [], front_texture: Texture2D = TEX_WALL_FRONT) -> void:
	var segments := [
		Rect2(rect.position.x, rect.position.y, rect.size.x, thickness),
		Rect2(rect.position.x, rect.end.y - thickness, rect.size.x, thickness),
		Rect2(rect.position.x, rect.position.y + thickness, thickness, rect.size.y - thickness * 2.0),
		Rect2(rect.end.x - thickness, rect.position.y + thickness, thickness, rect.size.y - thickness * 2.0),
	]
	for seg in segments:
		for piece in split_wall(seg, openings):
			add_wall(piece, front_texture)


## 벽 사각형에서 openings 와 겹치는 구간을 잘라낸 조각들을 돌려준다.
func split_wall(seg: Rect2, openings: Array) -> Array[Rect2]:
	var pieces: Array[Rect2] = [seg]
	for op in openings:
		var next: Array[Rect2] = []
		var o: Rect2 = op
		for p in pieces:
			if not p.intersects(o):
				next.append(p)
				continue
			if p.size.x > p.size.y:
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


## 가로 벽 앞면에 붙는 그림 (창문, 두꺼비집, 문). wall_bottom_y 는 그 벽 바닥면의 아랫변.
func add_wall_decor(x_center: float, wall_bottom_y: float, texture: Texture2D, lift: float = 6.0) -> Sprite2D:
	var n := Node2D.new()
	n.position = Vector2(x_center, wall_bottom_y + 0.5)
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -lift - texture.get_height())
	n.add_child(s)
	props.add_child(n)
	occluders.append({"node": n, "rect": Rect2(n.position + s.offset, texture.get_size())})
	return s


# -- 소품 / 엄폐물 --------------------------------------------------------------

func add_prop(rect: Rect2, texture: Texture2D, kind: PropKind, name: String = "") -> Node2D:
	var node: Node2D
	match kind:
		PropKind.DECOR:
			node = Node2D.new()
		PropKind.LOW_COVER:
			node = _make_body(rect, Layers.LOW_COVER)
		PropKind.HIGH_COVER:
			node = _make_body(rect, Layers.WORLD)
		_:
			node = _make_body(rect, Layers.WORLD | Layers.VISION_BLOCKER)
	if name != "":
		node.name = name
	node.position = Vector2(rect.get_center().x, rect.end.y)
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	node.add_child(s)
	props.add_child(node)
	if kind != PropKind.DECOR:
		_obstructions.append(_rect_outline(rect))
		minimap_rects.append(rect)
	if kind != PropKind.LOW_COVER and kind != PropKind.DECOR and texture.get_height() - rect.size.y > 24:
		occluders.append({"node": node, "rect": Rect2(node.position + s.offset, texture.get_size())})
	if kind == PropKind.HIGH_COVER or kind == PropKind.LOW_COVER:
		_add_cover_points(node as PhysicsBody2D, rect, kind == PropKind.LOW_COVER)
	return node


func _add_cover_points(body: PhysicsBody2D, rect: Rect2, is_low: bool) -> void:
	var gap := 20.0
	var c := rect.get_center()
	var candidates := [
		Vector2(c.x, rect.position.y - gap),
		Vector2(c.x, rect.end.y + gap),
		Vector2(rect.position.x - gap, c.y),
		Vector2(rect.end.x + gap, c.y),
	]
	for pos in candidates:
		if _bounds.size != Vector2.ZERO and not _bounds.grow(-16.0).has_point(pos):
			continue
		var cp := CoverPoint.new()
		cp.position = pos
		cp.prop_body = body
		cp.is_low = is_low
		props.add_child(cp)


func _make_body(rect: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = Vector2(0, -rect.size.y * 0.5)
	body.add_child(shape)
	return body


# -- 조명 ---------------------------------------------------------------------

func add_light(pos: Vector2, color: Color, energy: float, scale: float, name: String = "") -> PointLight2D:
	var light := Fx.make_light(lights, pos, color, energy, scale)
	light.shadow_enabled = false
	if name != "":
		light.name = name
	return light


## 천장 매달림 조명 같은, 모든 것 위에 그려지는 그림
func add_overhead(pos: Vector2, texture: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = pos
	lights.add_child(s)
	return s


# -- 내비게이션 -----------------------------------------------------------------

func build_navigation(agent_radius: float = 11.0) -> NavigationRegion2D:
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
