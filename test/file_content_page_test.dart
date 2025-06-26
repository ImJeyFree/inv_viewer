import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_viewer/pages/file_content_page.dart';
import 'package:inv_viewer/pages/pole.dart';

final filename = 'G100_1_30.INV';

// MockStorage 클래스 추가
class MockStorage extends Storage {
  MockStorage() : super(fileName: filename);

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
  group('FileContentPage Widget :', () {
    testWidgets('로딩 인디케이터가 정상 표시', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FileContentPage(fileName: filename), //'test.inv'),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('리스트로 보기 - 각 Spec 텍스트 정상 표시', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FileContentPage(
            fileName: filename, storage: MockStorage()), // MockStorage 주입
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
        // 화면에 표시된 모든 텍스트 출력
        final allTexts = find.byType(Text);
        for (final widget in tester.widgetList(allTexts)) {
          final textWidget = widget as Text;
          // ignore: avoid_print
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

      print(' 리스트로 보기');
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
        home: FileContentPage(
            fileName: filename, storage: MockStorage()), // MockStorage 주입
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

      print(' 표로 보기');
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
}
