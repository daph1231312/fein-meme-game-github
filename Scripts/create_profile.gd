extends Control

@onready var avatar_rect  := $CenterContainer/Container/ProfilePictureContainer/ProfilePicture
@onready var add_btn      := $CenterContainer/Container/ProfilePictureContainer/Add
@onready var file_dialog  := $FileDialog
@onready var username_field := $CenterContainer/Container/Username


const TARGET_SIZE := 64          # final size
const MIN_ACCEPT  := 32          # reject below this (change if you want)

func _ready() -> void:
	# FileDialog filters (PNG/JPG)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Images"])
	# Wire signals
	add_btn.pressed.connect(_on_add_avatar_pressed)
	file_dialog.file_selected.connect(_on_avatar_file_selected)
	# TextureRect display behavior
	avatar_rect.expand = true
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_add_avatar_pressed() -> void:
	file_dialog.popup_centered()
	


func _on_avatar_file_selected(path: String) -> void:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("Failed to load image: %s" % path)
		return
	
	var w := img.get_width()
	var h := img.get_height()
	
	if w < MIN_ACCEPT or h < MIN_ACCEPT:
		_toast("Image too small (%dx%d). Pick at least %dx%d." % [w, h, MIN_ACCEPT, MIN_ACCEPT])
		return
	
	var side: int = int(min(w, h))
	var off_x: int = int((w - side) / 2)   # or: (w - side) >> 1
	var off_y: int = int((h - side) / 2)
	
	var square := Image.create(side, side, false, img.get_format())
	square.blit_rect(img, Rect2i(Vector2i(off_x, off_y), Vector2i(side, side)), Vector2i.ZERO)
	
	if side != TARGET_SIZE:
		square.resize(TARGET_SIZE, TARGET_SIZE, Image.INTERPOLATE_LANCZOS)
		
	var tex := ImageTexture.create_from_image(square)
	avatar_rect.texture = tex

	_toast("Avatar set to %dx%d." % [TARGET_SIZE, TARGET_SIZE])

func _toast(msg: String) -> void:
	print(msg)  # visible in output; swap with a custom AcceptDialog if you want

func _on_delete_pressed() -> void:
	var default_path := "res://Images/avatar-default.svg"
	var tex: Texture2D = load(default_path)

	if tex == null:
		push_error("Default avatar not found at %s" % default_path)
		return

	avatar_rect.texture = tex
	_toast("Avatar reset to default.")
	

func _on_create_pressed() -> void:
	ChatNet.my_name = username_field.text
	ChatNet.my_avatar_img = avatar_rect.texture.get_image()
	get_tree().change_scene_to_file("res://Scenes/lobby_manager.tscn")
