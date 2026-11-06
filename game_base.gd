extends Node2D
## The game node's shared state, constants and drawing primitives.
## The game is one node built in layers, each only calling the layers beneath it:
## game_base, game_audio, game_field, game_screens, game_effects, game_events, then main.gd.
## Rules live in sim/game_sim.gd and the screens outside the game in menus.gd.

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")
const Menus := preload("res://menus.gd")
const Verify := preload("res://verify.gd")
const WebTouch := preload("res://web_touch.gd")
const Music := preload("res://music.gd")
const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Bosses := preload("res://data/bosses.gd")
const BossArt := preload("res://boss_art.gd")
const Achievements := preload("res://data/achievements.gd")
const Shop := preload("res://data/shop.gd")
const RunContent := preload("res://data/run_content.gd")
const Worlds := preload("res://data/worlds.gd")
const Cosmetics := preload("res://data/cosmetics.gd")
const PerkArt := preload("res://perk_art.gd")
const UI := preload("res://ui_theme.gd")
const BackgroundShader := preload("res://shaders/background.gdshader")
const ImpactShader := preload("res://shaders/impact.gdshader")

const BASE_H := 1280.0
const BASE_W := 720.0
const MIN_AIM_HEIGHT := 24.0
const TAP_SLOP := 18.0
const ACCEPT_INPUT_AFTER := 0.3
const FONT_LATIN := ["Avenir Next", "Helvetica Neue", "Roboto", "sans-serif"]
const FONT_JAPANESE := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"]
const BUNDLED_FONT := preload("res://fonts/NotoSansJP-Game.ttf")
## The first-run hint: a ghost finger visits these points in turn, one tap per cycle.
const TUTORIAL_CYCLE := 2.4
const TUTORIAL_TARGETS: Array[Vector2] = [Vector2(230.0, 560.0), Vector2(500.0, 470.0), Vector2(380.0, 660.0)]
const SAMPLE_RATE := 22050
const BURST_WINDUP := 1.15
const BURST_AFTERGLOW := 1.1
const BOSS_INTRO := 2.7
const BOSS_INTRO_SKIP_AFTER := 0.3
const BOSS_DOWN_HOLD := 1.7
const SPEECH_SECONDS := 2.6
const SPEECH_COOLDOWN := 7.0
const BOSS_HEAL_COLOR := Color("7dffb0")
const MUSIC_VOLUME_DB := -13.0
const REDUCED_FX_SCALE := 0.25
const WHEEL_SCROLL := 70.0
const PAN_SCROLL := 24.0
const COUNT_UP_SECONDS := 1.0
const COUNT_UP_TICK := 0.07
const OVERKILL_TEXT_GAP := 0.12
const CARD_ICON_MAX := 120.0
const WIPE_SECONDS := 0.32
const REVEAL_SECONDS := 0.5
const COMBO_STAGES: Array[int] = [100, 300, 1000]
const ENDING_LINE_SECONDS := 2.6
const STAGE_SKY_SHIFT := 0.035
const WORLD_PITCH := {"wall": 1.0, "desert": 0.94, "glacier": 1.06, "cosmos": 0.9}
const BALL_GLYPHS := {"normal": "star", "iron": "hammer", "fire": "flame", "splitter": "fork", "blaster": "bomb", "ghost": "crosshair", "lucky": "clover", "titan": "big_ball"}
const KIND_BORDER := 4
const CARD_PATH_WIDTH := 96.0
const OBSTACLE_BODY := Color("2a2845")
const OBSTACLE_EDGE := Color("6f6b9c")
const OBSTACLE_PORTAL := Color("c77dff")
const OBSTACLE_PULSE_DECAY := 6.0
const BUILD_TILE := 54.0
const BUILD_GAP := 8.0
const STAGE_PIP_SPACING := 26.0
## The last target slows time, and destroying it nearly stops it.
const TENSION_SLOW := 0.45
const TENSION_SECONDS := 1.2
const TENSION_ZOOM := 1.05
const TENSION_BOSS_HP := 0.08
const FINISH_SLOW := 0.12
const FINISH_SECONDS := 0.6
const FINISH_ZOOM := 1.16
const FINISH_FX_RATE := 0.35
const ZOOM_SPEED := 10.0
const RANK_SECONDS := 1.4
const RANK_POP_SECONDS := 0.16
## Ranks below this are not worth interrupting the player's eye for.
const RANK_SHOW_FROM := 2
const RANK_COLORS: Array[Color] = [Color("8a8aa3"), Color("9db8ff"), Color("5ff0d0"), Color("6fdc6a"), Color("ffd84d"), Color("ff9a3d"), Color("ff5fa2")]
const TRAIL_BASE := 34.0
const TRAIL_PER_COMBO := 0.8
const TRAIL_MAX_EXTRA := 110.0
const TRAIL_COLOR_FULL_COMBO := 60.0
const EVOLVE_SECONDS := 2.1
const EVOLVE_IMPACT := 0.6
const EVOLVE_SKIP_AFTER := 0.3
const EVOLVE_FADE := 0.25

var sim: GameSim
var save: SaveData
var menus: Menus
var verifier: Verify
var screen: int = Menus.Screen.TITLE
var settings_return: int = Menus.Screen.TITLE
var shop_return: int = Menus.Screen.TITLE
var paused := false
var run_banked := true
var run_seconds := 0.0
var run_new_record := false
var y_offset := 0.0
var time := 0.0
var screen_age := 0.0
var last_state := -1

var aiming := false
var aim_current := Vector2.ZERO
var hovering := false
var list_press := Vector2.ZERO
var list_last := Vector2.ZERO
var list_active := false
var list_moved := false

var hitstop := 0.0
var trauma := 0.0
var descend_anim := 0.0
var flash := {}
var particles: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var fly_coins: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var toasts: Array[Dictionary] = []
var banner_text := ""
var banner_time := 0.0
var combo_pop := 0.0
var coin_pop := 0.0
var screen_flash := 0.0
var last_boom_stop := 0.0
var last_boom_sound := 0.0
var last_pop_sound := 0.0
var last_hit_sound := 0.0
var next_milestone := 25
var seen_choices: Array[String] = []
var burst_windup := -1.0
var burst_after := 0.0
var burst_origin := Vector2.ZERO
var burst_was_ready := false
var boss_intro := -1.0
var boss_intro_id := ""
var boss_intro_slammed := false
var boss_down := 0.0
var boss_down_id := ""
var boss_down_pos := Vector2.ZERO
var boss_rage_said := false
var speech_text := ""
var speech_time := 0.0
var speech_cooldown := 0.0
var speech_anchor := Vector2.ZERO
var beams: Array[Dictionary] = []

var font: Font
var font_body: Font
var font_label: Font
var canvas: CanvasItem
var glow_layer: Node2D
var ui_layer: Node2D
var list_clip: Control
var glow_texture: Texture2D
var background_material: ShaderMaterial
var impact_rect: ColorRect
var impact_material: ShaderMaterial
var impact := 0.0
var heat := 0.0
var _box := StyleBoxFlat.new()
var _pending_dots: Array[Dictionary] = []
var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_players: Array[AudioStreamPlayer] = []
var music_task := -1
var web_touch: WebTouch
var music_layers: Array[PackedByteArray] = []
var end_age := 0.0
var wipe := 0.0
var fever_glow := 0.0
var combo_stage := 0
var boss_crack := 0.0
var boss_crack_pos := Vector2.ZERO
var pending_ending := false
var ending_age := 0.0
var last_bumper_sound := 0.0
var last_tick_sound := 0.0
var last_overkill_text := 0.0
var run_mastery_before := 0
var finish_time := 0.0
var tension_left := TENSION_SECONDS
var zoom := 1.0
var zoom_target := 1.0
var zoom_focus := Vector2(BASE_W / 2.0, BASE_H / 2.0)
var rank_time := 0.0
var rank_shown := 0
var evolve_cut := -1.0
var evolve_id := ""
var evolve_hit := false
var verify_stats := {"max_balls": 0, "explosions": 0, "splits": 0}


## Latin text uses a clean geometric face, with Japanese falling back to a matching gothic.
## The bundled font comes last, for platforms with no Japanese system font, such as the web.
func _make_font(weight: int) -> Font:
	var japanese := SystemFont.new()
	japanese.font_names = PackedStringArray(FONT_JAPANESE)
	japanese.font_weight = weight
	var bundled := FontVariation.new()
	bundled.base_font = BUNDLED_FONT
	bundled.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	var latin := SystemFont.new()
	latin.font_names = PackedStringArray(FONT_LATIN)
	latin.font_weight = weight
	latin.fallbacks = [japanese, bundled]
	return latin

func t(key: String) -> String:
	return I18n.text(save.lang, key)

func is_run_over() -> bool:
	return sim.state == GameSim.State.WON or sim.state == GameSim.State.LOST

func _volume_db(volume: int) -> float:
	return linear_to_db(maxf(float(volume) / SaveData.VOLUME_MAX, 0.0001))

func _counted(value: int) -> int:
	var k := clampf(end_age / COUNT_UP_SECONDS, 0.0, 1.0)
	return int(value * (1.0 - pow(1.0 - k, 3.0)))

func _fx_scale() -> float:
	return REDUCED_FX_SCALE if save.reduce_fx else 1.0

## Letting go below the launcher cancels the shot.
func _can_aim_at(p: Vector2) -> bool:
	return p.y < GameSim.LAUNCH_Y - MIN_AIM_HEIGHT

func current_buttons() -> Array[Dictionary]:
	if screen != Menus.Screen.GAME:
		return menus.buttons(screen)
	var list: Array[Dictionary] = []
	if burst_windup >= 0.0 or evolve_cut >= 0.0 or (boss_intro >= 0.0 and not paused) or (boss_down > 0.0 and not paused):
		return list
	if paused:
		list.append(_button("resume", Rect2(110.0, 510.0, 500.0, 110.0), t("resume"), "primary"))
		list.append(_button("settings", Rect2(110.0, 636.0, 500.0, 84.0), t("settings")))
		list.append(_button("restart", Rect2(110.0, 736.0, 500.0, 84.0), t("restart")))
		list.append(_button("to_title", Rect2(110.0, 836.0, 500.0, 84.0), t("to_title")))
	elif is_run_over():
		list.append(_button("restart", Rect2(70.0, 930.0, 580.0, 120.0), t("retry"), "primary"))
		list.append(_button("shop", Rect2(70.0, 1066.0, 282.0, 100.0), t("shop")))
		list.append(_button("to_title", Rect2(368.0, 1066.0, 282.0, 100.0), t("to_title")))
		list.append(_button("save_card", Rect2(230.0, 876.0, 260.0, 44.0), t("save_card"), "small"))
	elif sim.state == GameSim.State.ROUTE:
		pass
	elif sim.state == GameSim.State.EVENT:
		list.append(_button("event_leave", Rect2(160.0, 1110.0, 400.0, 90.0), t("event_leave")))
	elif sim.state == GameSim.State.UPGRADE:
		if sim.rerolls > 0:
			list.append(_button("reroll", Rect2(160.0, 1110.0, 400.0, 90.0), t("reroll_button") % sim.rerolls))
	else:
		list.append(_button("pause", Rect2(628.0, 4.0, 88.0, 62.0), "", "icon"))
		if sim.can_burst():
			list.append(_button("burst", Rect2(120.0, 1140.0, 480.0, 96.0), t("burst_ready"), "burst"))
	return list

func _button(id: String, rect: Rect2, label: String, style := "normal") -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "style": style}

func _glow_sprite(center: Vector2, size: float, color: Color) -> void:
	canvas.draw_texture_rect(glow_texture, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false, color)

func soft_glow(center: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_texture_rect(glow_texture, Rect2(center - size / 2.0, size), false, color)

## A colored dot with a halo, used for ball swatches on top of buttons.
func soft_glow_deferred(center: Vector2, color_code: String) -> void:
	_pending_dots.append({"pos": center, "color": Color(color_code)})

func fill_screen(color: Color) -> void:
	var view := get_viewport_rect().size
	canvas.draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, view.y + 160.0), color)

func panel(rect: Rect2, color: Color, radius := 16.0, border := Color.TRANSPARENT, border_width := 0) -> void:
	_box.bg_color = color
	_box.set_corner_radius_all(int(radius))
	_box.border_color = border
	_box.set_border_width_all(border_width)
	canvas.draw_style_box(_box, rect)

func row(left: Vector2, width: float, label: String, value: String, size: int, value_color: Color) -> void:
	canvas.draw_string(font_body, left + Vector2(0.0, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.MUTED)
	canvas.draw_string(font, left + Vector2(0.0, size * 0.35), value, HORIZONTAL_ALIGNMENT_RIGHT, width, size, value_color)

## Colour is the health readout: the hotter the block, the more it still takes to break.
func _block_color(block: Dictionary) -> Color:
	var size: Vector2i = block["size"]
	var top: float = float(sim.stage_cfg()["hp_max"]) * GameSim.Tiers.hp_scale(sim.tier) * size.x * size.y
	return UI.ramp(float(block["hp"]) / top)

func _block_border(block: Dictionary) -> Color:
	if block.has("tint"):
		return Bosses.color("purun")
	return UI.BLOCKS.get(block["kind"], Color.TRANSPARENT)

func _combo_color(combo: int) -> Color:
	return UI.ramp(fmod(combo * 0.018, 1.0))

func _ball_color() -> Color:
	var override := String(Cosmetics.ITEMS[save.wearing("skin")]["color"])
	return Color(override) if override != "" else Color(String(Balls.BALLS[sim.ball_type]["color"]))

func _card_alpha(index: int) -> float:
	return 1.0 - pow(1.0 - clampf((screen_age - index * 0.06) / 0.22, 0.0, 1.0), 3.0)

func _feeds_build(id: String) -> bool:
	var owned := sim.tag_levels()
	for tag in Perks.tags_of(id):
		if int(owned.get(tag, 0)) > 0:
			return true
	return false

func card_rect(index: int, count: int) -> Rect2:
	var top := 305.0
	var area := 785.0
	var gap := 16.0
	var height := minf((area - gap * (count - 1)) / count, 235.0)
	return Rect2(70.0, top + index * (height + gap), 580.0, height)

## Largest size up to `size` at which the text fits, so no language can overflow a box.
func fit_size(text: String, size: int, max_width: float) -> int:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if width <= max_width else int(size * max_width / width)

func text_center(center: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	var used: Font = font if face == null else face
	var width := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(used, center + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_left(left: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	canvas.draw_string(font if face == null else face, left + Vector2(0.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_right(right: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	var used: Font = font if face == null else face
	var width := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(used, right + Vector2(-width, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_shadowed(center: Vector2, text: String, size: int, color: Color) -> void:
	text_center(center + Vector2(0.0, 5.0), text, size, Color(UI.INK, color.a * 0.6))
	text_center(center, text, size, color)
