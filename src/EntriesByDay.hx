class EntriesByDay {
	public var day: DateTime;
	public var entries: Array<Entry>;

	public function new(day: DateTime) {
		this.day = day;
		this.entries = [];
	}

	public function addEntry(e: Entry) {
		this.entries.push(e);
		this.entries.sort(function(e1, e2) {
			return Std.int((e2.timeStart - e1.timeStart).getTotalSeconds());
		});
	}

	public function removeEntry(e: Entry) {
		this.entries.remove(e);
	}

	public function totalDuration() {
		var duration = 0;
		for (e in this.entries) {
			duration += e.getDuration();
		}
		return duration;
	}

	public function getLastEntry(): Entry {
		if (this.entries.length == 0) return null;
		return this.entries[this.entries.length - 1];
	}

	// return a value between 0 and 100
	public function getHeatmap(interval = 60, currentTimeNum: Null<Int> = null): Array<Int> {
		var dayStart = Config.dayStart;
		var heat = [];
		var curr = day + Hour(dayStart);
		var end = curr + Day(1);
		var currentInd = 0;
		var now = DateTime.local();
		while (curr != end) {
			var intervalStart = curr;
			var intervalEnd = intervalStart + Minute(interval);
			var intervalDuration = (intervalStart - intervalEnd).getTotalSeconds();
			var h = 0;

			if (currentInd < this.entries.length) {
				// if window is after the current entry
				// we shift up the index
				// we are unlikely to have to shift up more than once
				var entry = this.entries[currentInd];
				var timeEnd = entry.timeEnd == null ? now : entry.timeEnd;
				if (intervalStart > timeEnd) currentInd += 1;
			}

			if (currentInd < this.entries.length) {
				var duration: Float = 0;
				// this loop handles 2 entries in a single interval.
				// mostly to handle split command
				// in rare cases, might handle more than 2 entries in the same interval
				while (currentInd < this.entries.length) {
					var entry = this.entries[currentInd];
					// the window haven't move to the next entry, we do nothing
					if (intervalEnd < entry.timeStart) break;
					var min = intervalStart > entry.timeStart ? intervalStart : entry.timeStart;
					var timeEnd = entry.timeEnd == null ? now : entry.timeEnd;
					var max = intervalEnd < timeEnd ? intervalEnd : timeEnd;
					duration += (max - min).getTotalSeconds();
					if (max == intervalEnd) break;
					currentInd += 1;
				}
				h = Std.int(duration / intervalDuration * 100);
			}
			if (currentTimeNum != null && intervalStart <= now && now <= intervalEnd) {
				h = currentTimeNum;
			}

			if (h > 100) h = 100;
			heat.push(h);
			curr = intervalEnd;
		}
		return heat;
	}
}
