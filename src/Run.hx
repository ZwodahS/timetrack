import datetime.DateTime;

import Entry;

using StringTools;

class Run {
	public static var db: Database;
	public static var interpreterMode = false;
	public static var redact = false;

	static public function main() {
		var args = Sys.args();

		// TODO: Fix for windows if necessary
		var home = Sys.getEnv("HOME");
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
		Console.log("  --redact hide descriptions when printing entries");
		Console.log("Commands: ");
		pushPrefix("    ");
		Console.log("<magenta>quit</>".rpad(" ", 40) + "quit the interpreter");
		Console.log("<magenta>info</>".rpad(" ", 40) + "print current week screen");
		Console.log("<magenta>clear</>".rpad(" ", 40) + "clear the screen");
		Console.log("<magenta>cancel</>".rpad(" ", 40) + "undo a [start] command");
		Console.log("<magenta>start</>".rpad(" ", 40) + "start a new entry");
		Console.log("<magenta>finish</> [description]".rpad(" ", 40)
			+ "finish the current entry with description");
		Console.log("<magenta>split</> [description]".rpad(" ", 40)
			+ "finish the current entry with description and start a new entry");
		Console.log("<magenta>description</> [description]".rpad(" ", 40)
			+ "set the description of the last entry");
		Console.log("<magenta>day</> [offset]".rpad(" ", 40) + "print day information");
		Console.log("<magenta>week</> [offset]".rpad(" ", 40) + "print week information");
		Console.log("<magenta>unfinish</>".rpad(" ", 40) + "Undo a finish");
		Console.log("<magenta>stats</>".rpad(" ", 40) + "print data stats");
		Console.log("<magenta>last</> [number]".rpad(" ", 40) + "print the last few entries");
		Console.log("<magenta>help</>".rpad(" ", 40) + "print this help");
		if (Run.interpreterMode) {
			Console.log("<magenta>save</>".rpad(" ", 40) + "save any unsaved changes");
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

	static function processCommand(command: String): Bool {
		command = command.trim();
		var split = command.split(" ");
		switch (split[0]) {
			case "quit":
				return quit();
			case "info":
				clear();
				printCurrentState();
			case "clear":
				clear();
			case "cancel":
				cancel();
			case "start":
				checkin();
			case "finish":
				checkout(split.slice(1).join(" "));
			case "unfinish":
				uncheckout();
			case "split":
				checkoutin(split.slice(1).join(" "));
			case "save":
				save();
			case "description":
				updateDescription(split.slice(1).join(" "));
			case "day":
				printDayState(split.slice(1));
			case "week":
				printWeekStats(split.slice(1));
			case "stats":
				stats();
			case "last":
				last(split.slice(1));
			case "help":
				help();
			default:
				Console.log('Invalid command: <red>${split[0]}</>');
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

	static function checkin() {
		if (Run.db.checkin()) {
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

	static function stats() {
		Console.log('Current number of entries: <green>${Run.db.allEntries.length}</>');
		Console.log('Number of days tracked: <green>${Run.db.entriesByDayArray.length}</>');
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
		if (threshold == null) threshold = [100, 66, 33];
		var str = "";
		for (i in heat) {
			if (i >= threshold[0]) {
				str += '<bold,green>■</>';
			} else if (i > threshold[1]) {
				str += '<green>■</>';
			} else if (i > threshold[2]) {
				str += '<dim,light_green>■</>';
			} else if (i > 0) {
				str += '<dim,green>■</>';
			} else if (i == 0) {
				str += '<light_black>■</>';
			} else if (i == -1) {
				str += '<light_yellow>■</>';
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

		var str = 'Data for <blue>${dt.format("%Y %m %d")}</> | ';
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

	static function printCurrentState() {
		printWeekStats([]);
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

	static function printWeekStats(args: Array<String>) {
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
					entries.push(e);
				}

				var prefix = '<blue>${formatDayOfWeek(ind).lpad(" ", 9)}</> - ';
				var heat = day.getHeatmap(10, -1);
				for (i => h in heat) {
					if (h > 0) heatmapTotal[i] += h;
				}
				var duration = day == null ? 0 : day.totalDuration();
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
			if (weekStart != thisWeek && total / DateTime.SECONDS_IN_HOUR < 40) {
				str += ' (<red>Missed 40h Target</>)';
			}
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
