class EntriesByWeek {
	// 0 will be monday
	public var entriesByDayMap: Map<Int, EntriesByDay>;
	public var entriesByDayArray: Array<EntriesByDay>;
	public var weekStart: DateTime;
	public var db: Database;

	public function new(db: Database, weekStart: DateTime) {
		this.db = db;
		this.weekStart = weekStart; // this will always be monday
		this.entriesByDayMap = new Map<Int, EntriesByDay>();
		this.entriesByDayArray = [];
		var curr = new DateTime(this.weekStart);
		for (i in 0...7) {
			var day = new EntriesByDay(curr);
			day.db = this.db;
			this.entriesByDayMap[Database.getDayKey(curr)] = day;
			this.entriesByDayArray.push(day);
			curr = curr + Day(1);
		}
	}

	public function getDay(day: DateTime): EntriesByDay {
		return this.entriesByDayMap[Database.getDayKey(day)];
	}

	public function totalDuration(): Int {
		var duration = 0;
		for (day in this.entriesByDayArray) {
			duration += day.totalDuration();
		}
		return duration;
	}

	public var count(get, never): Int;

	public function get_count(): Int {
		var c = 0;
		for (e in this.entriesByDayArray) {
			c += e.entries.length;
		}
		return c;
	}
}
