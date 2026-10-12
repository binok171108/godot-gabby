extends Node

const Board = preload("res://drawing_board.gd")
var host: Node
var current := ""
var score := 0
var round_index := 0
var answer := ""
var feedback: Label
var selected := -1
var cards: Array[int] = []
var card_buttons: Array[Button] = []
var matched: Dictionary = {}
var cells: Array[int] = []
var board_buttons: Array[Button] = []
var recipe: Dictionary = {}
var paper_model: Dictionary = {}
var step_index := 0
var board: Control
var audio: AudioStreamPlayer
var tone_stream := AudioStreamGenerator.new()
var tone_playback: AudioStreamGeneratorPlayback
var tone_phase := 0.0
var tone_frequency := 0.0
var tone_remaining := 0.0
var vocabulary: Array = []
var lesson: Dictionary = {}
var generation := 0

func _ready() -> void:
	audio = AudioStreamPlayer.new()
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.bus = "StreamCapture" if AudioServer.get_bus_index("StreamCapture") >= 0 else "Master"
	tone_stream.mix_rate = 48000
	tone_stream.buffer_length = 0.1
	audio.stream = tone_stream
	add_child(audio)
	audio.play()
	tone_playback = audio.get_stream_playback()

func _process(_delta: float) -> void:
	if not tone_playback:
		return
	for sample in range(tone_playback.get_frames_available()):
		var amplitude := sin(tone_phase) * 0.18 if tone_remaining > 0 else 0.0
		tone_phase = fmod(tone_phase + TAU * tone_frequency / 48000, TAU)
		tone_remaining = maxf(0, tone_remaining - 1.0 / 48000)
		tone_playback.push_frame(Vector2(amplitude, amplitude))

func tone(frequency: float) -> void:
	tone_frequency = frequency
	tone_remaining = 0.18

func start(id: String) -> void:
	generation += 1
	current = id
	score = 0
	round_index = 0
	match id:
		"math", "spelling": quiz()
		"memory": memory()
		"caro": caro()
		"cooking": choose_recipe()
		"origami": choose_paper()
		"draw": drawing()
		"piano": piano()
		"english": choose_english()
		"science": choose_science()
		"quests": quests()
		_:
			host.open_panel("Chưa port hoạt động này")
			host.paragraph("Bản Godot chưa có hoạt động: " + id + ". Bản web vẫn giữ nguyên để chơi đầy đủ.")

func finish() -> void:
	host.state.record_score(current, score)
	host.state.save()
	host.open_panel("Hoàn thành!")
	host.paragraph("Cốm nhận %d sao. Tổng cộng: %d sao." % [score, host.state.stars])
	host.option("Chơi lại", func(): start(current))
	tone(880)

func quiz() -> void:
	if round_index >= 5:
		finish()
		return
	host.open_panel("Toán vui" if current == "math" else "Chính tả tiếng Việt")
	host.paragraph("Câu %d / 5 · %d sao" % [round_index + 1, score])
	var choices: Array[String] = []
	if current == "math":
		var left := randi_range(1, 12)
		var right := randi_range(1, 12)
		answer = str(left + right)
		host.paragraph("%d + %d = ?" % [left, right])
		choices = [answer, str(left + right + 1), str(maxi(0, left + right - 2))]
	else:
		var vocabulary := [["cầu vồng", "cầu vòng", "cầu vồnh"], ["ngôi sao", "ngôi xao", "ngồi sao"], ["gia đình", "da đình", "gia đìn"], ["búp bê", "búp bề", "búp bế"], ["khu vườn", "khu vường", "khu vượn"]]
		var question: Array = vocabulary[round_index]
		answer = question[0]
		host.paragraph("Chọn cách viết đúng:")
		for word in question:
			choices.append(word)
	choices.shuffle()
	for choice in choices:
		host.option(choice, func():
			if choice == answer:
				score += 1
				tone(880)
			else:
				tone(220)
			round_index += 1
			quiz())

func memory() -> void:
	host.open_panel("Tìm cặp hình")
	cards = [0, 0, 1, 1, 2, 2, 3, 3]
	cards.shuffle()
	selected = -1
	matched.clear()
	card_buttons.clear()
	var grid := GridContainer.new()
	grid.columns = 4
	host.panel_body.add_child(grid)
	for index in range(cards.size()):
		card_buttons.append(host.button(grid, "?", Vector2.ZERO, Vector2(150, 100), func(): reveal(index)))

func reveal(index: int) -> void:
	var started := generation
	if matched.has(index) or index == selected:
		return
	card_buttons[index].text = ["MÈO", "HOA", "SAO", "BÁNH"][cards[index]]
	if selected < 0:
		selected = index
		return
	var first := selected
	selected = -1
	if cards[first] == cards[index]:
		matched[first] = true
		matched[index] = true
		tone(880)
		if matched.size() == cards.size():
			score = 3
			finish()
	else:
		for item in card_buttons:
			item.disabled = true
		await get_tree().create_timer(0.7).timeout
		if current != "memory" or started != generation or not is_instance_valid(card_buttons[index]):
			return
		card_buttons[first].text = "?"
		card_buttons[index].text = "?"
		for item in card_buttons:
			item.disabled = false

func caro() -> void:
	host.open_panel("Cờ caro — 5 quân liền nhau")
	cells.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	board_buttons.clear()
	var grid := GridContainer.new()
	grid.columns = 6
	host.panel_body.add_child(grid)
	for index in range(36):
		board_buttons.append(host.button(grid, "·", Vector2.ZERO, Vector2(90, 48), func(): place_mark(index)))

func has_line(mark: int) -> bool:
	for row in range(6):
		for column in range(6):
			for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var count := 0
				for offset in range(5):
					var point: Vector2i = Vector2i(column, row) + direction * offset
					if point.x >= 0 and point.x < 6 and point.y >= 0 and point.y < 6 and cells[point.y * 6 + point.x] == mark:
						count += 1
				if count == 5:
					return true
	return false

func place_mark(index: int) -> void:
	if cells[index] != 0:
		return
	cells[index] = 1
	board_buttons[index].text = "X"
	if has_line(1):
		score = 3
		finish()
		return
	var free: Array[int] = []
	for candidate in range(cells.size()):
		if cells[candidate] == 0:
			free.append(candidate)
	if free.is_empty():
		score = 1
		finish()
		return
	var opponent: int = free.pick_random()
	for mark in [1, 2]:
		for candidate in free:
			cells[candidate] = mark
			if has_line(mark):
				opponent = candidate
			cells[candidate] = 0
	cells[opponent] = 2
	board_buttons[opponent].text = "O"
	if has_line(2):
		score = 0
		finish()

func choose_recipe() -> void:
	host.open_panel("Nấu ăn cùng Cakey — bản nút chọn")
	host.paragraph("Dùng công thức gốc. Bản Godot đầu tiên chưa có kéo dụng cụ và hoạt cảnh bếp 3D.")
	host.choice_grid()
	for definition in host.content.recipes:
		host.option(definition.name, func(): recipe = definition; step_index = 0; cooking_step())

func cooking_step() -> void:
	if step_index >= recipe.steps.size():
		score = 3
		finish()
		return
	var step: Dictionary = recipe.steps[step_index]
	host.open_panel(recipe.name + " · Bước %d/%d" % [step_index + 1, recipe.steps.size()])
	host.paragraph(step.say)
	feedback = host.paragraph("")
	if step.has("amount"):
		var amount: Dictionary = step.amount
		var choices: Array[int] = [int(amount.target), int(amount.max) + 5, maxi(0, int(amount.min) - 1)]
		choices.shuffle()
		for value in choices:
			host.option(str(value) + " " + amount.unit, func():
				if value >= amount.min and value <= amount.max:
					step_index += 1
					tone(660)
					cooking_step()
				else:
					feedback.text = "Lượng này chưa phù hợp. Thử lại nhé!")
	else:
		host.option("Thực hiện bước này", func(): step_index += 1; tone(660); cooking_step())

func choose_paper() -> void:
	host.open_panel("Gấp giấy — mẫu gốc")
	host.choice_grid(3)
	for definition in host.content.origami.MODELS:
		host.option(definition.name, func(): paper_model = definition; step_index = 0; paper_step())

func paper_step() -> void:
	if step_index >= paper_model.steps.size():
		score = 3
		finish()
		return
	var step: Dictionary = paper_model.steps[step_index]
	host.open_panel(paper_model.name + " · Bước %d/%d" % [step_index + 1, paper_model.steps.size()])
	host.paragraph(step.say)
	board = Board.new()
	for point in paper_model.shape:
		board.paper.append(Vector2(point[0], point[1]))
	host.panel_body.add_child(board)
	host.paragraph("Bản hướng dẫn: hình tờ giấy ban đầu; chưa có mô phỏng nếp gấp 3D.")
	host.option("Đã gấp xong bước này", func(): step_index += 1; paper_step())

func drawing() -> void:
	host.open_panel("Vẽ tranh của Cốm")
	board = Board.new()
	host.panel_body.add_child(board)
	var row := HBoxContainer.new()
	host.panel_body.add_child(row)
	for color in [["Hồng", "e46d99"], ["Xanh", "52acbd"], ["Tím", "9672cc"], ["Vàng", "e6b04a"]]:
		host.button(row, color[0], Vector2.ZERO, Vector2(130, 45), func(): board.ink = Color(color[1]))
	host.option("Lưu tranh", func():
		var saved: Array = []
		for stroke in board.strokes:
			var points: Array = []
			for point in stroke.points:
				points.append([point.x, point.y])
			saved.append({"color":stroke.color.to_html(),"points":points})
		var file := FileAccess.open(host.state.data_path("drawing.json"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(saved))
			score = 1
			finish())

func piano() -> void:
	host.open_panel("Piano của DJ Catnip")
	host.paragraph("Chạm các phím để chơi nhạc. Âm thanh do Godot tạo, không trích từ phim.")
	var row := HBoxContainer.new()
	host.panel_body.add_child(row)
	var notes := [261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25]
	for index in range(notes.size()):
		host.button(row, ["Đô", "Rê", "Mi", "Fa", "Sol", "La", "Si", "Đô"][index], Vector2.ZERO, Vector2(83, 160), func(): tone(notes[index]))

func choose_english() -> void:
	host.open_panel("Tiếng Anh — chủ đề gốc")
	host.paragraph("Ôn từ vựng bằng nút chọn. Hội thoại/phát âm AI Live chưa chuyển sang Godot.")
	host.choice_grid(3)
	for topic in host.content.englishTopics:
		host.option(topic.title, func(): vocabulary = topic.words.duplicate(); vocabulary.shuffle(); lesson = topic; round_index = 0; english_question())

func english_question() -> void:
	if round_index >= mini(5, vocabulary.size()):
		finish()
		return
	host.open_panel(lesson.title + " · %d/5" % [round_index + 1])
	var word: Array = vocabulary[round_index]
	answer = word[1]
	host.paragraph("Từ “" + str(word[0]) + "” có nghĩa là gì?")
	feedback = host.paragraph("")
	var alternatives: Array[String] = [answer]
	for candidate in vocabulary:
		if alternatives.size() < 3 and not alternatives.has(candidate[1]):
			alternatives.append(candidate[1])
	alternatives.shuffle()
	for choice in alternatives:
		host.option(choice, func():
			if choice == answer:
				score += 1
				round_index += 1
				tone(880)
				english_question()
			else:
				feedback.text = "Chưa đúng. Nghĩ lại một chút nhé!"
				tone(220))

func choose_science() -> void:
	host.open_panel("Khám phá khoa học — nội dung gốc")
	host.choice_grid(3)
	for topic in host.content.scienceTopics:
		host.option(topic.title, func(): lesson = topic; science_questions())

func science_questions() -> void:
	host.open_panel(lesson.title)
	host.choice_grid()
	for question in lesson.questions:
		host.option(question.question, func():
			host.open_panel(lesson.title)
			host.paragraph(question.question)
			host.option("Xem giải thích", func(): host.paragraph(question.answer))
			host.option("Câu hỏi khác", science_questions))

func quests() -> void:
	host.open_panel("Nhiệm vụ & sticker · %d sao" % host.state.stars)
	for quest in host.content.quests:
		var done: bool = host.state.discoveries.has("quest:" + quest.id)
		host.paragraph(("✓ " if done else "○ ") + quest.title + "\n" + quest.hint)
		if done:
			host.paragraph("Sticker: " + quest.sticker.name)
