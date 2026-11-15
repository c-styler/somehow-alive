@tool
class_name Rug
extends Node2D
## A woven floor mat drawn as pixel art (4 screen px per art pixel, like the furniture
## sprites). Walk-through; joins the "furniture" group so locked rooms dim it too.
## Position = top-left corner.

@export var size_px := Vector2i(24, 36): # in art pixels (x4 on screen)
	set(v):
		size_px = v
		queue_redraw()
@export var field := Color("0081A7"): # main color
	set(v):
		field = v
		queue_redraw()
@export var border := Color("0B3C5D"):
	set(v):
		border = v
		queue_redraw()
@export var accent := Color("FED9B7"): # inner stripe + motif + fringe
	set(v):
		accent = v
		queue_redraw()

const PX := 4.0

func _enter_tree() -> void:
	add_to_group("furniture")

func _px(x: int, y: int, c: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, PX, PX), c)

func _draw() -> void:
	var w := size_px.x
	var h := size_px.y
	var fringe := 2 # rows of fringe at the short ends
	for y in range(fringe, h - fringe):
		for x in w:
			var top := y == fringe
			var bottom := y == h - fringe - 1
			var edge := x == 0 or x == w - 1 or top or bottom
			var corner := (x == 0 or x == w - 1) and (top or bottom)
			if corner:
				continue # rounded corners
			var c := field
			if edge or x == 1 or x == w - 2 or y == fringe + 1 or y == h - fringe - 2:
				c = border
			elif x == 3 or x == w - 4 or y == fringe + 3 or y == h - fringe - 4:
				c = accent # inner stripe
			else:
				# center diamond motif + a subtle woven checker
				var cx := (w - 1) / 2.0
				var cy := (h - 1) / 2.0
				var d := absf(x - cx) / (w * 0.22) + absf(y - cy) / (h * 0.16)
				if d <= 1.0 and d > 0.6:
					c = accent
				elif d <= 0.35:
					c = border
				elif (x + y) % 2 == 0:
					c = field.darkened(0.06)
			_px(x, y, c)
	# fringe on the short ends
	for x in range(2, w - 2, 2):
		for f in fringe:
			_px(x, f, accent.darkened(0.1))
			_px(x, h - 1 - f, accent.darkened(0.1))
