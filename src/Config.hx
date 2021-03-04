typedef ConfigStruct = {
	?dayStart: Int,
	?aliases: Dynamic
}

class Config {
	public static var dayStart = 6;
	public static var aliases: Map<String, String>;

	public static var heatmapColor = {
		threshold: ["<bold,green>", "<green>", "<dim,light_green>", "<dim,green>"],
		zero: "<dim,light_black>",
		current: "<light_yellow>",
	}
	public static var heatmapThreshold: Array<Int> = [100, 66, 33];

	public static function init() {
		Config.aliases = new Map<String, String>();
	}

	public static function loadFromFile(path: String) {
		if (!sys.FileSystem.exists(path)) return;
		try {
			var data = sys.io.File.getContent(path);
			var config: ConfigStruct = haxe.Json.parse(data);
			if (config.dayStart != null) Config.dayStart = config.dayStart;
			if (config.aliases != null) {
				for (key in Reflect.fields(config.aliases)) {
					var command: String = Reflect.field(config.aliases, key);
					Config.aliases[key] = command;
				}
			}
		} catch (e: haxe.Exception) {
			Console.log('Error in config file');
		}
	}
}
