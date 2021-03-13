import datetime.DateTime;
import datetime.DateTimeInterval;

/**
	Track a single time entry
**/
class Entry {
	public var index: Int;
	public var timeStart: Null<DateTime>;
	public var timeEnd: Null<DateTime>;
	@:isVar
	public var description(get, set): String = "";
	public var db: Database;
	public var day(get, never): DateTime;
	public var tags: Array<String>;

	public function get_description(): String {
		if (Run.redact) return '--REDACTED--';
		return this.description;
	}

	public function set_description(s: String): String {
		this.description = s;
		var i = s.indexOf('#');
		while (i != -1) {
			var end = s.indexOf(' ', i);
			if (end == -1) end = s.length;
			var tag = s.substring(i, end);
			s = s.substring(end);
			this.tags.push(tag);
			i = s.indexOf('#');
		}
		return this.description;
	}

	public function get_day(): Null<DateTime> {
		if (this.db == null || this.timeStart == null) return null;
		return Database.getStoredDate(timeStart);
	}

	public function new() {
		this.tags = [];
	}

	public function getInterval(): DateTimeInterval {
		if (timeStart == null) return null;
		if (timeEnd == null) {
			return DateTime.local() - timeStart;
		}
		return timeEnd - timeStart;
	}

	public function getDuration(): Int { // in seconds
		var interval = getInterval();
		if (interval == null) return 0;
		return Std.int(interval.getTotalSeconds());
	}

	public function toStruct(): EntryStruct {
		if (this.timeStart == null) return null;
		var s: EntryStruct = {timeStart: this.timeStart.toString()};
		s.description = this.description;
		if (this.timeEnd != null) s.timeEnd = this.timeEnd.toString();
		return s;
	}

	public function toString(): String {
		return '${timeStart} - ${timeEnd} : ${description}';
	}
}
