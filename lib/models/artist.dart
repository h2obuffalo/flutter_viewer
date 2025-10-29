class SetTime {
  final String start;
  final String end;
  final String stage;
  final String status;

  SetTime({
    required this.start,
    required this.end,
    required this.stage,
    required this.status,
  });

  factory SetTime.fromJson(Map<String, dynamic> json) {
    return SetTime(
      start: json['start'] as String,
      end: json['end'] as String,
      stage: json['stage'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'stage': stage,
      'status': status,
    };
  }

  DateTime get startDateTime => DateTime.parse(start);
  DateTime get endDateTime => DateTime.parse(end);

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return now.isBefore(startDateTime);
  }

  bool get isCompleted {
    final now = DateTime.now();
    return now.isAfter(endDateTime);
  }
}

class Artist {
  final int id;
  final String name;
  final String photo;
  final String? website;
  final String? bandcamp;
  final String? blurb;
  final List<String> stages;
  final List<SetTime> setTimes;
  bool isFavorited = false;

  Artist({
    required this.id,
    required this.name,
    required this.photo,
    this.website,
    this.bandcamp,
    this.blurb,
    required this.stages,
    required this.setTimes,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int,
      name: json['name'] as String,
      photo: json['photo'] as String,
      website: json['website'] as String?,
      bandcamp: json['bandcamp'] as String?,
      blurb: json['blurb'] as String?,
      stages: (json['stages'] as List<dynamic>).cast<String>(),
      setTimes: (json['setTimes'] as List<dynamic>)
          .map((e) => SetTime.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
      'website': website,
      'bandcamp': bandcamp,
      'blurb': blurb,
      'stages': stages,
      'setTimes': setTimes.map((e) => e.toJson()).toList(),
    };
  }

  // Helper methods for time-based filtering
  bool get isCurrentlyPlaying {
    return setTimes.any((setTime) => setTime.isLive);
  }

  bool get hasUpcomingSets {
    return setTimes.any((setTime) => setTime.isUpcoming);
  }

  List<SetTime> get currentSets {
    return setTimes.where((setTime) => setTime.isLive).toList();
  }

  List<SetTime> get upcomingSets {
    return setTimes.where((setTime) => setTime.isUpcoming).toList();
  }

  List<SetTime> get completedSets {
    return setTimes.where((setTime) => setTime.isCompleted).toList();
  }

  SetTime? get nextSet {
    final upcoming = upcomingSets;
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return upcoming.first;
  }

  SetTime? get currentSet {
    final current = currentSets;
    if (current.isEmpty) return null;
    return current.first;
  }

  // Helper method to check if artist has any links
  bool get hasLinks {
    return website != null || bandcamp != null;
  }

  // Helper method to get primary stage (most common stage)
  String get primaryStage {
    if (stages.isEmpty) return 'Unknown';
    if (stages.length == 1) return stages.first;
    
    // Count stage occurrences in setTimes
    final stageCounts = <String, int>{};
    for (final setTime in setTimes) {
      stageCounts[setTime.stage] = (stageCounts[setTime.stage] ?? 0) + 1;
    }
    
    if (stageCounts.isEmpty) return stages.first;
    
    return stageCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}
