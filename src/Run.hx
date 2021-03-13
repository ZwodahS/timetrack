import datetime.DateTime;

import Entry;

using StringTools;

@:structInit class Flags {
	public var tagFilter: String = null;
	public var rest: Array<String> = null;

	public function new() {}
}

@:structInit class FlagsToParse {
	public var tagFilter: Bool = false;
}

class Run {
	public static var db: Database;
	public static var interpreterMode = false;
	public static var redact = false;

	static public function main() {
		var args = Sys.args();
		if (Sys.getEnv("HAXELIB_RUN") == "1") args.pop();

		// TODO: Fix for windows if necessary
		var home = Sys.getEnv("HOME");
		Config.init();
		Config.loadFromFile('${home}/.ttconfig');
		var interpreter = false;
		var dataPath = "timesheet.json";
		var createFile = false;
		var commands = [];
		while (args.length > 0) {
			if (args[0].startsWith('-') && commands.length > 0) {
				help();
				return;
			}
			if (args[0] == '-i') {
				interpreter = true;
				args.shift();
			} else if (args[0] == '--timestart') {
				args.shift();
				var arg = args.shift();
				try {
					var ts = Std.parseInt(arg);
					if (ts < 0 || ts > 23) {
						Console.log('invalid timestart: ${arg}');
						return;
					}
					Config.dayStart = ts;
				} catch (e: haxe.Exception) {
					Console.log('invalid timestart: ${arg}');
					return;
				}
			} else if (args[0] == '-f') {
				args.shift();
				dataPath = args.shift();
			} else if (args[0] == '-c') {
				args.shift();
				createFile = true;
			} else if (args[0] == '--redact') {
				args.shift();
				Run.redact = true;
			} else if (args[0].startsWith('-')) {
				Console.log('invalid option ${args[0]}');
				return;
			} else {
				while (args.length > 0)
					commands.push(args.shift());
			}
		}

		if (createFile && !sys.FileSystem.exists(dataPath)) {
			sys.io.File.saveContent(dataPath, haxe.format.JsonPrinter.print({entries: []}));
		}

		if (!loadData(dataPath)) {
			Console.log('Fail to read file: ${dataPath}');
			Console.log('-c to create if the file did not exists');
			return;
		}

		if (interpreter) {
			startInterpreter();
			return;
		}

		if (commands.length == 0) commands.push("info");
		Run.interpreterMode = false;
		var command = commands.join(" ");
		processCommand(command);
		if (Run.db.isDirty) save();
	}

	static function help() {
		pushPrefix('');
		Console.log("timetrack [-c] [--redact] [-i] [-f path] [command] [command args]");
		Console.log("  -c create data file if not found");
		Console.log("  -i interpreter mode");
		Console.log("  -f path to data.json, default to current directory timesheet.json");
		Console.log("   --timestart [0 < int < 23] set the dayStart time. This will override the one in .ttconfig");
		Console.log("  --redact hide descriptions when printing entries");
		Console.log("Commands: ");
		pushPrefix("    ");
		Console.log("<magenta>info</>".rpad(" ", 40) + "print current week screen");
		Console.log("<magenta>cancel</>".rpad(" ", 40) + "undo a [start] command");
		Console.log("<magenta>start</> [description]".rpad(" ", 40) + "start a new entry");
		Console.log("<magenta>finish</> [description]".rpad(" ", 40)
			+ "finish the current entry with description");
		Console.log("<magenta>split</> [description]".rpad(" ", 40)
			+ "finish the current entry with description and start a new entry");
		Console.log("<magenta>description</> [description]".rpad(" ", 40)
			+ "set the description of the last entry");
		Console.log("<magenta>day</> [offset]".rpad(" ", 40) + "print day information");
		Console.log("<magenta>week</> [offset]".rpad(" ", 40) + "print week information");
		Console.log("<magenta>unfinish</>".rpad(" ", 40) + "Undo a finish");
		Console.log("<magenta>overview</> [maxWeek: Int]".rpad(" ", 40) + "show overview");
		Console.log("<magenta>last</> [numberOfEntries: Int]".rpad(" ", 40) + "print the last few entries");
		Console.log("<magenta>help</>".rpad(" ", 40) + "print this help");
		Console.log("<magenta>config</>".rpad(" ", 40) + "print the default .ttconfig");
		if (Run.interpreterMode) {
			Console.log("<magenta>save</>".rpad(" ", 40) + "save any unsaved changes");
			Console.log("<magenta>clear</>".rpad(" ", 40) + "clear the screen");
			Console.log("<magenta>quit</>".rpad(" ", 40) + "quit the interpreter");
		}
		popPrefix();
		popPrefix();
	}

	static function loadData(path): Bool {
		try {
			Run.db = Database.loadFromFile(path);
			return true;
		} catch (e: haxe.Exception) {
			return false;
		}
	}

	static function startInterpreter() {
		Run.interpreterMode = true;
		Console.logPrefix = '';
		printCurrentState();
		@:privateAccess var r = Console.format('<light_green>></> ', Console.formatMode);
		while (true) {
			Console.log();
			if (Run.db.isDirty) {
				@:privateAccess var result = Console.format('<red>(Unsaved) ></> ', Console.formatMode);
				Console.print(result.formatted);
			} else {
				Console.print(r.formatted);
			}
			var command = Sys.stdin().readLine();
			if (processCommand(command)) break;
		}
	}

	static function quit(): Bool {
		if (Run.db.isDirty) {
			Console.log('<red>Data not saved</>');
			return false;
		}
		return true;
	}

	static function parseFlags(args: Array<String>, flagsToParse: FlagsToParse): Flags {
		var ind = 0;
		var flags = new Flags();
		while (ind < args.length) {
			if (args[ind] == "--tag" || args[ind] == "-t") {
				if (flags.tagFilter != null) {
					Console.log('<red>Double tag filter not implemented</>');
					return null;
				}
				if (args.length < 2) {
					Console.log('<red>Missing tag value</>');
					return null;
				}
				args.shift();
				flags.tagFilter = args.shift();
				continue;
			}
			break;
		}
		flags.rest = args;
		return flags;
	}

	static function processCommand(command: String): Bool {
		command = command.trim();
		var split = command.split(" ");
		// convert aliases if any
		var mapped = Config.aliases[split[0]];
		if (mapped != null) {
			split[0] = mapped;
			command = split.join(" ");
			split = command.split(" ");
		}
		var c = split.shift();
		switch (c) {
			case "quit":
				return quit();
			case "info":
				clear();
				printCurrentState(split);
			case "clear":
				clear();
			case "cancel":
				cancel();
			case "start":
				checkin(split.join(" "));
			case "finish":
				checkout(split.join(" "));
			case "unfinish":
				uncheckout();
			case "split":
				checkoutin(split.join(" "));
			case "save":
				save();
			case "description":
				updateDescription(split.join(" "));
			case "day":
				printDayState(split);
			case "week":
				printWeekStats(split);
			case "last":
				last(split);
			case "help":
				help();
			case "overview":
				var maxWeek = -1;
				if (split.length > 0) {
					maxWeek = Std.parseInt(split[0]);
				}
				printOverview(maxWeek);
			case "config":
				var config = Config.getDefault();
				var string = haxe.format.JsonPrinter.print(config, "  ");
				haxe.Log.trace(string, null);
			default:
				Console.log('Invalid command: <red>${c}</>');
				help();
		}
		return false;
	}

	static function last(args: Array<String>) {
		var count = 20;
		if (args.length != 0) {
			try {
				count = Std.parseInt(args[0]);
			} catch (e: haxe.Exception) {
				Console.log('invalid value: ${args[0]}');
				return;
			}
		}
		pushPrefix("    ");
		for (s in getLastEntriesFormattedStrings(count)) {
			Console.log(s);
		}
		popPrefix();
	}

	static function getLastEntriesFormattedStrings(i: Int): Array<String> {
		var start = Run.db.allEntries.length - i;
		if (start < 0) start = 0;
		return formatEntries(Run.db.allEntries.slice(start));
	}

	static function formatEntries(entries: Array<Entry>): Array<String> {
		var formatted: Array<String> = [];
		var day: Null<DateTime> = null;
		var duration = 0;
		for (entry in entries) {
			var entryDay = entry.day;
			var prefix = '';
			if (day == null || entryDay != day) {
				day = entryDay;
				if (duration != 0) formatted.push(prefix.lpad(' ', 25 + 21)
					+ '[${formatDuration(duration)}]');
				duration = 0;
				prefix = '(${formatDayOfWeek(entryDay.getWeekDay(true) - 1)}) ${day.format("%F")}';
			}
			duration += entry.getDuration();
			prefix = prefix.lpad(' ', 25);
			formatted.push('<blue>${prefix}</> ${formatEntry(entry)}');
		}
		formatted.push("".lpad(' ', 25 + 21) + '[${formatDuration(duration)}]');
		return formatted;
	}

	static function updateDescription(description: String) {
		if (Run.db.updateLastDescription(description)) {
			Console.log('<green>Description updated</>');
		} else {
			Console.log('<red>No entry found</>');
		}
	}

	static function save() {
		if (Run.db.save()) {
			Console.log('<green>Saved</>');
		} else {
			Console.log('<red>Fail to save data</>');
		}
	}

	static function checkin(description: String) {
		if (Run.db.checkin(null, description)) {
			Console.log('<green>Activity Started</>');
		} else {
			Console.log('<red>Current Activity not finish</>');
		}
	}

	static function checkout(description: String) {
		if (Run.db.checkout(description)) {
			Console.log('<green>Successfully logged</>');
		} else {
			Console.log('<red>No active activity</>');
		}
	}

	static function checkoutin(description: String) {
		if (Run.db.checkoutin(description)) {
			Console.log('<green>Successfully Split</>');
		} else {
			Console.log('<red>No active activity</>');
		}
	}

	static function uncheckout() {
		if (Run.db.uncheckout()) {
			Console.log('<green>Successfully reverted</>');
		} else {
			Console.log('<red>Current Activity not finished.</>');
		}
	}

	static function cancel() {
		if (Run.db.undoCheckin()) {
			Console.log('<green>Successfully delete last entry</>');
		} else {
			Console.log('<red>No active activity</>');
		}
	}

	static function clear() {
		// this only run during interpreterMode
		if (Run.interpreterMode) Sys.command("clear");
	}

	static function generateHeatmapHourHeader(distance: Int): String {
		var start = Config.dayStart;
		if (distance >= 6) {
			var str = [];
			while (start != Config.dayStart || str.length == 0) {
				str.push('|<blue>${formatInt(start, false)}:00</>');
				start += 1;
				if (start == 24) start = 0;
			}
			return str.join("");
		} else {
			throw "not implemented";
		}
	}

	static function formatHeatmap(heat: Array<Int>, ?threshold: Array<Int> = null): String {
		if (threshold == null) threshold = Config.heatmapThreshold;
		var str = "";
		for (i in heat) {
			if (i >= threshold[0]) {
				str += '${Config.heatmapColor.threshold[0]}■</>';
			} else if (i >= threshold[1]) {
				str += '${Config.heatmapColor.threshold[1]}■</>';
			} else if (i >= threshold[2]) {
				str += '${Config.heatmapColor.threshold[2]}■</>';
			} else if (i > 0) {
				str += '${Config.heatmapColor.threshold[3]}■</>';
			} else if (i == 0) {
				str += '${Config.heatmapColor.zero}■</>';
			} else if (i == -1) {
				str += '${Config.heatmapColor.now}■</>';
			}
		}
		return str;
	}

	static function printDayState(args: Array<String>) {
		var dt = DateTime.local();
		if (args.length != 0) {
			try {
				var i = Std.parseInt(args[0]);
				dt += Day(i);
			} catch (e: haxe.Exception) {
				Console.log('invalid value: ${args[0]}');
			}
		}
		pushPrefix("    ");

		var day = Run.db.getDayEntries(dt);

		var str = 'Data for <blue>${formatDate(dt)}</> | ';
		if (day == null || day.entries.length == 0) {
			str += '<red>No Entries</>';
		} else {
			str += '${formatDuration(day.totalDuration())}';
		}
		Console.log();
		Console.log(str);
		Console.log();
		if (day != null && day.entries.length != 0) {
			var heat = day.getHeatmap(10);
			var header = generateHeatmapHourHeader(6);
			Console.log(header);
			Console.log(formatHeatmap(heat));
			Console.log();
		}

		if (day != null) {
			for (e in day.entries) {
				Console.log(formatEntry(e));
			}
		}
		popPrefix();
	}

	static function printOverview(maxWeek: Int = -1) {
		if (Run.db.entriesByWeekArray.length == 0) return; // 0 entries
		var weekStart = Run.db.entriesByWeekArray[0].weekStart;
		var weekEnd = Database.getWeekStart(DateTime.local());
		if (maxWeek > 0) {
			weekStart = weekEnd - Week(maxWeek - 1);
		}

		var heatmapStrings = [];

		var entries: Array<Entry> = [];
		while (weekStart <= weekEnd) {
			var str = '<blue>${formatDate(weekStart)} - ${formatDate(weekStart + Day(6))}</>';
			var heat = [];
			var week = Run.db.entriesByWeek[Database.getDayKey(weekStart)];
			if (week == null) {
				heat = [0, 0, 0, 0, 0, 0, 0];
			} else {
				for (day in week.entriesByDayArray) {
					var duration = day.totalDuration();
					heat.push(Std.int(duration / Config.perDayHourThreshold / DateTime.SECONDS_IN_HOUR * 100));
					for (e in day.entries) entries.push(e);
				}
			}
			str += ' ${formatHeatmap(heat)} [${formatDuration(week.totalDuration())}]';
			heatmapStrings.push(str);
			weekStart += Week(1);
		}

		pushPrefix("    ");
		Console.log('    Current number of entries: <green>${Run.db.allEntries.length}</>');
		Console.log('    Number of days tracked: <green>${Run.db.entriesByDayArray.length}</>');
		Console.log();
		printTwoColumn(heatmapStrings, []);
		popPrefix();
	}

	static function formatDate(dt: DateTime, format: String = "%Y-%m-%d"): String {
		format = format.replace("%b", formatMonth(dt.getMonth()));
		return dt.format(format);
	}

	static function formatMonth(m: Int): String {
		switch (m) {
			case 1:
				return "Jan";
			case 2:
				return "Feb";
			case 3:
				return "Mar";
			case 4:
				return "Apr";
			case 5:
				return "May";
			case 6:
				return "Jun";
			case 7:
				return "Jul";
			case 8:
				return "Aug";
			case 9:
				return "Sep";
			case 10:
				return "Oct";
			case 11:
				return "Nov";
			case 12:
				return "Dec";
			default:
				return '';
		}
	}

	static function printCurrentState(args: Array<String> = null) {
		if (args == null) args = [];
		printWeekStats(args);
	}

	static function formatDuration(seconds: Int): String {
		var hours: Int = Std.int(seconds / DateTime.SECONDS_IN_HOUR);
		seconds -= DateTime.SECONDS_IN_HOUR * hours;
		var minutes: Int = Std.int(seconds / DateTime.SECONDS_IN_MINUTE);
		seconds -= DateTime.SECONDS_IN_MINUTE * minutes;
		return '${formatInt(hours)}h ${formatInt(minutes)}m ${formatInt(seconds)}s';
	}

	static function formatInt(i: Int, padzero = 2, color = true): String {
		var st = '${i}';
		if (padzero > 0) st = st.lpad('0', padzero);
		if (!color) return st;
		if (i > 0) return '<green>${st}</>';
		return '<red>${st}</>';
	}

	static function formatEntry(e: Entry): String {
		var timeFormatted = '';
		if (e.timeEnd == null) {
			timeFormatted = '${e.timeStart.format("%T")} - <green>Current</>  ';
		} else {
			timeFormatted = '${e.timeStart.format("%T")} - ${e.timeEnd.format("%T")} ';
		}
		var duration = '[${formatDuration(e.getDuration())}] ';
		var description = '${formatDescription(e.description)}';
		return timeFormatted + duration + description;
	}

	static function formatDescription(s: String): String {
		var i = s.indexOf('#');
		while (i != -1) {
			var end = s.indexOf(' ', i);
			if (end == -1) end = s.length;
			s = s.substring(0, i) + '<blue>' + s.substring(i, end) + '</>' + s.substring(end);
			i = s.indexOf('#', end + 9);
		}
		return s;
	}

	static function printWeekStats(args: Array<String> = null) {
		if (args == null) args = [];
		var flags = parseFlags(args, {tagFilter: true});
		args = flags.rest;
		var dt = Database.getStoredDate(DateTime.local());
		if (args.length != 0) {
			try {
				var i = Std.parseInt(args[0]);
				dt += Week(i);
			} catch (e: haxe.Exception) {
				Console.log('invalid value: ${args[0]}');
			}
		}
		var oldPrefix = Console.logPrefix;
		Console.log();
		pushPrefix("    ");
		var weekStart = Database.getWeekStart(dt);
		Console.log('           Week starting <green>${weekStart.format("%F")}</green>');
		Console.log();
		var week = Run.db.getWeekEntries(dt);
		var thisWeek = Database.getWeekStart();

		var entries: Array<Entry> = [];
		{ // top header
			var total = 0;
			var header = generateHeatmapHourHeader(6);
			var startOfDurationString = 0;
			var heatmapTotal: Array<Int> = [for (i in 0...6 * 24) 0];
			Console.log("".lpad(" ", 12) + header);
			for (ind => day in week.entriesByDayArray) {
				for (e in day.entries) {
					if (flags.tagFilter == null || e.hasTag(flags.tagFilter)) entries.push(e);
				}

				var prefix = '<blue>${formatDayOfWeek(ind).lpad(" ", 9)}</> - ';
				var heat = day.getHeatmap(10, -1, flags.tagFilter);
				for (i => h in heat) {
					if (h > 0) heatmapTotal[i] += h;
				}
				var duration = day == null ? 0 : day.totalDuration(flags.tagFilter);
				total += duration;
				var durationString = formatDuration(duration);
				var str = prefix + formatHeatmap(heat) + " ";
				if (startOfDurationString == 0) startOfDurationString = Console.stripFormatting(str).length;
				str += durationString;
				Console.log(str);
			}

			for (ind => h in heatmapTotal) {
				heatmapTotal[ind] = Std.int(h / 7);
			}
			var prefix = "<blue>" + "[Total]".lpad(" ", 9) + "</> - ";
			var durationString = formatDuration(total);
			var str = prefix + formatHeatmap(heatmapTotal) + " " + durationString;
			Console.log(str);
		}

		Console.log();
		Console.log();

		if (entries.length > 0) {
			var formattedEntries = formatEntries(entries);
			for (s in formattedEntries) Console.log(s);
		} else {
			Console.log('<red>No Records</>');
		}
		popPrefix();
	}

	static function formatDayOfWeek(d: Int): String {
		switch (d) {
			case 0:
				return "Monday";
			case 1:
				return "Tuesday";
			case 2:
				return "Wednesday";
			case 3:
				return "Thursday";
			case 4:
				return "Friday";
			case 5:
				return "Saturday";
			case 6:
				return "Sunday";
			default:
		}
		return '';
	}

	static var prefixStack: Array<String> = [];

	static function pushPrefix(prefix: String) {
		prefixStack.push(Console.logPrefix);
		Console.logPrefix = prefix;
	}

	static function popPrefix() {
		if (prefixStack.length == 0) return;
		Console.logPrefix = prefixStack.pop();
	}

	static function printTwoColumn(leftColumns: Array<String>, rightColumns: Array<String>) {
		var leftWidth = 0;
		for (s in leftColumns) {
			var strip = Console.stripFormatting(s);
			if (strip.length > leftWidth) leftWidth = strip.length;
		}
		leftWidth += 2;

		var maxIndex = leftColumns.length < rightColumns.length ? leftColumns.length : rightColumns.length;
		var i = 0;
		while (i < maxIndex) {
			// normal printing
			var lstrip = Console.stripFormatting(leftColumns[i]);
			var leftPrint = leftColumns[i] + "".lpad(" ", leftWidth - lstrip.length);
			Console.log(leftPrint + "    " + rightColumns[i]);
			i += 1;
		}
		if (leftColumns.length < rightColumns.length) {
			var pad = "".lpad(" ", leftWidth + 4);
			while (i < rightColumns.length) {
				Console.log(pad + rightColumns[i]);
				i += 1;
			}
		} else if (leftColumns.length > rightColumns.length) {
			while (i < leftColumns.length) {
				Console.log(leftColumns[i]);
				i += 1;
			}
		}
	}
}
