class ConspiracyTexts {
  static const List<String> theories = [
    "The bass frequencies contain hidden messages",
    "All breakcore artists are replaced with clones",
    "The 303 was designed by DARPA for mind control",
    "Amen breaks can alter brain wave patterns",
    "Major festivals are psyops to test crowd control",
    "DJs are actually scanning our thoughts through speakers",
    "The drop is when they activate the programmers",
    "Ravers who disappear are recruited by alien",
    "Glow sticks emit tracking nanobots",
    "The government invented techno to distract millennials",
  ];

  static const List<String> alternativeTheories = [
    "The Amen Break is a frequency weapon",
    "All DJs are actually government agents",
    "Festival lineups are coded messages",
    "The 808 kick drum contains subliminal commands",
    "Rave culture is a CIA social experiment",
    "Glow sticks contain mind control chemicals",
    "The drop is when they activate the programming",
    "All techno is actually alien communication",
    "Security are undercover operatives",
    "The bass drop triggers mass hypnosis",
  ];

  static const String headerText = "> ACCESSING SECURE CHANNEL...\n> DECRYPTING INTERCEPTED COMMUNICATIONS...\n\n";

  static const String footerText = "\n> CLASSIFICATION LEVEL: ████████\n> SOURCE: UNKNOWN\n> SIGNAL STRENGTH: ███████████ 98%";

  static const List<String> warningTexts = [
    "  UNAUTHORIZED ACCESS DETECTED  ",
    "  INITIATING OVERRIDE PROTOCOL  ",
    "  COUNTER MEASURES: ACTIVE      ",
  ];

  static const String allYourBangFaceText = """
╔══════════════════════════════════╗
║                                  ║
║   ALL YOUR BANGFACE              ║
║   ARE BELONG TO US               ║
║                                  ║
║   RAVE OR DIE                    ║
║                                  ║
╚══════════════════════════════════╝""";

  static String getRandomTheory() {
    final random = DateTime.now().millisecondsSinceEpoch % theories.length;
    return theories[random];
  }

  static String getRandomAlternativeTheory() {
    final random = DateTime.now().millisecondsSinceEpoch % alternativeTheories.length;
    return alternativeTheories[random];
  }
}
