class SessionUser {
  SessionUser({
    required this.memberId,
    required this.fullName,
    required this.email,
    required this.walletBalance,
    this.phoneNumber,
    this.avatarUrl,
    this.tier,
    this.rank,
  });

  final int? memberId;
  final String fullName;
  final String email;
  final double walletBalance;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? tier;
  final String? rank;

  bool get isAdmin => email.toLowerCase() == 'luc@gmail.com';

  SessionUser copyWith({
    int? memberId,
    String? fullName,
    String? email,
    double? walletBalance,
    String? phoneNumber,
    String? avatarUrl,
    String? tier,
    String? rank,
  }) {
    return SessionUser(
      memberId: memberId ?? this.memberId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      walletBalance: walletBalance ?? this.walletBalance,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      tier: tier ?? this.tier,
      rank: rank ?? this.rank,
    );
  }

  static SessionUser fromMeJson(Map<String, dynamic> json) {
    return SessionUser(
      memberId: json['id'] as int?,
      fullName: (json['fullName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      walletBalance: (json['walletBalance'] ?? 0).toDouble(),
      phoneNumber: json['phoneNumber']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      tier: json['tier']?.toString(),
      rank: json['rank']?.toString(),
    );
  }
}


