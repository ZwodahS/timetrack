class Database {
	public var allEntries: Array<Entry>;
	public var entriesByDay: Map<Int, EntriesByDay>;
	public var entriesByDayArray: Array<EntriesByDay>;

	public var entriesByWeek: Map<Int, EntriesByWeek>;
	public var entriesByWeekArray: Array<EntriesByWeek>;

	public var isDirty: Bool = false;

	public var path: String;

	function new() {
		this.allEntries = [];
		this.entriesByDay = new Map<Int, EntriesByDay>();
		this.entriesByDayArray = [];
		this.entriesByWeek = new Map<Int, EntriesByWeek>();
		this.entriesByWeekArray = [];
	}

	public static function loadFromFile(path): Database {
		var content = sys.io.File.getContent(path);
		var data: {entries: Array<EntryStruct>} = haxe.Json.parse(content);

		var db = new Database();
		for (e in data.entries) {
			var entry = new Entry();
			entry.timeStart = DateTime.fromString(e.timeStart);
			if (e.timeEnd != null) {
				entry.timeEnd = DateTime.fromString(e.timeEnd);
			}
			if (e.description != null) {
				entry.description = e.description;
			}
			db.addEntry(entry);
		}
		db.isDirty = false;
		db.path = path;
		return db;
	}

	public function addEntry(entry: Entry) {
		// Not going to check for consistency for now
		entry.db = this;
		var day = getStoredDate(entry.timeStart);
		var dayKey = getDayKey(day);
		if (this.entriesByDay[dayKey] == null) {
			var weekStart = getWeekStart(day);
			var weekKey = getDayKey(weekStart);
			var week = entriesByWeek[weekKey];
			if (week == null) {
				week = new EntriesByWeek(this, weekStart);
				this.entriesByWeek[weekKey] = week;
				this.entriesByWeekArray.push(week);
			}
			var dayEntries = this.entriesByWeek[weekKey].getDay(day);
			this.entriesByDay[dayKey] = dayEntries;
			this.entriesByDayArray.push(dayEntries);
		}
		entry.index = this.allEntries.length;
		this.allEntries.push(entry);
		this.entriesByDay[dayKey].addEntry(entry);
		this.isDirty = true;
	}

	/**
		This get the stored date for a specific time.
		Note, do not run this on Entry.day, as Entry.day is already floored once.
	**/
	static public function getStoredDate(dt: DateTime): DateTime {
		var dayDT = dt - Hour(Config.dayStart);
		var d = dayDT.snap(Day(Down));
		return d;
	}

	static public function getWeekStart(?dt: DateTime): DateTime {
		if (dt == null) dt = getStoredDate(DateTime.local());
		var monday = dt.snap(Week(Down, Monday));
		return monday;
	}

	public inline static function getDayKey(day: DateTime): Int {
		return Std.int(day.getTime() / 1000);
	}

	public function checkin(?dt: DateTime, ?description: String): Bool {
		var activeEntry = getActiveEntry();
		if (activeEntry != null) return false;
		var entry = new Entry();
		dt = dt == null ? DateTime.local() : dt;
		entry.timeStart = dt;
		if (description != null && description != "") entry.description = description;
		addEntry(entry);
		return true;
	}

	public function checkout(description: String, ?dt: DateTime): Bool {
		var activeEntry = getActiveEntry();
		if (activeEntry == null) return false;
		dt = dt == null ? DateTime.local() : dt;
		activeEntry.timeEnd = dt;
		if (description.trim() != '') activeEntry.description = description;
		this.isDirty = true;
		return true;
	}

	public function uncheckout(): Bool {
		var lastEntry = getLastEntry();
		if (lastEntry.timeEnd == null) return false;
		lastEntry.timeEnd = null;
		this.isDirty = true;
		return true;
	}

	public function getActiveEntry(): Entry {
		var entry = getLastEntry();
		if (entry == null || entry.timeEnd != null) return null;
		return entry;
	}

	public function getLastEntry(): Entry {
		if (allEntries.length == 0) return null;
		return this.allEntries[this.allEntries.length - 1];
	}

	public function updateLastDescription(description: String): Bool {
		var e = getLastEntry();
		if (e == null) return false;
		e.description = description;
		this.isDirty = true;
		return true;
	}

	public function save(): Bool {
		var savedEntries: Array<EntryStruct> = [];
		for (e in this.allEntries) {
			var s = e.toStruct();
			if (s == null) continue;
			savedEntries.push(s);
		}
		var data = {entries: savedEntries};
		sys.io.File.saveContent(this.path, haxe.format.JsonPrinter.print(data, "  "));
		this.isDirty = false;
		return true;
	}

	/**
		Get the day entries for this datetime

		Note: do not use entry.day as the param, as entry.day is already been floored
	**/
	public function getDayEntries(?day: DateTime): EntriesByDay {
		if (day == null) day = DateTime.local();
		day = getStoredDate(day);
		return this.entriesByDay[getDayKey(day)];
	}

	/**
		Get the week entries for this datetime

		Note: do not use entry.day as the param, as entry.day had already been floored
	**/
	public function getWeekEntries(?d: DateTime = null): EntriesByWeek {
		var weekStart = getWeekStart(d);
		var weekStartKey = getDayKey(weekStart);
		var week = entriesByWeek[weekStartKey];
		if (week == null) {
			week = new EntriesByWeek(this, weekStart);
		}
		return week;
	}

	public function undoCheckin(): Bool {
		var entry = getActiveEntry();
		if (entry == null) return false;
		this.allEntries.pop();
		this.entriesByDayArray[this.entriesByDayArray.length - 1].removeEntry(entry);
		this.isDirty = true;
		return true;
	}

	public function checkoutin(?description: String): Bool {
		var dt = DateTime.local();
		if (!Run.db.checkout(description, dt)) return false;
		Run.db.checkin(dt);
		return true;
	}

	public function checkinout(?description: String): Bool {
		var dt = DateTime.local();
		if (!checkin(dt)) return false;
		if (!checkout(description, dt)) return false;
		return true;
	}
}
