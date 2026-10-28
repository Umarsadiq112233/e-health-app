class SetupProgress {
  final bool profileComplete, consentComplete, deviceComplete;
  final int pairingStep;
  final String name, weight;
  final Map<String, bool> permissions;
  final Map<String, dynamic> wellness;
  final String? avatarPath, avatarUrl, avatarDisplayUrl;
  const SetupProgress({
    this.profileComplete = false,
    this.consentComplete = false,
    this.deviceComplete = false,
    this.pairingStep = 0,
    this.name = '',
    this.weight = '70',
    this.permissions = const {},
    this.wellness = const {},
    this.avatarPath,
    this.avatarUrl,
    this.avatarDisplayUrl,
  });
  factory SetupProgress.fromJson(Map<String, dynamic> value) => SetupProgress(
    profileComplete: value['profile'] == true,
    consentComplete: value['consent'] == true,
    deviceComplete: value['device'] == true,
    pairingStep:
        (value['pairingStep'] is num
                ? (value['pairingStep'] as num).toInt()
                : 0)
            .clamp(0, 9),
    avatarPath: value['avatarPath'] as String?,
    avatarUrl: value['avatarUrl'] as String?,
    avatarDisplayUrl: value['avatarDisplayUrl'] as String?,
    name: value['name'] is String ? value['name'] as String : '',
    weight: value['weight'] is String ? value['weight'] as String : '70',
    wellness: value['wellness'] is Map
        ? Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(value['wellness'] as Map),
          )
        : const {},
    permissions: value['permissions'] is Map
        ? Map.unmodifiable(
            (value['permissions'] as Map).map(
              (key, value) => MapEntry(key.toString(), value == true),
            ),
          )
        : const {},
  );
  Map<String, dynamic> toJson() => {
    'profile': profileComplete,
    'consent': consentComplete,
    'device': deviceComplete,
    'pairingStep': pairingStep,
    'name': name,
    'weight': weight,
    'permissions': permissions,
    'wellness': wellness,
    if (avatarPath != null) 'avatarPath': avatarPath,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };
}
