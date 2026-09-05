class_name CozyHUD
extends CanvasLayer
## Presentation only. The game owns purchases, wardrobe choices and journal state.

signal dialogue_blip(speaker_id: int, character_index: int)
signal dialogue_finished

signal travel_requested(index: int)
signal decorate_requested(kind: int)
signal action_requested(action: String)

const CREAM := Color("faf6eb")
const NAVY := Color("263c48")
const MINT := Color("dcebdc")
const MUTED := Color("64766f")
const LINE := Color("dedfd2")
const GOLD := Color("f3dc9e")
const PAPER := Color("fffcf4")
const SWATCHES := [Color("aac9af"), Color("c7bcde"), Color("e4bc9a"), Color("a8ccd2")]
const OrbitMotif = preload("res://scripts/ui_orbit_motif.gd")
const NEIGHBORS := ["Lumi", "Bolt", "Pip", "Miso"]
const NEIGHBOR_HOMES := ["Luma", "Rust", "Pebble", "Honey"]
const DESTINATIONS := ["Clover", "Luma", "Rust", "Commons", "Pebble", "Honey"]
const DESCRIPTIONS := [
	"A little green world. Room to grow.",
	"Soft light and a quieter pace.",
	"Warm earth. Small discoveries.",
	"A place to gather, a place to belong.",
	"Quiet stones and pocket-sized wonders.",
	"Golden light. A sweeter kind of day."
]

var _dialogue_label: Label
var _dialogue_clock := 0.0
var _dialogue_speaker := -1
var _typing := false
var _safe_insets := Vector4.ZERO
var _external_safe_area := false
var _touch_controls_active := false
var _touch_reserved_height := 200.0
var _bubble_style: StyleBoxTexture

var _root: Control
var _status: PanelContainer
var _planet: Label
var _subtitle: Label
var _wallet: PanelContainer
var _stars: Label
var _footer_card: PanelContainer
var _footer: VBoxContainer
var _actions: HFlowContainer
var _sound_button: Button
var _hint: Label
var _overlay: Control
var _backdrop: Button
var _panel: PanelContainer
var _panel_stack: VBoxContainer
var _panel_header: VBoxContainer
var _panel_intro: VBoxContainer
var _panel_body: VBoxContainer
var _dialogue_responses: VBoxContainer
var _panel_scroll: ScrollContainer
var _panel_grid: GridContainer
var _toast_card: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _toast_tween: Tween
var _focus_before_panel: WeakRef
var _panel_focus: Control
var _panel_open := false
var _travel_active := false
var _conversation := false
var _layout_pending := false
var _start_menu := false
var _settings_open := false
var _title_active := false
var _title_wordmark: Label
var _panel_default_style: StyleBoxFlat
var _panel_padding := 20.0
var _preview_cache: Dictionary = {}
var _shop_open := false
var _shop_purse: Label
var _shop_confirmation: Label
var _shop_parcel: Button
var _shop_entries: Array[Dictionary] = []


func _ready() -> void:
	_ensure_ui()
	_layout()


func set_status(planet_name: String, subtitle: String, stars: int) -> void:
	_ensure_ui()
	var money := "✦  %d stardust" % stars
	if _planet.text == planet_name and _subtitle.text == subtitle and _stars.text == money:
		return
	_planet.text = planet_name
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_stars.text = money
	_stars.tooltip_text = "%d stardust" % stars
	_queue_layout()


func set_hint(text: String) -> void:
	_ensure_ui()
	text = text.replace("  ·  M star map  ·  B decorate", "")
	if _hint.text == text:
		return
	_hint.text = text
	_hint.visible = not text.is_empty()
	_sync_footer()
	_hint.add_theme_font_size_override("font_size", 16 if text.begins_with("E  ·") else 14)
	_queue_layout()


func set_sound_enabled(enabled: bool) -> void:
	_ensure_ui()
	var text := "Sound on [V]" if enabled else "Sound off [V]"
	if _sound_button.text == text:
		return
	_sound_button.text = text
	_queue_layout()


func set_travel_active(active: bool) -> void:
	_ensure_ui()
	if _travel_active == active:
		return
	_travel_active = active
	_sync_footer()
	if active:
		toast("")
	_queue_layout()


func toast(text: String) -> void:
	_ensure_ui()
	# Panels own attention; never queue a toast to reappear after they close.
	if _panel_open:
		text = ""
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_timer.stop()
	_toast_label.text = text
	_toast_card.visible = not text.is_empty()
	_toast_card.modulate.a = 1.0
	_queue_layout()
	if not text.is_empty() and is_inside_tree():
		_toast_timer.start()


func show_start_menu(has_save: bool) -> void:
	_begin_panel("", "", "", false)
	_start_menu = true
	set_title_active(true)
	_set_backdrop_alpha(0.16)
	_panel_padding = 32.0
	var title_style := _style(Color(0.10, 0.19, 0.23, 0.92), 26, 32, Color(0.98, 0.96, 0.92, 0.14))
	title_style.shadow_color = Color(0.04, 0.10, 0.13, 0.20)
	title_style.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", title_style)
	_panel_body.add_theme_constant_override("separation", 16)
	_panel_body.add_child(_orbit_illustration(88))
	_panel_body.add_child(_wrapped_label("MAKE YOURSELF AT HOME", 11, Color("bccfc4")))
	_title_wordmark = _wrapped_label("LITTLE\nORBIT", 72, CREAM)
	_title_wordmark.name = "TitleWordmark"
	_title_wordmark.add_theme_constant_override("line_spacing", -12)
	_panel_body.add_child(_title_wordmark)
	_panel_body.add_child(_wrapped_label("A small home in a very big universe", 19, Color("dce5da")))
	var breathing_room := Control.new()
	breathing_room.custom_minimum_size.y = 8
	breathing_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_body.add_child(breathing_room)
	var begin := _title_button("Continue" if has_save else "Begin your little orbit", true)
	begin.pressed.connect(_emit_action.bind("continue" if has_save else "new_game"))
	_panel_body.add_child(begin)
	if has_save:
		var new_game := _title_button("New game")
		new_game.pressed.connect(_emit_action.bind("new_game"))
		_panel_body.add_child(new_game)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 12)
	_panel_body.add_child(utilities)
	var settings := _title_button("Settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(_emit_action.bind("settings"))
	utilities.add_child(settings)
	var quit := _title_button("Quit")
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(_emit_action.bind("quit"))
	utilities.add_child(quit)
	_finish_panel(begin)


func show_settings(music: float, effects: float, fullscreen: bool, sound_enabled: bool = true) -> void:
	_begin_panel("MAKE IT FEEL LIKE HOME", "Settings", "A little fine-tuning for your orbit.")
	_settings_open = true
	var master := _button("Sound · On" if sound_enabled else "Sound · Off", sound_enabled)
	master.pressed.connect(_emit_action.bind("sound"))
	_panel_body.add_child(master)
	var audio_card := _card(PAPER, 18, 18)
	_panel_body.add_child(audio_card)
	var audio_rows := _stack(20)
	audio_card.add_child(audio_rows)
	var music_slider := _volume_row(audio_rows, "Music", music, "music")
	_volume_row(audio_rows, "Sound effects", effects, "effects")
	var display := _button("Fullscreen · On" if fullscreen else "Fullscreen · Off", fullscreen)
	display.toggle_mode = true
	display.button_pressed = fullscreen
	display.tooltip_text = "Switch between fullscreen and windowed play"
	display.pressed.connect(_emit_action.bind("fullscreen"))
	_panel_body.add_child(display)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	_panel_body.add_child(navigation)
	var guide := _button("Field guide")
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.pressed.connect(_emit_action.bind("help"))
	navigation.add_child(guide)
	var back := _button("Back", true)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_emit_action.bind("back_to_title"))
	navigation.add_child(back)
	_finish_panel(music_slider)


func set_title_active(active: bool) -> void:
	_ensure_ui()
	# Presentation only: main owns the title camera, pause state and save decisions.
	_title_active = active
	if active:
		toast("")
	_sync_footer()
	_queue_layout()


func show_dialog(speaker: String, text: String, button: String = "Lovely", action: String = "close") -> void:
	_begin_panel("A MOMENT TOGETHER", speaker, "")
	_dialog_identity(speaker)
	_add_dialogue_text(text, speaker)
	var accept := _button(button, true)
	accept.pressed.connect(func() -> void:
		if _reveal_dialogue():
			return
		close_panel()
		action_requested.emit(action)
	)
	_dialogue_responses.add_child(accept)
	_finish_panel(accept)


func show_travel(current: int) -> void:
	_begin_panel("POSTCARDS FROM THE COSMOS", "Your little universe", "Six small worlds. A lovely place for every mood.")
	var grid := _new_grid()
	for index in range(DESTINATIONS.size()):
		var here := index == current
		var card := _quiet_card(MINT if here else PAPER, 22, 14)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 180
		grid.add_child(card)
		var content := _stack(8)
		card.add_child(content)
		content.add_child(_orbit_illustration(76, index))
		content.add_child(_wrapped_label("%02d  /  %s" % [index + 1, DESTINATIONS[index]], 20, NAVY))
		var description := _wrapped_label(DESCRIPTIONS[index], 14, MUTED)
		description.custom_minimum_size.y = 42
		content.add_child(description)
		var destination := _button("You are here" if here else "Visit " + DESTINATIONS[index] + "  ›", not here)
		destination.disabled = here
		destination.tooltip_text = DESCRIPTIONS[index]
		destination.pressed.connect(_choose_destination.bind(index))
		content.add_child(destination)
	_finish_panel()


func show_inventory(items: Array) -> void:
	_begin_panel("MAKE YOURSELF AT HOME", "Decorating bag", "")
	_compact_panel_header()
	var grid := _new_grid()
	var valid_items := 0
	for entry in items:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		if not item.has("kind") or not item.has("name") or not item.has("count"):
			continue
		var count := maxi(0, int(item["count"]))
		var kind := int(item["kind"])
		var name_text := str(item["name"])
		var content := _catalog_card(grid, item)
		var quantity := _wrapped_label("%d in your bag" % count if count > 0 else "None in your bag", 13, MUTED)
		content.add_child(quantity)
		var choice := _compact_button("Place", count > 0)
		choice.name = "Place%d" % kind
		choice.set_meta("kind", kind)
		choice.disabled = count == 0
		choice.tooltip_text = "Place %s · %d available" % [name_text, count] if count > 0 else "Place %s · None available just now" % name_text
		choice.pressed.connect(_choose_decoration.bind(kind))
		content.add_child(choice)
		valid_items += 1
	if valid_items == 0:
		_empty_state("A little room for possibility.", "Your collected decorations will appear here.")
	_finish_panel()


func show_shop(items: Array, balance: int) -> void:
	_begin_panel("FOR YOUR HOME", "Orbit Objects", "")
	_shop_open = true
	_compact_panel_header()
	_shop_confirmation = _panel_header.find_child("PanelEyebrow", true, false) as Label
	_shop_confirmation.max_lines_visible = 2
	_shop_confirmation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var shop_bar := HFlowContainer.new()
	shop_bar.add_theme_constant_override("h_separation", 12)
	shop_bar.add_theme_constant_override("v_separation", 6)
	_panel_header.add_child(shop_bar)
	var purse := _label("%d stardust" % balance, 15, NAVY)
	purse.custom_minimum_size.y = 40.0
	purse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_bar.add_child(purse)
	_shop_purse = purse
	var parcel := _compact_button("Buy a parcel · 15")
	parcel.custom_minimum_size.x = 184.0
	parcel.disabled = balance < 15
	parcel.tooltip_text = "One surprise decoration · 15 stardust" if balance >= 15 else "A surprise parcel needs 15 stardust"
	parcel.pressed.connect(_choose_action.bind("buy"))
	shop_bar.add_child(parcel)
	_shop_parcel = parcel
	var grid := _new_grid()
	var valid_items := 0
	for entry in items:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		if not item.has("kind") or not item.has("name") or not item.has("price"):
			continue
		var price := maxi(0, int(item["price"]))
		var affordable := balance >= price
		var content := _catalog_card(grid, item)
		var buy := _compact_button("Buy · %d stardust" % price, true)
		buy.disabled = not affordable
		buy.tooltip_text = "Buy %s · %d stardust" % [str(item["name"]), price] if affordable else "%s · %d more stardust needed" % [str(item["name"]), price - balance]
		buy.pressed.connect(_emit_action.bind("buy_item:%d" % int(item["kind"])))
		content.add_child(buy)
		_shop_entries.append({"button": buy, "price": price, "name": str(item["name"])})
		valid_items += 1
	if valid_items == 0:
		_empty_state("The shelves are resting.", "A surprise parcel is still here whenever you fancy one.")
	_finish_panel()


func refresh_shop(balance: int, purchased_name: String) -> void:
	if not _panel_open or not _shop_open:
		return
	_shop_purse.text = "%d stardust" % balance
	_shop_parcel.disabled = balance < 15
	_shop_parcel.tooltip_text = "One surprise decoration · 15 stardust" if balance >= 15 else "A surprise parcel needs 15 stardust"
	for entry in _shop_entries:
		var buy := entry["button"] as Button
		var price := int(entry["price"])
		var name_text := str(entry["name"])
		buy.disabled = balance < price
		buy.tooltip_text = "Buy %s · %d stardust" % [name_text, price] if balance >= price else "%s · %d more stardust needed" % [name_text, price - balance]
	if not purchased_name.is_empty():
		# Reuse the fixed header line, so confirmation adds no height above the grid.
		_shop_confirmation.text = "Added to your bag · %s" % purchased_name
		_shop_confirmation.tooltip_text = _shop_confirmation.text
	# No panel rebuild, focus grab or scrolling: only refresh keyboard routes.
	_wire_panel_focus(get_viewport().gui_get_focus_owner())


func show_wardrobe(current: int, names: Array, colors: Array) -> void:
	_begin_panel("ORBIT OUTFITTERS", "Your next look", "Every color is yours to wear.")
	_compact_panel_header()
	var grid := _new_grid()
	for index in range(mini(names.size(), colors.size())):
		var wearing := index == current
		var name_text := str(names[index])
		var color := MINT
		if colors[index] is Color:
			color = colors[index]
		elif colors[index] is String or colors[index] is StringName:
			color = Color.from_string(str(colors[index]), MINT)
		var card := _quiet_card(MINT if wearing else PAPER, 16, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var content := _stack(10)
		card.add_child(content)
		var preview := _rendered_thumbnail("res://assets/icons/suit_%02d.png" % index, color)
		preview.tooltip_text = name_text
		content.add_child(preview)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		title_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(title_row)
		title_row.add_child(_color_swatch(color, 18.0, 44.0))
		var title := _wrapped_label(name_text, 17, NAVY)
		title.custom_minimum_size.y = 44
		title_row.add_child(title)
		content.add_child(_wrapped_label("Wearing now" if wearing else "Complimentary", 13, MUTED))
		var wear := _compact_button("Currently wearing" if wearing else "Wear this color", not wearing)
		wear.disabled = wearing
		wear.tooltip_text = "%s · Currently wearing" % name_text if wearing else "Wear %s" % name_text
		wear.pressed.connect(_choose_action.bind("wear:%d" % index))
		content.add_child(wear)
	if grid.get_child_count() == 0:
		_empty_state("A little space for a new look.", "Your suit colors will appear here.")
	_finish_panel()


func show_journal(entries: Array) -> void:
	_begin_panel("FRIENDS & HOME", "Neighborhood journal", "Small moments, kept close.")
	var valid_entries := 0
	var summaries: Array[Dictionary] = []
	for entry in entries:
		if not entry is Dictionary or not (entry.has("title") or entry.has("name")):
			continue
		var who := int(entry.get("who", -1))
		if who < 0 or who >= NEIGHBORS.size():
			summaries.append(entry)
			continue

		var identity := _neighbor_identity(who, str(entry.get("name", NEIGHBORS[who])), str(entry.get("location", NEIGHBOR_HOMES[who])), str(entry.get("friendship", "")))
		identity.name = "Neighbor%d" % who
		var page := _quiet_card(PAPER if valid_entries % 2 == 0 else Color("edf0e2"), 20, 18)
		_panel_body.add_child(page)
		page.add_child(identity)
		var content := identity.get_child(1) as VBoxContainer
		var progress := str(entry.get("progress", ""))
		if not progress.is_empty():
			content.add_child(_wrapped_label(progress, 15, NAVY))
		var body := str(entry.get("body", ""))
		if not body.is_empty() and body != progress:
			content.add_child(_wrapped_label(body, 14, MUTED))
		valid_entries += 1
	for entry in summaries:
		var strip := _quiet_card(MINT, 12, 14)
		strip.name = "HomeSummary" if str(entry.get("title", "")) == "Your little corner of the cosmos" else "JournalSummary"
		_panel_body.add_child(strip)
		var content := _stack(6)
		strip.add_child(content)
		var title := "HOME" if strip.name == "HomeSummary" else str(entry.get("title", entry.get("name", "")))
		content.add_child(_wrapped_label(title, 12, MUTED))
		var progress := str(entry.get("progress", ""))
		if not progress.is_empty():
			content.add_child(_wrapped_label(progress, 16, NAVY))
		var body := str(entry.get("body", ""))
		if not body.is_empty():
			content.add_child(_wrapped_label(body, 13, MUTED))
		valid_entries += 1
	if valid_entries == 0:
		_empty_state("Every friendship starts with hello.", "Your neighborhood stories will find a home on these pages.")
	_finish_panel()


func show_choices(speaker: String, text: String, choices: Array) -> void:
	_begin_panel("A MOMENT TOGETHER", speaker, "")
	_dialog_identity(speaker)
	_add_dialogue_text(text, speaker)
	var first_choice: Button
	for entry in choices:
		if not entry is Dictionary or not entry.has("label") or not entry.has("action"):
			continue
		var choice := _button(str(entry["label"]), first_choice == null)
		choice.tooltip_text = str(entry["label"])
		choice.pressed.connect(_choose_action.bind(str(entry["action"])))
		_dialogue_responses.add_child(choice)
		if first_choice == null:
			first_choice = choice
	_finish_panel(first_choice)


func show_controls() -> void:
	# Retain the API; the full control legend now belongs to main's Help dialog.
	action_requested.emit("help")


func close_panel() -> void:
	_stop_dialogue()
	if not _panel_open:
		return
	_panel_open = false
	_shop_open = false
	_start_menu = false
	_settings_open = false
	_title_active = false
	_overlay.hide()
	_sync_footer()
	_queue_layout()
	_panel_focus = null
	if _focus_before_panel:
		var previous = _focus_before_panel.get_ref()
		if is_instance_valid(previous) and previous is Control and previous.is_visible_in_tree():
			previous.grab_focus()
	_focus_before_panel = null


func is_panel_open() -> bool:
	return _panel_open


func _unhandled_key_input(event: InputEvent) -> void:
	if _panel_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_dismiss_panel()
		get_viewport().set_input_as_handled()
	elif not _panel_open and not _travel_active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_request_footer_action("help")
		get_viewport().set_input_as_handled()


func _ensure_ui() -> void:
	if is_instance_valid(_root):
		return
	_touch_controls_active = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		_touch_controls_active = _touch_controls_active or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
	layer = 10
	_root = Control.new()
	_root.name = "LittleOrbitHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rounded := FontVariation.new()
	rounded.base_font = preload("res://assets/ui/fonts/Nunito-Variable.ttf")
	rounded.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
	# Explicit symbols cover stars absent from the engine default font.
	rounded.fallbacks = [preload("res://assets/ui/fonts/NotoSansSymbols2-Regular.ttf"), ThemeDB.fallback_font]
	_root.theme = Theme.new()
	_root.theme.default_font = rounded
	add_child(_root)
	_root.resized.connect(_queue_layout)

	_status = _card(CREAM, 18, 14)
	_root.add_child(_status)
	var status_stack := _stack(3)
	_status.add_child(status_stack)
	status_stack.add_child(_label("LITTLE ORBIT", 10, MUTED))
	_planet = _label("A little place to belong", 22, NAVY)
	_planet.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_stack.add_child(_planet)
	_subtitle = _label("Make yourself at home.", 13, MUTED)
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_stack.add_child(_subtitle)
	_wallet = _card(GOLD, 18, 12)
	_root.add_child(_wallet)
	_stars = _label("✦  0 stardust", 16, NAVY)
	_stars.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet.add_child(_stars)

	_footer_card = _card(CREAM, 18, 12)
	var footer_style := _footer_card.get_theme_stylebox("panel") as StyleBoxFlat
	footer_style.content_margin_top = 8
	footer_style.content_margin_bottom = 8
	_footer_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_footer_card.minimum_size_changed.connect(_queue_layout)
	_root.add_child(_footer_card)
	_footer = _stack(6)
	_footer.minimum_size_changed.connect(_queue_layout)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_card.add_child(_footer)
	_hint = _label("", 14, NAVY)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.hide()
	_footer.add_child(_hint)
	_actions = HFlowContainer.new()
	_actions.alignment = FlowContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("h_separation", 6)
	_actions.add_theme_constant_override("v_separation", 6)
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(_actions)
	var map_button := _button("Map  [M]")
	_size_footer_button(map_button, 82.0)
	map_button.pressed.connect(_request_footer_action.bind("map"))
	_actions.add_child(map_button)
	var decorate_button := _button("Decorate  [B]", true)
	_size_footer_button(decorate_button, 112.0)
	decorate_button.pressed.connect(_request_footer_action.bind("decorate"))
	_actions.add_child(decorate_button)
	var journal_button := _button("Journal  [J]")
	_size_footer_button(journal_button, 100.0)
	journal_button.pressed.connect(_request_footer_action.bind("journal"))
	_actions.add_child(journal_button)
	var camera_button := _button("Camera  [C]")
	_size_footer_button(camera_button, 100.0)
	camera_button.tooltip_text = "Switch between cozy and overview cameras · C"
	camera_button.pressed.connect(_request_footer_action.bind("camera"))
	_actions.add_child(camera_button)
	_sound_button = _button("Sound [V]")
	_size_footer_button(_sound_button, 116.0)
	_sound_button.pressed.connect(_request_footer_action.bind("sound"))
	_actions.add_child(_sound_button)
	var help_button := _button("Help  [H]")
	_size_footer_button(help_button, 82.0)
	help_button.tooltip_text = "Movement (WASD / Shift), decorating and camera controls · H"
	help_button.pressed.connect(_request_footer_action.bind("help"))
	_actions.add_child(help_button)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	_root.add_child(_overlay)
	_backdrop = Button.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.focus_mode = Control.FOCUS_NONE
	_set_backdrop_alpha(0.40)
	_backdrop.pressed.connect(_dismiss_panel)
	_overlay.add_child(_backdrop)
	_panel = _card(CREAM, 24, 20)
	_panel_default_style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_panel)
	_panel_stack = _stack(14)
	_panel.add_child(_panel_stack)
	_panel_header = _stack(8)
	_panel_header.minimum_size_changed.connect(_queue_layout)
	_panel_stack.add_child(_panel_header)
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.follow_focus = true
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_stack.add_child(_panel_scroll)
	_panel_body = _stack(14)
	_panel_body.minimum_size_changed.connect(_queue_layout)
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel_body)
	_panel_scroll.resized.connect(_queue_layout)
	_dialogue_responses = _stack(6)
	_dialogue_responses.hide()
	_panel_stack.add_child(_dialogue_responses)

	_toast_card = _card(NAVY, 18, 16)
	_toast_card.minimum_size_changed.connect(_queue_layout)
	_toast_card.hide()
	_root.add_child(_toast_card)
	_toast_label = _label("", 16, CREAM)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_card.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.6
	_toast_timer.timeout.connect(_fade_toast)
	add_child(_toast_timer)
	_queue_layout()


func _begin_panel(eyebrow: String, title: String, description: String, standard_header: bool = true) -> void:
	_ensure_ui()
	_stop_dialogue()
	_shop_open = false
	_shop_entries.clear()
	_shop_purse = null
	_shop_confirmation = null
	_shop_parcel = null
	_conversation = false
	_start_menu = false
	_settings_open = false
	_title_wordmark = null
	_panel_padding = 20.0
	_panel_stack.add_theme_constant_override("separation", 14)
	_panel.add_theme_stylebox_override("panel", _panel_default_style)
	_panel_header.visible = standard_header
	_panel_body.add_theme_constant_override("separation", 14)
	_set_backdrop_alpha(0.40)
	toast("")
	if not _panel_open:
		var focused := get_viewport().gui_get_focus_owner()
		_focus_before_panel = weakref(focused) if focused else null
	_panel_open = true
	_sync_footer()
	_panel_focus = null
	_panel_grid = null
	_panel_intro = null
	_dialogue_responses.hide()
	for container in [_panel_header, _panel_body, _dialogue_responses]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_panel_scroll.scroll_vertical = 0
	if not standard_header:
		return
	var top := HBoxContainer.new()
	_panel_header.add_child(top)
	var kicker := _label(eyebrow, 11, MUTED)
	kicker.name = "PanelEyebrow"
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(kicker)
	var dismiss := _button("×")
	dismiss.name = "ClosePanel"
	dismiss.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := dismiss.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.set_content_margin_all(8)
		dismiss.add_theme_stylebox_override(state, style)
	dismiss.tooltip_text = "Close · Escape"
	dismiss.pressed.connect(_dismiss_panel)
	top.add_child(dismiss)
	_panel_focus = dismiss
	_panel_intro = _stack(8)
	_panel_header.add_child(_panel_intro)
	var heading := _label(title, 29, NAVY)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_intro.add_child(heading)
	if not description.is_empty():
		var summary := _label(description, 15, MUTED)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_intro.add_child(summary)
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _style(LINE, 1, 1))
	_panel_intro.add_child(rule)


func _set_backdrop_alpha(alpha: float) -> void:
	var style := _style(Color(0.08, 0.16, 0.19, alpha), 0, 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		_backdrop.add_theme_stylebox_override(state, style)


func _finish_panel(focus_target: Control = null) -> void:
	_overlay.show()
	_wire_panel_focus()
	if focus_target:
		_panel_focus = focus_target
	_queue_layout()
	_focus_panel.call_deferred()


func _wire_panel_focus(retained_focus: Control = null) -> void:
	var focusable: Array[Control] = []
	for node in _panel_stack.find_children("*", "Control", true, false):
		if not node.is_visible_in_tree():
			continue
		# A just-purchased item can become unaffordable without losing its focus.
		if (node is Button and (not node.disabled or node == retained_focus)) or (node is Slider and node.editable):
			focusable.append(node)
	for index in range(focusable.size()):
		var control := focusable[index]
		control.focus_next = control.get_path_to(focusable[(index + 1) % focusable.size()])
		control.focus_previous = control.get_path_to(focusable[(index - 1 + focusable.size()) % focusable.size()])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		# Left/right adjusts a slider; Tab and up/down still traverse the whole menu.
		control.focus_neighbor_left = NodePath(".") if control is Slider else control.focus_previous
		control.focus_neighbor_right = NodePath(".") if control is Slider else control.focus_next


func _focus_panel() -> void:
	if _panel_open and is_instance_valid(_panel_focus) and _panel_focus.is_inside_tree():
		_panel_focus.grab_focus()


func _choose_destination(index: int) -> void:
	close_panel()
	travel_requested.emit(index)


func _choose_decoration(kind: int) -> void:
	close_panel()
	decorate_requested.emit(kind)


func _choose_action(action: String) -> void:
	if _reveal_dialogue():
		return
	close_panel()
	action_requested.emit(action)


func _emit_action(action: String) -> void:
	# Title and settings navigation stays visible until main decides the next screen.
	action_requested.emit(action)


func _dismiss_panel() -> void:
	if _start_menu or _settings_open or _title_active:
		action_requested.emit("back_to_title")
	else:
		close_panel()


func _request_footer_action(action: String) -> void:
	action_requested.emit(action)


func _sync_footer() -> void:
	_status.visible = not _title_active
	_wallet.visible = not _title_active
	_footer_card.visible = not _panel_open and not _title_active and (not _touch_controls_active or not _hint.text.is_empty())
	_actions.visible = not _travel_active and not _touch_controls_active


func _queue_layout() -> void:
	if not _layout_pending:
		_layout_pending = true
		_layout.call_deferred()


func _layout() -> void:
	_layout_pending = false
	if not is_instance_valid(_root) or not is_inside_tree():
		return
	var full_size := get_viewport().get_visible_rect().size
	if not _external_safe_area:
		_update_browser_safe_area(full_size)
	var safe_origin := Vector2(_safe_insets.x, _safe_insets.y)
	var viewport_size := full_size - safe_origin - Vector2(_safe_insets.z, _safe_insets.w)
	var margin := 22.0 if viewport_size.x >= 720.0 and viewport_size.y >= 500.0 else 12.0
	var available := maxf(1.0, viewport_size.x - margin * 2.0)
	var compact := _touch_controls_active or viewport_size.y < 440.0 or viewport_size.x < 500.0
	var status_stack := _status.get_child(0)
	status_stack.get_child(0).visible = not compact
	_subtitle.visible = not compact and not _subtitle.text.is_empty()
	_planet.add_theme_font_size_override("font_size", 17 if compact else 22)
	for card in [_status, _wallet]:
		var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat
		card_style.content_margin_top = 8 if compact else 14
		card_style.content_margin_bottom = 8 if compact else 14
	_hint.add_theme_font_size_override("font_size", 13 if compact else 14)
	_hint.max_lines_visible = 2 if compact else -1
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var wallet_width := minf(150.0 if compact else 174.0, available * 0.43)
	_status.position = Vector2(margin, margin)
	_status.size = Vector2(minf(330.0, maxf(1.0, available - wallet_width - 12.0)), 0.0)
	_wallet.position = Vector2(viewport_size.x - margin - wallet_width, margin)
	_wallet.size = Vector2(wallet_width, 0.0)
	var money_font_size := 16 if wallet_width >= 164.0 else 12
	if _stars.get_theme_font_size("font_size") != money_font_size:
		_stars.add_theme_font_size_override("font_size", money_font_size)
	# Size only the outer card; containers own the positions and sizes beneath it.
	_footer_card.size = Vector2(minf(340.0 if _touch_controls_active else 700.0, available), 0.0)
	var touch_space := _touch_reserved_height if _touch_controls_active and not _panel_open and not _title_active else 0.0
	# In short landscape, the overlay leaves a central gap between its side controls.
	# Keep the compact hint there instead of across the player and placement preview.
	if _touch_controls_active and viewport_size.x > viewport_size.y and viewport_size.y < 500.0:
		touch_space = 0.0
	_footer_card.position = Vector2((viewport_size.x - _footer_card.size.x) * 0.5, maxf(margin, viewport_size.y - margin - touch_space - _footer_card.size.y))
	var right_conversation := false
	var normal_width := 680.0 if _conversation else 780.0
	var title_width := minf(500.0, viewport_size.x * 0.40) if viewport_size.x >= 960.0 else 500.0
	var panel_width := minf(title_width if _start_menu else normal_width, available)
	if _start_menu and is_instance_valid(_title_wordmark):
		var short_title := viewport_size.y < 440.0
		var title_size := 34 if short_title else clampi(int((panel_width - 64.0) / 6.0), 38, 72)
		_title_wordmark.text = "LITTLE ORBIT" if short_title else "LITTLE\nORBIT"
		_title_wordmark.add_theme_font_size_override("font_size", title_size)
		_panel_padding = 16.0 if short_title else 32.0
		_panel.get_theme_stylebox("panel").set_content_margin_all(_panel_padding)
		_panel_body.add_theme_constant_override("separation", 8 if short_title else 16)
		for child in _panel_body.get_children():
			if child.get_script() == OrbitMotif or (child is Label and child.text == "MAKE YOURSELF AT HOME") or child.get_class() == "Control":
				child.visible = not short_title
		for node in _panel_body.find_children("*", "Button", true, false):
			node.custom_minimum_size.y = 44 if short_title else 52
			for state in ["normal", "hover", "pressed"]:
				var button_style := node.get_theme_stylebox(state) as StyleBoxFlat
				button_style.content_margin_top = 8 if short_title else 14
				button_style.content_margin_bottom = 8 if short_title else 14
	if is_instance_valid(_panel_intro) and not _conversation:
		# Short windows scroll the introduction too; the close control stays in reach.
		var intro_parent: VBoxContainer = _panel_body if viewport_size.y < 440.0 else _panel_header
		if _panel_intro.get_parent() != intro_parent:
			_panel_intro.reparent(intro_parent)
			if intro_parent == _panel_body:
				_panel_body.move_child(_panel_intro, 0)
	if is_instance_valid(_panel_grid):
		# Leave room for the scrollbar before picking columns, avoiding resize oscillation.
		var grid_width := maxf(1.0, panel_width - 58.0)
		var columns := clampi(int((grid_width + 12.0) / 210.0), 1, 2 if viewport_size.x < 1100.0 else 3)
		if _panel_grid.columns != columns:
			_panel_grid.columns = columns
	if _conversation:
		var short_screen := viewport_size.y < 440.0
		_panel_padding = 12.0 if short_screen else 20.0
		var paper := _panel.get_theme_stylebox("panel")
		for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			paper.set_content_margin(edge, _panel_padding)
		if is_instance_valid(_dialogue_label):
			_dialogue_label.add_theme_font_size_override("font_size", 18 if short_screen else 20)
			_dialogue_label.add_theme_constant_override("line_spacing", 2)
	var header_height := _panel_header.get_combined_minimum_size().y + 14.0 if _panel_header.visible else 0.0
	var content_height := header_height + _panel_body.get_combined_minimum_size().y + _panel_padding * 2.0
	var panel_height := minf(maxf(220.0, content_height), maxf(1.0, viewport_size.y - margin * 2.0))
	if _conversation:
		content_height += _dialogue_responses.get_combined_minimum_size().y + 6
		panel_height = minf(content_height, viewport_size.y * (0.55 if viewport_size.y < 440 else 0.52))
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = (viewport_size - _panel.size) * 0.5
	if _start_menu and viewport_size.x >= 960.0:
		_panel.position.x = viewport_size.x - maxf(margin, viewport_size.x * 0.05) - _panel.size.x
	elif right_conversation:
		_panel.position = Vector2(
			viewport_size.x - margin - _panel.size.x,
			clampf(viewport_size.y * 0.35, margin, maxf(margin, viewport_size.y - margin - _panel.size.y))
		)
	if _conversation:
		_panel.position.y = maxf(margin, viewport_size.y - margin - _panel.size.y - 12.0)
	_toast_card.size = Vector2(minf(420.0, available), 0.0)
	_toast_card.position = Vector2((viewport_size.x - _toast_card.size.x) * 0.5, maxf(margin, _footer_card.position.y - _toast_card.size.y - 18.0))

	for surface in [_status, _wallet, _footer_card, _panel, _toast_card]:
		surface.position += safe_origin


func _fade_toast() -> void:
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_card, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast_card.hide)


func _title_button(text: String, accent: bool = false) -> Button:
	var result := _button(text, accent)
	result.custom_minimum_size.y = 52.0
	result.add_theme_font_size_override("font_size", 18)
	result.tooltip_text = text
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, NAVY if accent else CREAM)
	result.add_theme_stylebox_override("normal", _style(CREAM if accent else Color.TRANSPARENT, 14, 14, Color(0.98, 0.96, 0.92, 0.24)))
	result.add_theme_stylebox_override("hover", _style(MINT if accent else Color(0.98, 0.96, 0.92, 0.10), 14, 14, Color(0.98, 0.96, 0.92, 0.50)))
	result.add_theme_stylebox_override("pressed", _style(GOLD if accent else Color(0.98, 0.96, 0.92, 0.17), 14, 14))
	var focus := _style(Color.TRANSPARENT, 14, 0, GOLD)
	focus.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus)
	return result


func _volume_row(parent: VBoxContainer, text: String, value: float, action: String) -> HSlider:
	var row := _stack(6)
	parent.add_child(row)
	var heading := HBoxContainer.new()
	row.add_child(heading)
	var label := _wrapped_label(text, 17, NAVY)
	heading.add_child(label)
	var percentage := _label("%d%%" % roundi(clampf(value, 0.0, 1.0) * 100.0), 14, MUTED)
	percentage.custom_minimum_size.x = 48.0
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(percentage)
	var slider := HSlider.new()
	slider.name = "MusicSlider" if action == "music" else "EffectsSlider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = clampf(value, 0.0, 1.0)
	slider.focus_mode = Control.FOCUS_ALL
	slider.scrollable = false
	slider.custom_minimum_size.y = 36.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s · %d%% · Left/right to adjust" % [text, roundi(slider.value * 100.0)]
	slider.add_theme_stylebox_override("slider", _style(LINE, 4, 3))
	slider.add_theme_stylebox_override("grabber_area", _style(Color("a9c5af"), 4, 3))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(Color("91b39b"), 4, 3))
	var focus := _style(Color.TRANSPARENT, 8, 0, NAVY)
	focus.set_border_width_all(2)
	slider.add_theme_stylebox_override("focus", focus)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.84, 1.0])
	gradient.colors = PackedColorArray([NAVY, NAVY, Color(NAVY, 0.0)])
	var thumb := GradientTexture2D.new()
	thumb.gradient = gradient
	thumb.width = 22
	thumb.height = 22
	thumb.fill = GradientTexture2D.FILL_RADIAL
	thumb.fill_from = Vector2(0.5, 0.5)
	thumb.fill_to = Vector2(0.5, 0.0)
	slider.add_theme_icon_override("grabber", thumb)
	var highlight_gradient := Gradient.new()
	highlight_gradient.offsets = PackedFloat32Array([0.0, 0.60, 0.64, 0.84, 1.0])
	highlight_gradient.colors = PackedColorArray([GOLD, GOLD, NAVY, NAVY, Color(NAVY, 0.0)])
	var highlight_thumb := thumb.duplicate() as GradientTexture2D
	highlight_thumb.gradient = highlight_gradient
	highlight_thumb.width = 26
	highlight_thumb.height = 26
	slider.add_theme_icon_override("grabber_highlight", highlight_thumb)
	row.add_child(slider)
	# Connect after setting the initial value: opening settings emits no changes.
	slider.value_changed.connect(func(amount: float) -> void:
		percentage.text = "%d%%" % roundi(amount * 100.0)
		slider.tooltip_text = "%s · %d%% · Left/right to adjust" % [text, roundi(amount * 100.0)]
		action_requested.emit("%s:%.2f" % [action, amount])
	)
	return slider


func _new_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_body.add_child(grid)
	_panel_grid = grid
	return grid


func _catalog_card(grid: GridContainer, item: Dictionary) -> VBoxContainer:
	var card := _quiet_card(PAPER, 16, 12)
	card.name = "Decor%d" % int(item["kind"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(card)
	var content := _stack(8)
	card.add_child(content)
	content.add_child(_decoration_thumbnail(int(item["kind"]), str(item["name"])))
	var title := _wrapped_label(str(item["name"]), 17, NAVY)
	title.custom_minimum_size.y = 44.0
	content.add_child(title)
	var description := _wrapped_label(str(item.get("description", item.get("desc", ""))), 14, MUTED)
	description.custom_minimum_size.y = 42.0
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	return content


func _decoration_thumbnail(kind: int, name_text: String) -> Control:
	var path := "res://assets/icons/decor_%02d.png" % kind
	var preview := _rendered_thumbnail(path, SWATCHES[posmod(kind, SWATCHES.size())])
	preview.tooltip_text = name_text
	return preview


func _rendered_thumbnail(path: String, fallback_color: Color) -> PanelContainer:
	var texture := _preview_texture(path)
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", _style(Color("f0efdf"), 20, 4, Color("e4e4d3")))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture:
		var thumbnail := TextureRect.new()
		thumbnail.name = "RenderedThumbnail"
		thumbnail.texture = texture
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size.y = 160.0
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(thumbnail)
	else:
		# A plain color mark while main's rendered icon is unavailable; no invented art.
		preview.add_child(_color_swatch(fallback_color, 36.0, 160.0))
	return preview


func _preview_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	if _preview_cache.has(path):
		return _preview_cache[path] as Texture2D
	var texture := ResourceLoader.load(path) as Texture2D
	if not texture:
		return null
	var source := texture.get_image()
	if not source or source.is_empty():
		return texture
	if source.is_compressed() and source.decompress() != OK:
		return texture
	# Trim only the rendered backdrop, leaving the source asset unchanged. Cache
	# the atlas so thin/tall objects can use the same 160 px field as wider pieces.
	var background := source.get_pixel(0, 0)
	var low := Vector2i(source.get_width(), source.get_height())
	var high := Vector2i(-1, -1)
	for y in range(0, source.get_height(), 2):
		for x in range(0, source.get_width(), 2):
			var pixel := source.get_pixel(x, y)
			var difference := maxf(absf(pixel.r - background.r), maxf(absf(pixel.g - background.g), absf(pixel.b - background.b)))
			var foreground := pixel.a > 0.05 and (background.a < 0.05 or difference > 0.045)
			if foreground:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x >= low.x and high.y >= low.y:
		var region := Rect2(Vector2(low), Vector2(high - low + Vector2i(2, 2))).grow(12.0)
		region = region.intersection(Rect2(Vector2.ZERO, Vector2(source.get_size())))
		var cropped := AtlasTexture.new()
		cropped.atlas = texture
		cropped.region = region
		cropped.filter_clip = true
		_preview_cache[path] = cropped
	else:
		_preview_cache[path] = texture
	return _preview_cache[path] as Texture2D


func _neighbor_identity(who: int, name_text: String, location: String, friendship: String = "", portrait_size: float = 64.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := _preview_texture("res://assets/icons/neighbor_%02d.png" % who)
	var portrait_box := CenterContainer.new()
	portrait_box.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_box)
	if portrait:
		var image := TextureRect.new()
		image.name = "NeighborPortrait"
		image.texture = portrait
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(portrait_size, portrait_size)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_box.add_child(image)
	else:
		portrait_box.add_child(_color_swatch(Color("a8d8bd") if who == 0 else Color("accbd3"), portrait_size * 0.65, portrait_size))
	var identity := _stack(5)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var name_label := _label(name_text, 20, NAVY)
	name_label.custom_minimum_size.x = 72
	identity.add_child(name_label)
	var details := location
	if not friendship.is_empty():
		details += (" · " if not details.is_empty() else "") + friendship
	if not details.is_empty():
		identity.add_child(_wrapped_label(details, 13, MUTED))
	return row


func _dialog_identity(speaker: String) -> void:
	_conversation = true
	_set_backdrop_alpha(0.12)
	var bubble := _style(PAPER, 38, 24, Color("e3d8be"))
	bubble.corner_radius_top_left = 18
	bubble.corner_radius_bottom_right = 58
	bubble.corner_radius_bottom_left = 30
	bubble.shadow_color = Color(0.12, 0.21, 0.19, 0.16)
	bubble.shadow_size = 12
	bubble.shadow_offset = Vector2(0, 6)
	_panel_padding = 24
	if _bubble_style == null:
		var paper_texture: Texture2D
		if ResourceLoader.exists("res://assets/ui/dialogue_paper.svg"):
			paper_texture = load("res://assets/ui/dialogue_paper.svg") as Texture2D
		else:
			var paper_image := Image.load_from_file("res://assets/ui/dialogue_paper.svg")
			if paper_image:
				paper_texture = ImageTexture.create_from_image(paper_image)
		if paper_texture:
			_bubble_style = StyleBoxTexture.new()
			_bubble_style.texture = paper_texture
			for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_bubble_style.set_texture_margin(edge, 60)
				_bubble_style.set_content_margin(edge, 24)
	_panel.add_theme_stylebox_override("panel", _bubble_style if _bubble_style else bubble)
	for child in _panel_intro.get_children():
		_panel_intro.remove_child(child)
		child.queue_free()
	var who := NEIGHBORS.find(speaker)
	var tab := _quiet_card(SWATCHES[posmod(who, SWATCHES.size())], 20, 10)
	tab.name = "SpeakerTab"
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.rotation = -0.035
	var top := _panel_header.get_child(0)
	var eyebrow := top.get_child(0)
	top.remove_child(eyebrow)
	eyebrow.queue_free()
	top.add_child(tab)
	top.move_child(tab, 0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.move_child(spacer, 1)
	_panel_intro.hide()
	_dialogue_responses.show()
	_panel_stack.add_theme_constant_override("separation", 6)
	_panel_body.add_theme_constant_override("separation", 6)
	if who >= 0:
		tab.add_child(_neighbor_identity(who, speaker, "", "", 32))
	else:
		tab.add_child(_label(speaker, 22, NAVY))


func _add_dialogue_text(text: String, speaker: String) -> void:
	_dialogue_label = _wrapped_label(text, 22, NAVY)
	_dialogue_label.name = "DialogueText"
	_dialogue_label.add_theme_constant_override("line_spacing", 6)
	_dialogue_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_dialogue_label.visible_characters = 0
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dialogue_label.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_reveal_dialogue()
			_dialogue_label.accept_event()
	)
	_panel_body.add_child(_dialogue_label)
	_dialogue_speaker = NEIGHBORS.find(speaker)
	_dialogue_clock = 0.0
	_typing = not text.is_empty()
	set_process(_typing)
	if not _typing:
		dialogue_finished.emit()


func _process(delta: float) -> void:
	if not _typing or not is_instance_valid(_dialogue_label):
		return
	_dialogue_clock += delta
	if _dialogue_clock < 1.0 / 15.0:
		return
	# Never burst voice events after a stalled browser frame.
	_dialogue_clock = 0.0
	var index := _dialogue_label.visible_characters
	while index < _dialogue_label.text.length() and _dialogue_label.text.substr(index, 1).strip_edges().is_empty():
		index += 1
	if index < _dialogue_label.text.length():
		_dialogue_label.visible_characters = index + 1
		dialogue_blip.emit(_dialogue_speaker, index)
	if index + 1 >= _dialogue_label.text.length():
		_typing = false
		_dialogue_label.visible_characters = -1
		set_process(false)
		dialogue_finished.emit()


func _reveal_dialogue() -> bool:
	if not _typing:
		return false
	_typing = false
	set_process(false)
	if is_instance_valid(_dialogue_label):
		_dialogue_label.visible_characters = -1
	dialogue_finished.emit()
	return true


func _stop_dialogue() -> void:
	var interrupted := _typing
	_typing = false
	set_process(false)
	_dialogue_label = null
	# Natural completion and reveal already emitted; interruption emits only once.
	if interrupted:
		dialogue_finished.emit()


func is_title_active() -> bool:
	return _title_active


func is_open() -> bool:
	return _panel_open


func set_safe_area_insets(insets: Vector4) -> void:
	# Logical viewport pixels: left, top, right, bottom. Platform may supply CSS env values.
	_external_safe_area = true
	_safe_insets = insets
	_queue_layout()


func _orbit_illustration(height: float, index: int = 0) -> Control:
	var drawing := OrbitMotif.new()
	drawing.custom_minimum_size.y = height
	drawing.seed_index = index
	drawing.planet_color = SWATCHES[posmod(index, SWATCHES.size())]
	return drawing


func _divider() -> HSeparator:
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _style(LINE, 1, 1))
	return rule


func _compact_panel_header() -> void:
	var dismiss := _panel_header.find_child("ClosePanel", true, false) as Button
	if dismiss:
		dismiss.custom_minimum_size = Vector2(48.0, 48.0)
	_panel_body.add_theme_constant_override("separation", 12)


func _compact_button(text: String, accent: bool = false) -> Button:
	var button := _button(text, accent)
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	return button


func _quiet_card(color: Color, radius: int, padding: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(color, radius, padding))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _color_swatch(color: Color, diameter: float, height: float) -> CenterContainer:
	var center := CenterContainer.new()
	center.custom_minimum_size.y = height
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(diameter, diameter)
	circle.add_theme_stylebox_override("panel", _style(color, int(diameter * 0.5), 0, color.darkened(0.12)))
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(circle)
	return center


func _empty_state(title: String, body: String) -> void:
	var card := _card(PAPER, 18, 18)
	_panel_body.add_child(card)
	var content := _stack(9)
	card.add_child(content)
	content.add_child(_wrapped_label(title, 19, NAVY))
	content.add_child(_wrapped_label(body, 16, MUTED))


func _wrapped_label(text: String, font_size: int, color: Color) -> Label:
	var result := _label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


func _stack(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _button(text: String, accent: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(48.0, 48.0)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size", 16)
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, NAVY)
	result.add_theme_color_override("font_disabled_color", MUTED)
	var normal := _style(Color("c9dfc5") if accent else Color("f5ecd9"), 22, 16, Color("d6ceb8"))
	normal.shadow_color = Color("b7b79d")
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 3)
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", _style(Color("e8eedb"), 16, 16, Color("a7bda6")))
	result.add_theme_stylebox_override("pressed", _style(Color("c6ddc7"), 16, 16, MUTED))
	result.add_theme_stylebox_override("disabled", _style(Color("edece2"), 16, 16))
	var focus := _style(Color.TRANSPARENT, 16, 0, NAVY)
	focus.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus)
	return result


func _size_footer_button(button: Button, minimum_width: float) -> void:
	# Ellipsis removes text from Button's minimum-width calculation in Godot.
	# These short persistent labels must keep their natural width in the flow row.
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.custom_minimum_size = Vector2(minimum_width, 44.0)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)


func _card(color: Color, radius: int, padding: int) -> PanelContainer:
	var result := PanelContainer.new()
	var style := _style(color, radius, padding)
	style.shadow_color = Color(0.10, 0.18, 0.20, 0.12)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	result.add_theme_stylebox_override("panel", style)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _style(color: Color, radius: int, padding: int, border: Color = LINE) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(padding)
	result.border_color = border
	if radius > 0:
		result.set_border_width_all(1)
	result.corner_detail = 12
	return result


func _update_browser_safe_area(viewport_size: Vector2) -> void:
	if not OS.has_feature("web"):
		return
	# CSS pixels must be converted to logical Godot pixels after canvas scaling.
	var encoded = JavaScriptBridge.eval("""(function() {
		var p = document.createElement('div');
		p.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
		document.body.appendChild(p);
		var s = getComputedStyle(p);
		var a = [parseFloat(s.paddingLeft)||0,parseFloat(s.paddingTop)||0,parseFloat(s.paddingRight)||0,parseFloat(s.paddingBottom)||0,innerWidth,innerHeight];
		p.remove(); return JSON.stringify(a);
	})()""")
	if encoded is String:
		var values = JSON.parse_string(encoded)
		if values is Array and values.size() == 6:
			var scale := viewport_size / Vector2(maxf(float(values[4]), 1), maxf(float(values[5]), 1))
			_safe_insets = Vector4(float(values[0]) * scale.x, float(values[1]) * scale.y, float(values[2]) * scale.x, float(values[3]) * scale.y)


func set_touch_controls_active(active: bool, reserved_height: float = 200.0) -> void:
	_ensure_ui()
	var next_height := maxf(0.0, reserved_height)
	if _touch_controls_active == active and is_equal_approx(_touch_reserved_height, next_height):
		return
	_touch_controls_active = active
	_touch_reserved_height = next_height
	_sync_footer()
	_queue_layout()
