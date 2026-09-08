@tool
class_name TextureMaskPlayer
extends TextureRect
## 纹理遮罩动画播放器，可用于纯色遮罩或图片显隐。
## 原始 shader 与图案：Copyright © 2021 GlassBrick，MIT 协议（见 LICENSE）。

## 动画正常结束时发出；停止或替换播放不会发出。
signal playback_finished

const MASK_SHADER = preload("texture_mask.gdshader")
## 内置的 8 种遮罩图案。
const PATTERNS: Dictionary = {
	"circle": preload("shader_patterns/circle.png"),
	"curtains": preload("shader_patterns/curtains.png"),
	"diagonal": preload("shader_patterns/diagonal.png"),
	"horizontal": preload("shader_patterns/horizontal.png"),
	"radial": preload("shader_patterns/radial.png"),
	"scribbles": preload("shader_patterns/scribbles.png"),
	"squares": preload("shader_patterns/squares.png"),
	"vertical": preload("shader_patterns/vertical.png"),
}

## 灰度遮罩纹理；留空时使用普通透明度渐变。
@export var mask_texture: Texture2D:
	set(value):
		mask_texture = value
		_sync_material()
## 要显示的图片；留空时绘制纯色遮罩。
@export var content_texture: Texture2D:
	set(value):
		content_texture = value
		_sync_material()
## 纯色遮罩的颜色；设置内容图片后不使用此颜色。
@export var tint: Color = Color.BLACK:
	set(value):
		tint = value
		_sync_material()
## 显示进度：0 完全隐藏，1 完全显示。
@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_sync_material()
## 反转遮罩灰度顺序，与动画倒放相互独立。
@export var inverted: bool = false:
	set(value):
		inverted = value
		_sync_material()

@export_group("Preview")
## 检查器播放按钮使用的动画时长，单位为秒。
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:s") var preview_duration: float = 1.0
@export_tool_button("播放（显示）", "Play") var preview_play: Callable = _preview_play
@export_tool_button("倒放（隐藏）", "PlayBackwards") var preview_reverse: Callable = _preview_reverse
@export_tool_button("停止", "Stop") var preview_stop: Callable = stop

var _shader_material: ShaderMaterial
var _white_texture: GradientTexture2D
var _tween: Tween

## 创建独立材质，避免多个播放器互相影响。
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	_white_texture = GradientTexture2D.new()
	_white_texture.gradient = Gradient.new()
	_white_texture.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = MASK_SHADER
	_sync_material()

func _ready() -> void:
	_sync_material()

## 将当前属性同步到显示纹理和 shader。
func _sync_material() -> void:
	if _shader_material == null:
		return
	# 仅在资源变化时赋值，避免检查器重建打断进度滑条拖动。
	if material != _shader_material:
		material = _shader_material
	var desired_texture: Texture2D = content_texture if content_texture != null else _white_texture
	if texture != desired_texture:
		texture = desired_texture
	_shader_material.set_shader_parameter("mask_texture", mask_texture)
	_shader_material.set_shader_parameter("has_mask", mask_texture != null)
	_shader_material.set_shader_parameter("use_content", content_texture != null)
	_shader_material.set_shader_parameter("tint", tint)
	_shader_material.set_shader_parameter("progress", progress)
	_shader_material.set_shader_parameter("inverted", inverted)

## 按名称选择内置图案；名称无效时返回 false，保留原图案。
func set_pattern(pattern_name: String) -> bool:
	if not PATTERNS.has(pattern_name):
		return false
	mask_texture = PATTERNS[pattern_name]
	return true

## 从起始进度播放到目标进度，替换当前动画；时长不大于 0 时立即完成。
## 时长可能为 0 时，须先连接完成信号，再调用本方法。
func play(from_progress: float = 0.0, to_progress: float = 1.0,
		duration: float = 1.0, transition: Tween.TransitionType = Tween.TRANS_LINEAR,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if not is_inside_tree():
		push_error("TextureMaskPlayer.play() requires a node inside the scene tree.")
		return
	stop()
	progress = from_progress
	if duration <= 0.0:
		progress = to_progress
		playback_finished.emit()
		return
	_tween = create_tween()
	_tween.set_trans(transition).set_ease(easing)
	_tween.tween_property(self, "progress", clampf(to_progress, 0.0, 1.0), duration)
	_tween.finished.connect(_on_finished)

## 暂停当前动画，保留进度。
func pause() -> void:
	if _tween != null and _tween.is_valid():
		_tween.pause()

## 继续已暂停的动画。
func resume() -> void:
	if _tween != null and _tween.is_valid():
		_tween.play()

## 停止动画并保留当前进度，不发出完成信号。
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

## 是否正在播放；暂停或停止时返回 false。
func is_playing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

func _on_finished() -> void:
	_tween = null
	playback_finished.emit()

## 检查器预览：从隐藏播放到显示。
func _preview_play() -> void:
	play(0.0, 1.0, preview_duration)

## 检查器预览：从显示播放到隐藏。
func _preview_reverse() -> void:
	play(1.0, 0.0, preview_duration)

## 节点离开场景树时清理动画。
func _exit_tree() -> void:
	stop()
