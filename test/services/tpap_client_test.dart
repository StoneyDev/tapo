import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tapo/core/tpap_session.dart';
import 'package:tapo/services/tpap_client.dart';

@GenerateMocks([TpapSession])
import 'tpap_client_test.mocks.dart';

void main() {
  late MockTpapSession mockSession;
  late TpapClient client;

  setUp(() {
    mockSession = MockTpapSession();
    client = TpapClient(session: mockSession);
  });

  group('TpapClient', () {
    group('getDeviceInfo', () {
      test('sends correct request and returns result', () async {
        when(mockSession.request({'method': 'get_device_info'})).thenAnswer(
          (_) async => {
            'error_code': 0,
            'result': {
              'device_id': 'abc123',
              'model': 'P110',
              'device_on': true,
            },
          },
        );

        final result = await client.getDeviceInfo();

        expect(result, isNotNull);
        expect(result!['device_id'], 'abc123');
        expect(result['model'], 'P110');
        expect(result['device_on'], true);
        verify(mockSession.request({'method': 'get_device_info'})).called(1);
      });

      test('returns null when session returns null', () async {
        when(mockSession.request(any)).thenAnswer((_) async => null);

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });

      test('returns null when result key is missing', () async {
        when(mockSession.request(any)).thenAnswer(
          (_) async => {'error_code': 0},
        );

        final result = await client.getDeviceInfo();

        expect(result, isNull);
      });
    });

    group('setDeviceOn', () {
      test('sends correct request to turn on', () async {
        when(mockSession.request({
          'method': 'set_device_info',
          'params': {'device_on': true},
        })).thenAnswer((_) async => {'error_code': 0});

        final result = await client.setDeviceOn(on: true);

        expect(result, isTrue);
        verify(mockSession.request({
          'method': 'set_device_info',
          'params': {'device_on': true},
        })).called(1);
      });

      test('sends correct request to turn off', () async {
        when(mockSession.request({
          'method': 'set_device_info',
          'params': {'device_on': false},
        })).thenAnswer((_) async => {'error_code': 0});

        final result = await client.setDeviceOn(on: false);

        expect(result, isTrue);
      });

      test('returns false when session returns null', () async {
        when(mockSession.request(any)).thenAnswer((_) async => null);

        final result = await client.setDeviceOn(on: true);

        expect(result, isFalse);
      });
    });

    group('getEnergyUsage', () {
      test('sends correct request and returns result', () async {
        when(mockSession.request({'method': 'get_energy_usage'})).thenAnswer(
          (_) async => {
            'error_code': 0,
            'result': {
              'today_energy': 150,
              'month_energy': 4500,
              'current_power': 45,
            },
          },
        );

        final result = await client.getEnergyUsage();

        expect(result, isNotNull);
        expect(result!['today_energy'], 150);
        expect(result['month_energy'], 4500);
        expect(result['current_power'], 45);
        verify(mockSession.request({'method': 'get_energy_usage'})).called(1);
      });

      test('returns null when session returns null', () async {
        when(mockSession.request(any)).thenAnswer((_) async => null);

        final result = await client.getEnergyUsage();

        expect(result, isNull);
      });

      test('returns null when result key is missing', () async {
        when(mockSession.request(any)).thenAnswer(
          (_) async => {'error_code': 0},
        );

        final result = await client.getEnergyUsage();

        expect(result, isNull);
      });
    });
  });
}
