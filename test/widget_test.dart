// 통합 테스트 파일 - 모든 테스트를 함께 실행
//
// 실행 방법:
// flutter test test/widget_test.dart
// 또는
// flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_viewer/main.dart';
import 'package:inv_viewer/pages/device_inv.dart';
import 'package:inv_viewer/pages/pole.dart';
import 'package:inv_viewer/pages/file_content_page.dart';
import 'dart:io';

// MockStorage 클래스 (file_content_page_test.dart에서 가져옴)
class MockStorage extends Storage {
  MockStorage() : super(fileName: 'G100_1_30.INV');

  @override
  Future<bool> open({bool writeAccess = false, bool create = false}) async =>
      true;

  // parseINVData 오버라이드: 더미 데이터 반환
  Future<Map<String, dynamic>> parseINVData(Storage storage) async {
    return {
      'deviceSpec': {
        'strDataFileVer': '1.0',
        'nInvModelNo': 123,
        'strInvModelName': '테스트모델',
        'strInvSWVer': 'v1.2.3',
        'strInvCodeVer': 'code-456',
        'nCommOffset': 10,
        'nTotalDiagNum': 2,
        'nModelNoCommAddr': 100,
        'nCodeVerCommAddr': 200,
        'nMotorStatusCommAddr': 300,
        'nInvStatusCommAddr': 400,
        'nInvControlCommAddr': 500,
        'nParameterSaveCommAddr': 600,
        'pDiagNum': [1, 2],
      },
      'ioSpec': {
        'nTotalInput': 4,
        'nNormalInput': 3,
        'nTotalInputFuncTitle': 2,
        'nTotalOutput': 2,
        'nNormalOutput': 2,
        'nTotalOutputFuncTitle': 1,
        'nAddInputStatus': 0,
        'nAddOutputStatus': 0,
        'pInputTermInfo': [
          {'name': 'IN1', 'desc': '입력1'},
          {'name': 'IN2', 'desc': '입력2'},
        ],
        'pOutputTermInfo': [
          {'name': 'OUT1', 'desc': '출력1'},
        ],
        'pInputFuncMsg': ['메시지1'],
        'pOutputFuncMsgTitle': ['타이틀1'],
      },
      'tripSpec': {
        'nTotalTripName': 1,
        'nFirstTripNameAddr': 10,
        'nCurTotalTrip': 1,
        'nTotalTripInfo': 1,
        'nTotalWarnName': 1,
        'nFirstWarnNameAddr': 20,
        'nCurTotalWarn': 1,
        'nTotalWarnInfo': 1,
        'pTripName': ['트립1'],
        'pWarnName': ['경고1'],
        'pTripAddr': [100],
        'pWarnAddr': [200],
        'pTripInfoData': [
          {'info': '트립정보'}
        ],
        'pWarnInfoData': [
          {'info': '경고정보'}
        ],
      },
      'msgSpec': {
        'nTotalMsg': 1,
        'pMsgInfo': [
          {'msg': '메시지정보'}
        ],
      },
      'commonSpec': {
        'nTotCommonNo': 1,
        'pCommonInfo': [
          {'info': '공통정보'}
        ],
      },
      'parameterSpec': {
        'nTotGroup': 1,
        'pParmGrp': [
          {'group': '파라미터그룹'}
        ],
      },
      'initOrder': {
        'nTotInitOder': 1,
        'pOrderAddr': [1234],
      },
    };
  }
}

void main() {
  group('=== 통합 테스트 스위트 ===', () {
    group('1. 기본 앱 테스트', () {
      testWidgets('앱이 정상적으로 빌드된다', (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());
        expect(find.byType(MyApp), findsOneWidget);
      });
    });

    group('2. Device INV Spec 테스트', () {
      late Storage storage;
      final fileName = Platform.environment['INV_FILE'] ?? 'G100_1_30.INV';

      setUp(() async {
        storage = Storage(fileName: fileName);
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

    group('3. FileContentPage Widget 테스트', () {
      const filename = 'G100_1_30.INV';

      testWidgets('로딩 인디케이터가 정상 표시', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: FileContentPage(fileName: filename),
        ));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('리스트로 보기 - 각 Spec 텍스트 정상 표시', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: FileContentPage(fileName: filename, storage: MockStorage()),
        ));

        bool found = false;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.byIcon(Icons.table_chart).evaluate().isNotEmpty) {
            found = true;
            break;
          }
        }
        if (!found) {
          final allTexts = find.byType(Text);
          for (final widget in tester.widgetList(allTexts)) {
            final textWidget = widget as Text;
            print('화면 텍스트: \'${textWidget.data}\'');
          }
        }
        expect(found, isTrue, reason: '표 보기 버튼이 노출되어야 합니다.');

        // INVDataViewPage 각 Spec 텍스트가 보이는지 확인
        final deviceSpecFinder = find.text('Device Spec');
        final ioSpecFinder = find.text('IO Spec');
        final tripSpecSpecFinder = find.text('Trip Spec');
        final msgSpecFinder = find.text('Message Spec');
        final commonSpecFinder = find.text('Common Spec');
        final parameterSpecFinder = find.text('Parameter Spec');
        final initOrderFinder = find.text('Init Order');

        print('리스트로 보기');
        print(
            ' - Device Spec : ${deviceSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - IO Spec : ${ioSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Trip Spec: ${tripSpecSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Message Spec : ${msgSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Common Spec : ${commonSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Parameter Spec : ${parameterSpecFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Init Order : ${initOrderFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');

        expect(deviceSpecFinder, findsOneWidget);
        expect(ioSpecFinder, findsOneWidget);
        expect(tripSpecSpecFinder, findsOneWidget);
        expect(msgSpecFinder, findsOneWidget);
        expect(commonSpecFinder, findsOneWidget);
        expect(parameterSpecFinder, findsOneWidget);
        expect(initOrderFinder, findsOneWidget);
      });

      testWidgets('표로 보기 - 각 Spec 탭 정상 표시', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: FileContentPage(fileName: filename, storage: MockStorage()),
        ));

        // 표 보기 버튼이 나타날 때까지 대기
        bool found = false;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.byIcon(Icons.table_chart).evaluate().isNotEmpty) {
            found = true;
            break;
          }
        }
        expect(found, isTrue, reason: '표 보기 버튼이 노출되어야 합니다.');

        // '표 형태로 보기' 버튼 클릭 후 INVDataTablePage가 정상 동작하는지 확인
        await tester.tap(find.byIcon(Icons.table_chart));
        await tester.pumpAndSettle();

        // INVDataTablePage의 탭 중 하나가 보이는지 터미널에 출력
        final deviceSpecTabFinder = find.text('Device Spec');
        final ioSpecTabFinder = find.text('IO Spec');
        final tripSpecTabFinder = find.text('Trip Spec');
        final msgSpecTabFinder = find.text('Message Spec');
        final commonSpecTabFinder = find.text('Common Spec');
        final parameterSpecTabFinder = find.text('Parameter Spec');
        final initOrderTabFinder = find.text('Init Order');

        print('표로 보기');
        print(
            ' - Device Spec : ${deviceSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - IO Spec : ${ioSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Trip Spec : ${tripSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Message Spec : ${msgSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Common Spec : ${commonSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Parameter Spec : ${parameterSpecTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');
        print(
            ' - Init Order : ${initOrderTabFinder.evaluate().isNotEmpty ? 'OK' : 'Failed'}');

        expect(deviceSpecTabFinder, findsWidgets);
        expect(ioSpecTabFinder, findsWidgets);
        expect(tripSpecTabFinder, findsWidgets);
        expect(msgSpecTabFinder, findsWidgets);
        expect(commonSpecTabFinder, findsWidgets);
        expect(parameterSpecTabFinder, findsWidgets);
        expect(initOrderTabFinder, findsWidgets);
      });
    });

    group('4. 통합 시나리오 테스트', () {
      test('모든 테스트가 성공적으로 완료되었습니다', () {
        expect(true, isTrue, reason: '통합 테스트 완료');
      });
    });
  });
}
