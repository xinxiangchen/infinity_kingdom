extends RefCounted

static var _cache: Dictionary = {}

static func load_texture(resource_path: String) -> Texture2D:
	if _cache.has(resource_path):
		return _cache[resource_path]
	var packed_texture := ResourceLoader.load(resource_path) as Texture2D
	if packed_texture != null:
		_cache[resource_path] = packed_texture
		return packed_texture
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[resource_path] = texture
	return texture
