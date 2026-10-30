import 'dart:async';

import 'package:jolt/models/tapo_device.dart';
import 'package:jolt/providers/home_provider.dart';

/// Home state set by the test, recording the actions the UI triggers.
///
/// The widget tests cover how the UI reacts to the state; the notifier logic
/// is tested in home_provider_test.dart.
class FakeHomeNotifier extends HomeNotifier {
  FakeHomeNotifier([this._initial = const HomeState()]);

  FakeHomeNotifier.withDevices(List<TapoDevice> devices)
    : this(HomeState(devices: devices));

  final HomeState _initial;

  @override
  HomeState build() => _initial;

  int refreshCallCount = 0;
  bool? lastRefreshSilent;

  /// When set, [refresh] stays pending until this completer completes.
  Completer<void>? refreshCompleter;
  int refreshIfStaleCallCount = 0;
  int turnOffAllCallCount = 0;
  String? lastToggledIp;
  String? lastRemovedIp;
  String? lastScheduledIp;
  ({String oldIp, String newIp})? lastIpUpdate;

  @override
  Future<void> refresh({bool silent = false}) async {
    refreshCallCount++;
    lastRefreshSilent = silent;
    await refreshCompleter?.future;
  }

  @override
  Future<void> refreshIfStale(Duration maxAge) async =>
      refreshIfStaleCallCount++;

  @override
  Future<void> turnOffAll() async => turnOffAllCallCount++;

  @override
  Future<bool> toggleDevice(String ip) async {
    lastToggledIp = ip;
    return true;
  }

  @override
  Future<void> removeDevice(String ip) async => lastRemovedIp = ip;

  @override
  Future<void> updateDeviceIp(String oldIp, String newIp) async =>
      lastIpUpdate = (oldIp: oldIp, newIp: newIp);

  @override
  void schedulePowerOff(String ip) => lastScheduledIp = ip;
}
