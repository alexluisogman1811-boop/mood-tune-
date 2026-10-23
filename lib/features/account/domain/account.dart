/// What a user has paid for. Prices are shown in US dollars.
enum Plan {
  free('Free', price: null, duration: null, usd: 0, thb: 0),
  monthly(
    'Monthly',
    price: '\$2.99',
    duration: Duration(days: 30),
    usd: 2.99,
    thb: 109,
  ),
  yearly(
    'Yearly',
    price: '\$24.99',
    duration: Duration(days: 365),
    usd: 24.99,
    thb: 899,
  ),
  lifetime('Lifetime', price: '\$39.99', duration: null, usd: 39.99, thb: 1449);

  const Plan(
    this.label, {
    required this.price,
    required this.duration,
    required this.usd,
    required this.thb,
  });

  final String label;

  /// Null for Free.
  final String? price;

  /// How long one purchase lasts; null for Free and Lifetime.
  final Duration? duration;

  /// Price for income reports: dollars, and the approximate baht price
  /// shown on the sales page.
  final double usd;
  final int thb;

  bool get isPaid => this != free;
}

/// Limits for people on the Free plan.
abstract final class FreeLimits {
  /// Playlists a Free user can make per day.
  static const playlistsPerDay = 3;

  /// Longest playlist on Free.
  static const playlistLength = 10;
}

/// A signed-in user's record in the database.
class Account {
  const Account({
    required this.uid,
    required this.email,
    this.plan = Plan.free,
    this.premiumUntil,
    this.usageDate,
    this.usageCount = 0,
    this.createdAt,
    this.lastOpened,
  });

  final String uid;
  final String email;
  final Plan plan;

  /// When a Monthly or Yearly plan ends. Null for Free and Lifetime.
  final DateTime? premiumUntil;

  /// Day ([dayKey]) that [usageCount] belongs to.
  final String? usageDate;
  final int usageCount;
  final DateTime? createdAt;

  /// Last day ([dayKey]) the app was opened, for the admin's active-user
  /// counts. Only the date is stored.
  final String? lastOpened;

  /// Lifetime never ends; Monthly and Yearly last until [premiumUntil].
  bool isPremium(DateTime now) => switch (plan) {
    Plan.free => false,
    Plan.lifetime => true,
    _ => premiumUntil != null && now.isBefore(premiumUntil!),
  };

  /// Playlists made today (a new day starts at zero).
  int usedToday(DateTime now) => usageDate == dayKey(now) ? usageCount : 0;

  /// Playlists left today; null means unlimited.
  int? playlistsLeft(DateTime now) => isPremium(now)
      ? null
      : (FreeLimits.playlistsPerDay - usedToday(now)).clamp(
          0,
          FreeLimits.playlistsPerDay,
        );

  /// Local calendar day, e.g. 2026-10-22.
  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// The new [premiumUntil] when [plan] is bought at [now]. Time left on a
  /// current plan is kept, so renewing early loses nothing.
  DateTime? untilAfterBuying(Plan plan, DateTime now) {
    final d = plan.duration;
    if (d == null) return null;
    final from = premiumUntil != null && premiumUntil!.isAfter(now)
        ? premiumUntil!
        : now;
    return from.add(d);
  }
}

/// What the app lets the current user do.
class Entitlements {
  const Entitlements({
    required this.premium,
    required this.playlistsLeft,
    required this.accountsEnabled,
  });

  /// Everything unlocked: accounts are switched off in this build.
  const Entitlements.unlimited()
    : premium = true,
      playlistsLeft = null,
      accountsEnabled = false;

  final bool premium;

  /// Null means unlimited.
  final int? playlistsLeft;
  final bool accountsEnabled;

  bool get canUsePhoto => premium;
  bool get canMakePlaylist => playlistsLeft == null || playlistsLeft! > 0;
  int maxPlaylistLength(int wanted) => premium
      ? wanted
      : (wanted < FreeLimits.playlistLength
            ? wanted
            : FreeLimits.playlistLength);
}
