import 'package:freezed_annotation/freezed_annotation.dart';

part 'tapo_device.freezed.dart';

@freezed
abstract class TapoDevice with _$TapoDevice {
  const factory TapoDevice({
    required String ip,
    required String nickname,
    required String model,
    required bool deviceOn,
    required bool isOnline,
  }) = _TapoDevice;
}
