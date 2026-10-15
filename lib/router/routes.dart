/// Strongly-typed route paths for Unwind navigation.
abstract final class Routes {
  static const String splash = '/';
  static const String home = '/home';
  static const String levels = '/levels';
  static const String settings = '/settings';
  static const String theme = '/settings/theme';
  static const String howToPlay = '/howto';
  static const String achievements = '/achievements';
  static const String stats = '/stats';
  static const String streak = '/streak';
  static const String devLab = '/dev/lab';

  /// Generates the route path for playing level [id].
  static String play(int id) => '/play/$id';
}
