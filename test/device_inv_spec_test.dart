import 'package:flutter_test/flutter_test.dart';
import 'package:inv_viewer/pages/device_inv.dart';
import 'package:inv_viewer/pages/poleEx.dart';
import 'dart:io';

// 실행: flutter test test/device_inv_spec_test.dart

void main([List<String>? args]) {
  // 커맨드라인 인자에서 파일명 추출, 없으면 기본값 사용
  final fileName = (args != null && args.isNotEmpty)
      ? args.first
      : (Platform.environment['INV_FILE'] ??
          //'G100_1_30.INV'
          //'C:\\workspace\\flutter\\inv_viewer\\test\\G100_1_30.INV'
          'assets/DataFile/LSIS/G100/G100_1_30.INV');

  group('$fileName Parse :', () {
    late Storage storage;

    setUp(() async {
      //fileName = 'assets/DataFile/LSIS/G100/G100_1_30.INV';
      storage = Storage(fileName: fileName);
      //storage = Storage(fileName: fileName, isAssets: true);
      await storage.open();
    });

    tearDown(() async {
      await storage.close();
    });

    test('DeviceSpec parse() 호출 정상 동작', () async {
      final spec = DeviceSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('DeviceSpec parse()에서 예외 발생: $e');
      }
    });

    test('IoSpec parse() 호출 정상 동작', () async {
      final spec = IoSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('IoSpec parse()에서 예외 발생: $e');
      }
    });

    test('TripSpec parse() 호출 정상 동작', () async {
      final spec = TripSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('TripSpec parse()에서 예외 발생: $e');
      }
    });

    test('MsgSpec parse() 호출 정상 동작', () async {
      final spec = MsgSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('MsgSpec parse()에서 예외 발생: $e');
      }
    });

    test('CommonSpec parse() 호출 정상 동작', () async {
      final spec = CommonSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('CommonSpec parse()에서 예외 발생: $e');
      }
    });

    test('ParameterSpec parse() 호출 정상 동작', () async {
      final spec = ParameterSpec(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('ParameterSpec parse()에서 예외 발생: $e');
      }
    });

    test('InitOrder parse() 호출 정상 동작', () async {
      final spec = InitOrder(storage);
      try {
        await spec.parse();
        expect(true, isTrue);
      } catch (e) {
        fail('InitOrder parse()에서 예외 발생: $e');
      }
    });
  });
}
