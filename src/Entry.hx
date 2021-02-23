import datetime.DateTime;
import datetime.DateTimeInterval;

/**
	Track a single time entry
**/
class Entry {
	public var timeStart: Null<DateTime>;
	public var timeEnd: Null<DateTime>;
	public var description: String = "";
	public var db: Database;
	public var day(get, never): DateTime;

	public function get_day(): Null<DateTime> {
		if (this.db == null || this.timeStart == null) return null;
		return Database.getStoredDate(timeStart);
	}

	public function new() {}

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
}
