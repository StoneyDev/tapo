class TapoDevice {
  final String ip;
  final String nickname;
  final String model;
  final bool deviceOn;
  final bool isOnline;

  const TapoDevice({
    required this.ip,
    required this.nickname,
    required this.model,
    required this.deviceOn,
    required this.isOnline,
  });

  TapoDevice copyWith({
    String? ip,
    String? nickname,
    String? model,
    bool? deviceOn,
    bool? isOnline,
  }) {
    return TapoDevice(
      ip: ip ?? this.ip,
      nickname: nickname ?? this.nickname,
      model: model ?? this.model,
      deviceOn: deviceOn ?? this.deviceOn,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
