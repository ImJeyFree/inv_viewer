import 'package:flutter_test/flutter_test.dart';
import 'package:inv_viewer/pages/device_inv.dart';
import 'package:inv_viewer/pages/pole.dart';
import 'dart:io';
import 'dart:convert';

// 실행: flutter test test/device_inv_json_test.dart

// 16진수 주소 문자열을 정수로 변환하는 헬퍼 함수 (테스트용)
int _parseHexAddress(String hexString) {
  try {
    if (hexString.startsWith('0x') || hexString.startsWith('0X')) {
      return int.parse(hexString.substring(2), radix: 16);
    }
    return int.parse(hexString, radix: 16);
  } catch (e) {
    return 0;
  }
}

void main() {
  // Flutter 바인딩 초기화
  TestWidgetsFlutterBinding.ensureInitialized();

  String fileName = 'assets/S300_1_00.json';
  SpecFromJson specFromJson = SpecFromJson();

  group('$fileName Parse :', () {
    late Storage storage;

    setUp(() async {
      // JSON 파일 로드
      await specFromJson.loadAssets(fileName);
    });

    tearDown(() async {});

    test('DeviceSpec parse() 호출 정상 동작', () async {
      final spec = DeviceSpec(null);
      try {
        specFromJson.deviceSpec(spec);
        expect(true, isTrue);
      } catch (e) {
        fail('DeviceSpec parse()에서 예외 발생: $e');
      }
    });

    test('IoSpec parse() 호출 정상 동작', () async {
      final spec = IoSpec(null);
      try {
        specFromJson.ioSpec(spec, null);
        expect(true, isTrue);
      } catch (e) {
        fail('IoSpec parse()에서 예외 발생: $e');
      }
    });

    test('TripSpec parse() 호출 정상 동작', () async {
      final spec = TripSpec(null);
      try {
        specFromJson.tripSpec(spec, null);
        expect(true, isTrue);
      } catch (e) {
        fail('TripSpec parse()에서 예외 발생: $e');
      }
    });

    test('MsgSpec parse() 호출 정상 동작', () async {
      final spec = MsgSpec(null);
      try {
        specFromJson.messageSpec(spec);
        expect(true, isTrue);
      } catch (e) {
        fail('MsgSpec parse()에서 예외 발생: $e');
      }
    });

    test('CommonSpec parse() 호출 정상 동작', () async {
      final spec = CommonSpec(null);
      try {
        specFromJson.commonSpec(spec);
        expect(true, isTrue);
      } catch (e) {
        fail('CommonSpec parse()에서 예외 발생: $e');
      }
    });

    test('ParameterSpec parse() 호출 정상 동작', () async {
      final spec = ParameterSpec(null);
      try {
        specFromJson.parameterSpec(spec);
        expect(true, isTrue);
      } catch (e) {
        fail('ParameterSpec parse()에서 예외 발생: $e');
      }
    });
  });
}
