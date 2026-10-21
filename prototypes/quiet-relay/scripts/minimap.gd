extends Control

var world
const PANEL := Rect2(940,18,190,194)

func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world):
		return
	var font := ThemeDB.fallback_font
	draw_rect(PANEL,Color(0.025,0.044,0.063,0.96))
	draw_string(font,Vector2(953,39),"EXPLORED / ROOM %d" % world.current_room,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e4c997"))
	for link in world.visible_connections():
		var a: Vector2i = world.rooms[link.x-1].cell
		var b: Vector2i = world.rooms[link.y-1].cell
		draw_line(Vector2(984,64)+Vector2(a)*Vector2(81,51),Vector2(984,64)+Vector2(b)*Vector2(81,51),Color("9bbfb1"),3)
	for room in world.rooms:
		if not room.id in world.discovered_rooms:
			continue
		var rect := Rect2(Vector2(958,49)+Vector2(room.cell)*Vector2(81,51),Vector2(52,30))
		draw_rect(rect,room.color.darkened(0.7))
		draw_rect(rect,room.color,false,1)
		draw_string(font,rect.position+Vector2(21,21),str(room.id),HORIZONTAL_ALIGNMENT_LEFT,-1,16,room.color)
		if room.id==world.current_room:
			draw_rect(rect.grow(3),Color("ffe1a0"),false,3)
			draw_circle(rect.position+Vector2(8,15),3,Color("ffe1a0"))
	draw_string(font,Vector2(953,201),"%d / 6   Down+jump: descend" % world.discovered_rooms.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b8e0dc"))
