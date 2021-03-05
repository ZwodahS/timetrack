typedef ConfigStruct = {
	?dayStart: Int,
	?aliases: Dynamic,

	?heatmap: {
		?color: {
			?threshold: Array<String>,
			?zero: String,
			?now: String,
		},
		?threshold: Array<Int>,
		?perDayHourThreshold: Int,
	}
}

class Config {
	public static var dayStart = 6;
	public static var aliases: Map<String, String>;

	public static var heatmapColor = {
		threshold: ["", "", "", ""],
		zero: "",
		now: "",
	}
	public static var heatmapThreshold: Array<Int> = [0, 0, 0];
	public static var perDayHourThreshold = 8;

	public static function init() {
		Config.aliases = new Map<String, String>();
		loadStruct(getDefault());
	}

	public static function loadFromFile(path: String) {
		if (!sys.FileSystem.exists(path)) return;
		try {
			var data = sys.io.File.getContent(path);
			var config: ConfigStruct = haxe.Json.parse(data);
			loadStruct(config);
		} catch (e: haxe.Exception) {
			Console.log('Error in config file');
		}
	}

	public static function loadStruct(config: ConfigStruct) {
		if (config.dayStart != null) Config.dayStart = config.dayStart;
		if (config.aliases != null) {
			for (key in Reflect.fields(config.aliases)) {
				var command: String = Reflect.field(config.aliases, key);
				Config.aliases[key] = command;
			}
		}
		if (config.heatmap != null) {
			if (config.heatmap.color != null) {
				if (config.heatmap.color.threshold != null) {
					for (i in 0...4) {
						if (i >= config.heatmap.color.threshold.length) break;
						Config.heatmapColor.threshold[i] = config.heatmap.color.threshold[i];
					}
				}
				if (config.heatmap.color.zero != null) Config.heatmapColor.zero = config.heatmap.color.zero;
				if (config.heatmap.color.now != null) Config.heatmapColor.now = config.heatmap.color.now;
			}
			if (config.heatmap.threshold != null) {
				for (i in 0...3) {
					if (i >= config.heatmap.threshold.length) break;
					Config.heatmapThreshold[i] = config.heatmap.threshold[i];
				}
			}
			if (config.heatmap.perDayHourThreshold != null) {
				Config.perDayHourThreshold = config.heatmap.perDayHourThreshold;
			}
		}
	}

	public static function getDefault(): ConfigStruct {
		var struct: ConfigStruct = {
			aliases: {},
			dayStart: 6,
			heatmap: {
				color: {
					threshold: ["<bold,green>", "<green>", "<dim,light_green>", "<dim,green>"],
					zero: "<dim,light_black>",
					now: "<light_yellow>",
				},
				threshold: [100, 66, 33],
				perDayHourThreshold: 6,
			}
		}
		return struct;
	}
}
