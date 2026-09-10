extends Node2D

var walker: AnimatedSprite2D
var elapsed := 0.0
var auto_close := false

func _ready() -> void:
    auto_close = "--verify" in OS.get_cmdline_user_args()
    var background := ColorRect.new()
    background.color = Color("172428")
    background.size = Vector2(1280, 720)
    add_child(background)
    var idle := Sprite2D.new()
    idle.texture = load("res://images/idle.png")
    idle.centered = false
    idle.scale = Vector2.ONE * 0.32
    idle.position = Vector2(325, 615) - Vector2(515, 1390) * 0.32
    var material := ShaderMaterial.new()
    material.shader = load("res://idle.gdshader")
    idle.material = material
    add_child(idle)
    walker = AnimatedSprite2D.new()
    walker.sprite_frames = load("res://passe_rive_sprite_frames.tres")
    walker.centered = false
    walker.scale = Vector2.ONE * 0.32
    walker.position = Vector2(955, 615) - Vector2(550, 1390) * 0.32
    add_child(walker)
    walker.play("walk_E")
    for entry in [["Passe-rive · Idle", 70.0], ["Marche E · essai à valider", 735.0]]:
        var label := Label.new()
        label.text = entry[0]
        label.position = Vector2(entry[1], 28)
        label.add_theme_font_size_override("font_size", 28)
        add_child(label)
    if auto_close:
        assert(walker.sprite_frames.get_frame_count("walk_E") == 8)
        assert(walker.sprite_frames.get_animation_loop("walk_E"))
        print("PASSE_RIVE_PREVIEW_LOADED: 8 walk frames, idle texture and shader")

func _process(delta: float) -> void:
    elapsed += delta
    if auto_close and elapsed >= 1.4:
        print("PASSE_RIVE_PREVIEW_CYCLE: ", walker.frame)
        get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        if walker.is_playing():
            walker.pause()
        else:
            walker.play()
