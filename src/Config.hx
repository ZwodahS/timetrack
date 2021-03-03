typedef ConfigStruct = {
	?dayStart: Int,
}

class Config {
	public static var dayStart = 6;

	public static function loadFromFile(path: String) {
		if (!sys.FileSystem.exists(path)) return;
		try {
			var data = sys.io.File.getContent(path);
			var config: ConfigStruct = haxe.Json.parse(data);
			if (config.dayStart != null) Config.dayStart = config.dayStart;
		} catch (e: haxe.Exception) {}
	}
}
