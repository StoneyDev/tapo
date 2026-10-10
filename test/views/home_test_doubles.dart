import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tapo/models/tapo_device.dart';
import 'package:tapo/services/secure_storage_service.dart';
import 'package:tapo/services/tapo_service.dart';
import 'package:tapo/services/widget_data_service.dart';
import 'package:tapo/viewmodels/home_viewmodel.dart';

/// Mock HomeViewModel for widget testing
/// Note: This tests UI behavior in response to
/// ViewModel state changes. The actual ViewModel logic
/// is tested in home_viewmodel_test.dart.
class MockHomeViewModel extends ChangeNotifier implements HomeViewModel {
  List<TapoDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _togglingDevices = {};

  @override
  List<TapoDevice> get devices => List.unmodifiable(_devices);
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool isToggling(String ip) => _togglingDevices.contains(ip);
  @override
  Duration? powerOffRemaining(String ip) => null;
  @override
  void schedulePowerOff(String ip) => schedulePowerOffCallCount++;
  @override
  void cancelPowerOff(String ip, {bool notify = true}) {}
  @override
  void cancelAllPowerOffs() {}

  // State setters
  void setDevices(List<TapoDevice> devices) {
    _devices = devices;
    notifyListeners();
  }

  void setIsLoading({required bool loading}) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setToggling(String ip, {required bool toggling}) {
    toggling ? _togglingDevices.add(ip) : _togglingDevices.remove(ip);
    notifyListeners();
  }

  // Call tracking
  int loadDevicesCallCount = 0;
  int refreshCallCount = 0;
  bool? lastRefreshSilent;

  /// When set, [refresh] stays pending until this completer completes.
  Completer<void>? refreshCompleter;
  int schedulePowerOffCallCount = 0;
  int refreshIfStaleCallCount = 0;
  int turnOffAllCallCount = 0;
  int toggleDeviceCallCount = 0;
  String? lastToggledIp;
  int removeDeviceCallCount = 0;
  String? lastRemovedIp;
  int updateDeviceIpCallCount = 0;
  String? lastOldIp;
  String? lastNewIp;

  @override
  Future<void> loadDevices({bool silent = false}) async =>
      loadDevicesCallCount++;
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
    toggleDeviceCallCount++;
    lastToggledIp = ip;
    return true;
  }

  @override
  Future<void> removeDevice(String ip) async {
    removeDeviceCallCount++;
    lastRemovedIp = ip;
  }

  @override
  Future<void> updateDeviceIp(String oldIp, String newIp) async {
    updateDeviceIpCallCount++;
    lastOldIp = oldIp;
    lastNewIp = newIp;
  }
}

/// Mock SecureStorageService for logout testing
class MockSecureStorageService implements SecureStorageService {
  int clearCredentialsCallCount = 0;
  int clearDeviceIpsCallCount = 0;

  @override
  Future<void> clearCredentials() async => clearCredentialsCallCount++;
  @override
  Future<void> clearDeviceIps() async => clearDeviceIpsCallCount++;
  @override
  Future<({String? email, String? password})> getCredentials() async =>
      (email: null, password: null);
  @override
  Future<List<String>> getDeviceIps() async => [];
  @override
  Future<bool> hasCredentials() async => false;
  @override
  Future<void> saveCredentials(String email, String password) async {}
  @override
  Future<void> saveDeviceIps(List<String> ips) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock TapoService for logout testing
class MockTapoService implements TapoService {
  int disconnectAllCallCount = 0;

  @override
  Future<void> disconnectAll() async => disconnectAllCallCount++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock WidgetDataService for logout testing
class MockWidgetDataService implements WidgetDataService {
  int clearWidgetDataCallCount = 0;
  int refreshWidgetsCallCount = 0;

  @override
  Future<void> clearWidgetData() async => clearWidgetDataCallCount++;
  @override
  Future<void> refreshWidgets() async => refreshWidgetsCallCount++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
