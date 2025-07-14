// ignore_for_file: file_names, constant_identifier_names, camel_case_types, unused_element, library_private_types_in_public_api, non_constant_identifier_names
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/services.dart';

//import 'pole.dart';
import 'poleEx.dart';

import '../utils/string_utils.dart';

//=================================================================================================

//=================================================================================================
// 크기 상수 : Ref docs\src\DriveView 9\include\DataFileDefine.h
//-------------------------------------------------------------------------------------------------
const int DMDF_TITLE_SIZE = 30;
const int DMDF_UNIT_SIZE = 10;
const int DMDF_SMALL_SIZE = 10;

//=================================================================================================
int _readU32(Uint8List buffer, int offset) {
  return buffer[offset] |
      (buffer[offset + 1] << 8) |
      (buffer[offset + 2] << 16) |
      (buffer[offset + 3] << 24);
}

String _readString(Uint8List buffer, int offset, int length) {
  List<int> bytes = [];
  for (int i = 0; i < length; i++) {
    if (buffer[offset + i] == 0) break;
    bytes.add(buffer[offset + i]);
  }
  return String.fromCharCodes(bytes);
}

// 16진수 주소 문자열을 정수로 변환하는 헬퍼 함수
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

String makeTitleWithAtValue(String strTitle, String strAtValue) {
  return Utils.makeTitleWithAtValue(strTitle, strAtValue);
}

//=================================================================================================
// DeviceSpec 클래스: 장치 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class DeviceSpec {
  //===============================================================================================
  String strDataFileVer = ''; // Fixed-size array of 10 bytes
  int nInvModelNo = 0;
  String strInvModelName = ''; // Fixed-size array of 30 bytes
  String strInvSWVer = ''; // Fixed-size array of 10 bytes
  String strInvCodeVer = ''; // Fixed-size array of 10 bytes

  int nCommOffset = 0;
  int nTotalDiagNum = 0;
  int nModelNoCommAddr = 0; // 모델번호 가져오기 주소
  int nCodeVerCommAddr = 0; // Code Version 가져오기 주소
  int nMotorStatusCommAddr = 0; // Moter Status 가져오기 주소
  int nInvStatusCommAddr = 0; // 인버터 상태 가져오기 주소
  int nInvControlCommAddr = 0;
  int nParameterSaveCommAddr = 0;
  //-----------------------------------------------------------------------------------------------
  List<int> diagNumList = []; // Diag Number list
  //-----------------------------------------------------------------------------------------------
  Storage? storage;
  //===============================================================================================
  DeviceSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => deviceInfoPath;
  int get size => deviceInfoSize;
  //-----------------------------------------------------------------------------------------------
  String get deviceInfoPath => '/Device Spec/Device Info';
  // 10 + 4 + 30 + 10 + 10 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 = 96 bytes, padding 때문에 100 bytes
  int get deviceInfoSize => 100; // DEVICE_INFO
  //-----------------------------------------------------------------------------------------------
  String get diagNumberPath => '/Device Spec/Diag Number';
  int get diagNumberSize => 4; // sizeof(int)
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // DeviceInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    if (buffer.isNotEmpty) {
      int offset = 0;
      //final byteData = buffer.buffer.asByteData();

      // strDataFileVer (10 bytes)
      strDataFileVer = _readString(buffer, offset, DMDF_SMALL_SIZE);
      //_readArray(strDataFileVer, buffer, offset, DMDF_SMALL_SIZE);
      offset += DMDF_SMALL_SIZE;
      offset += 2; // because padding

      // nInvModelNo (4 bytes)
      // final nInvModelNo = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
      nInvModelNo = _readU32(buffer, offset);
      offset += 4;

      // strInvModelName (30 bytes)
      strInvModelName = _readString(buffer, offset, DMDF_TITLE_SIZE);
      offset += DMDF_TITLE_SIZE;
      //offset += 2; // because padding

      // strInvSWVer (10 bytes)
      strInvSWVer = _readString(buffer, offset, DMDF_SMALL_SIZE);
      offset += DMDF_SMALL_SIZE;

      // strInvCodeVer (10 bytes)
      strInvCodeVer = _readString(buffer, offset, DMDF_SMALL_SIZE);
      offset += DMDF_SMALL_SIZE;
      offset += 2; // because padding

      // 나머지 정수 필드들 (각각 4 bytes)
      // final nCommOffset = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
      nCommOffset = _readU32(buffer, offset);
      offset += 4;
      nTotalDiagNum = _readU32(buffer, offset);
      offset += 4;
      nModelNoCommAddr = _readU32(buffer, offset);
      offset += 4;
      nCodeVerCommAddr = _readU32(buffer, offset);
      offset += 4;
      nMotorStatusCommAddr = _readU32(buffer, offset);
      offset += 4;
      nInvStatusCommAddr = _readU32(buffer, offset);
      offset += 4;
      nInvControlCommAddr = _readU32(buffer, offset);
      offset += 4;
      nParameterSaveCommAddr = _readU32(buffer, offset);

      int count = nTotalDiagNum;
      if (count > 0) {
        if (storage == null) {
          throw Exception('storage is null');
        }
        Stream stream = Stream(storage!, diagNumberPath);
        final temp = Uint8List(diagNumberSize); // 4:sizeof(int)
        for (int i = 0; i < count; i++) {
          if (await stream.read(temp, diagNumberSize) > 0) {
            diagNumList.add(_readU32(temp, 0));
          }
        }
      }
    }

    // print('PATH: $path');
    // print(' - strDataFileVer: $strDataFileVer');
    // print(' - nInvModelNo: $nInvModelNo');
    // print(' - strInvModelName: $strInvModelName');
    // print(' - strInvSWVer: $strInvSWVer');
    // print(' - strInvCodeVer: $strInvCodeVer');
    // print(' - nCommOffset: $nCommOffset');
    // print(' - nTotalDiagNum: $nTotalDiagNum');
    // print('   - diagNumber: $diagNumList');
    // if (diagNumList.isNotEmpty) {
    //   for (int i = 0; i < diagNumList.length; i++) {
    //     print('     - diagNum[$i]: ${diagNumList[i]}');
    //   }
    // }
    // print(' - nModelNoCommAddr: $nModelNoCommAddr');
    // print(' - nCodeVerCommAddr: $nCodeVerCommAddr');
    // print(' - nMotorStatusCommAddr: $nMotorStatusCommAddr');
    // print(' - nInvStatusCommAddr: $nInvStatusCommAddr');
    // print(' - nInvControlCommAddr: $nInvControlCommAddr');
    // print(' - nParameterSaveCommAddr: $nParameterSaveCommAddr');

    return {
      'strDataFileVer': strDataFileVer,
      'nInvModelNo': nInvModelNo,
      'strInvModelName': strInvModelName,
      'strInvSWVer': strInvSWVer,
      'strInvCodeVer': strInvCodeVer,
      'nCommOffset': nCommOffset,
      'nTotalDiagNum': nTotalDiagNum,
      'nModelNoCommAddr': nModelNoCommAddr,
      'nCodeVerCommAddr': nCodeVerCommAddr,
      'nMotorStatusCommAddr': nMotorStatusCommAddr,
      'nInvStatusCommAddr': nInvStatusCommAddr,
      'nInvControlCommAddr': nInvControlCommAddr,
      'nParameterSaveCommAddr': nParameterSaveCommAddr,
      'pDiagNum': diagNumList,
      'pDiagNumDetails': diagNumList
          .asMap()
          .entries
          .map((entry) => {'index': entry.key, 'value': entry.value})
          .toList(),
    };
  }
}

//=================================================================================================
// IoSpec 클래스: 입출력 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class IoSpec {
  //===============================================================================================
  int nTotalInput = 0;
  int nNormalInput = 0;
  int nTotalInputFuncTitle = 0;
  int nTotalOutput = 0;
  int nNormalOutput = 0;
  int nTotalOutputFuncTitle = 0;

  int nAddInputStatus = 0; //입력 단자 상태 정보 통신주소
  int nAddOutputStatus = 0; //출력 단자 상태 정보 동신주소
  //-----------------------------------------------------------------------------------------------
  // Terminal Info
  List<Map<String, dynamic>> inputTermInfoList = [];
  List<Map<String, dynamic>> outputTermInfoList = [];
  //-----------------------------------------------------------------------------------------------
  // IO Func Msg Title
  List<String> inputFuncMsgList = [];
  List<String> outputFuncMsgList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  IoSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => ioInfoPath;
  int get size => ioInfoSize;
  //-----------------------------------------------------------------------------------------------
  String get ioInfoPath => '/IO Spec/IO Info';
  int get ioInfoSize => 32; // IO_INFO
  //-----------------------------------------------------------------------------------------------
  String get terminalInfoPath => '/IO Spec/Terminal Info';
  int get terminalInfoSize => 36; // TERMINAL_INFO
  //-----------------------------------------------------------------------------------------------
  String get funcMsgTitlePath => '/IO Spec/IO Func Msg Title';
  int get funcMsgTitleSize => 30; // IO_FUNC_MSG_TITLE
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // IoInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    int offset = 0;
    //final byteData = buffer.buffer.asByteData();

    int readInt32() {
      //final value = byteData.getInt32(offset, Endian.little);
      final value = _readU32(buffer, offset);
      offset += 4;
      return value;
    }

    inputTermInfoList.clear();
    outputTermInfoList.clear();
    inputFuncMsgList.clear();
    outputFuncMsgList.clear();

    if (buffer.isNotEmpty) {
      nTotalInput = readInt32();
      nNormalInput = readInt32();
      nTotalInputFuncTitle = readInt32();
      nTotalOutput = readInt32();
      nNormalOutput = readInt32();
      nTotalOutputFuncTitle = readInt32();
      nAddInputStatus = readInt32();
      nAddOutputStatus = readInt32();

      int count = nTotalInput + nTotalOutput;
      if (count > 0) {
        if (storage == null) {
          throw Exception('storage is null');
        }
        Stream stream = Stream(storage!, terminalInfoPath);
        if (!stream.fail()) {
          final temp = Uint8List(terminalInfoSize); // 36
          for (int i = 0; i < nTotalInput; i++) {
            if (await stream.read(temp, terminalInfoSize) > 0) {
              Map<String, dynamic> map = {
                'strName': _readString(temp, 0, 30),
                'nCommAddr': _readU32(temp, 32),
              };
              inputTermInfoList.add(map);
            }
          }
          for (int i = 0; i < nTotalOutput; i++) {
            if (await stream.read(temp, terminalInfoSize) > 0) {
              Map<String, dynamic> map = {
                'strName': _readString(temp, 0, 30),
                'nCommAddr': _readU32(temp, 32),
              };
              outputTermInfoList.add(map);
            }
          }
        }
      }

      count = nTotalInputFuncTitle + nTotalOutputFuncTitle;
      if (count > 0) {
        if (storage == null) {
          throw Exception('storage is null');
        }
        Stream stream = Stream(storage!, funcMsgTitlePath);
        if (!stream.fail()) {
          final temp = Uint8List(funcMsgTitleSize); // 30
          for (int i = 0; i < nTotalInputFuncTitle; i++) {
            if (await stream.read(temp, funcMsgTitleSize) > 0) {
              inputFuncMsgList.add(_readString(temp, 0, funcMsgTitleSize));
            }
          }
          for (int i = 0; i < nTotalOutputFuncTitle; i++) {
            if (await stream.read(temp, funcMsgTitleSize) > 0) {
              outputFuncMsgList.add(_readString(temp, 0, funcMsgTitleSize));
            }
          }
        }
      }
    }

    // print('PATH: $path');
    // print(' - nTotalInput: $nTotalInput');
    // print(' - nNormalInput: $nNormalInput');
    // print(' - nTotalInputFuncTitle: $nTotalInputFuncTitle');
    // print(' - nTotalOutput: $nTotalOutput');
    // print(' - nNormalOutput: $nNormalOutput');
    // print(' - nTotalOutputFuncTitle: $nTotalOutputFuncTitle');
    // print(' - nAddInputStatus: $nAddInputStatus');
    // print(' - nAddOutputStatus: $nAddOutputStatus');
    // print('   - pInputTermInfo: $inputTermInfoList');
    // print('   - pOutputTermInfo: $outputTermInfoList');
    // print('   - pInputFuncMsg: $inputFuncMsgList');
    // print('   - pOutputFuncMsgTitle: $outputFuncMsgList');

    return {
      'nTotalInput': nTotalInput,
      'nNormalInput': nNormalInput,
      'nTotalInputFuncTitle': nTotalInputFuncTitle,
      'nTotalOutput': nTotalOutput,
      'nNormalOutput': nNormalOutput,
      'nTotalOutputFuncTitle': nTotalOutputFuncTitle,
      'nAddInputStatus': nAddInputStatus,
      'nAddOutputStatus': nAddOutputStatus,
      'pInputTermInfo': inputTermInfoList,
      'pOutputTermInfo': outputTermInfoList,
      'pInputFuncMsg': inputFuncMsgList,
      'pOutputFuncMsgTitle': outputFuncMsgList,
    };
  }
}

//=================================================================================================
// TripSpec 클래스: 트립 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class TripSpec {
  int nTotalTripName = 0;
  int nFirstTripNameAddr = 0;
  int nCurTotalTrip = 0;
  int nTotalTripInfo = 0;
  int nTotalWarnName = 0;
  int nFirstWarnNameAddr = 0;
  int nCurTotalWarn = 0;
  int nTotalWarnInfo = 0;
  //-----------------------------------------------------------------------------------------------
  // Trip Name
  List<String> tripNameList = [];
  List<String> warnNameList = [];
  //-----------------------------------------------------------------------------------------------
  // Comm Addr
  List<int> tripAddrList = [];
  List<int> warnAddrList = [];
  //-----------------------------------------------------------------------------------------------
  // Trip Info Data
  List<Map<String, dynamic>> tripInfoDataList = [];
  List<Map<String, dynamic>> warnInfoDataList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  TripSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => tripInfoPath;
  int get size => tripInfoSize;
  //-----------------------------------------------------------------------------------------------
  String get tripInfoPath => '/Trip Spec/Trip Info';
  int get tripInfoSize => 32; // TRIP_INFO_TYPE
  //-----------------------------------------------------------------------------------------------
  String get tripNamePath => '/Trip Spec/Trip Name';
  int get tripNameSize => 30; // TRIP_NAME
  //-----------------------------------------------------------------------------------------------
  String get tripInfoDataPath => '/Trip Spec/Trip Info Data';
  int get tripInfoDataSize => 56; // TRIP_INFO_DATA
  //-----------------------------------------------------------------------------------------------
  String get commAddrPath => '/Trip Spec/Comm Addr';
  int get commAddrSize => 4; // sizeof(int)
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    int offset = 0;
    //final byteData = buffer.buffer.asByteData();

    int readInt32() {
      //final value = byteData.getInt32(offset, Endian.little);
      final value = _readU32(buffer, offset);
      offset += 4;
      return value;
    }

    tripNameList.clear();
    warnNameList.clear();
    tripAddrList.clear();
    warnAddrList.clear();
    tripInfoDataList.clear();
    warnInfoDataList.clear();

    if (buffer.isNotEmpty) {
      nTotalTripName = readInt32();
      nFirstTripNameAddr = readInt32();
      nCurTotalTrip = readInt32();
      nTotalTripInfo = readInt32();
      nTotalWarnName = readInt32();
      nFirstWarnNameAddr = readInt32();
      nCurTotalWarn = readInt32();
      nTotalWarnInfo = readInt32();

      // Trip Name
      int count = nTotalTripName + nTotalWarnName;
      if (count > 0) {
        Stream stream = Stream(storage!, tripNamePath);
        if (!stream.fail()) {
          final temp = Uint8List(tripNameSize); // 30
          for (int i = 0; i < nTotalTripName; i++) {
            if (await stream.read(temp, tripNameSize) > 0) {
              tripNameList.add(_readString(temp, 0, tripNameSize));
            }
          }
          for (int i = 0; i < nTotalWarnName; i++) {
            if (await stream.read(temp, tripNameSize) > 0) {
              warnNameList.add(_readString(temp, 0, tripNameSize));
            }
          }
        }
      }

      // Comm Addr
      count = nCurTotalTrip + nCurTotalWarn;
      if (count > 0) {
        Stream stream = Stream(storage!, commAddrPath);
        if (!stream.fail()) {
          final temp = Uint8List(commAddrSize); // 4
          for (int i = 0; i < nCurTotalTrip; i++) {
            if (await stream.read(temp, commAddrSize) > 0) {
              tripAddrList.add(_readU32(temp, 0));
            }
          }
          for (int i = 0; i < nCurTotalWarn; i++) {
            if (await stream.read(temp, commAddrSize) > 0) {
              warnAddrList.add(_readU32(temp, 0));
            }
          }
        }
      }

      // Trip Info Data
      count = nTotalTripInfo + nTotalWarnInfo;
      if (count > 0) {
        Stream stream = Stream(storage!, tripInfoDataPath);
        if (!stream.fail()) {
          final temp = Uint8List(tripInfoDataSize); // 36
          for (int i = 0; i < nTotalTripInfo; i++) {
            if (await stream.read(temp, tripInfoDataSize) > 0) {
              Map<String, dynamic> map = {
                'nCommAddr': _readU32(temp, 0), // 4
                'strName': _readString(temp, 4, 30), // 30+2
                'nDataType': _readU32(temp, 36), // 4
                'nPointMsg': _readU32(temp, 40), // 4
                'strUnit': _readString(temp, 44, 10), // 10+2
              };
              tripInfoDataList.add(map);
            }
          }
          for (int i = 0; i < nTotalWarnInfo; i++) {
            if (await stream.read(temp, tripInfoDataSize) > 0) {
              Map<String, dynamic> map = {
                'nCommAddr': _readU32(temp, 0), // 4
                'strName': _readString(temp, 4, 30), // 30+2
                'nDataType': _readU32(temp, 36), // 4
                'nPointMsg': _readU32(temp, 40), // 4
                'strUnit': _readString(temp, 44, 10), // 10+2
              };
              warnInfoDataList.add(map);
            }
          }
        }
      }
    }

    // print('PATH: $path');
    // print(' - nTotalTripName: $nTotalTripName');
    // print(' - nFirstTripNameAddr: $nFirstTripNameAddr');
    // print(' - nCurTotalTrip: $nCurTotalTrip');
    // print(' - nTotalTripInfo: $nTotalTripInfo');
    // print(' - nTotalWarnName: $nTotalWarnName');
    // print(' - nFirstWarnNameAddr: $nFirstWarnNameAddr');
    // print(' - nCurTotalWarn: $nCurTotalWarn');
    // print(' - nTotalWarnInfo: $nTotalWarnInfo');
    // print('   - pTripName: $tripNameList');
    // print('   - pWarnName: $warnNameList');
    // print('   - pTripAddr: $tripAddrList');
    // print('   - pWarnAddr: $warnAddrList');
    // print('   - pWarnAddr: $tripInfoDataList');
    // print('   - pWarnInfoData: $warnInfoDataList');

    return {
      'nTotalTripName': nTotalTripName,
      'nFirstTripNameAddr': nFirstTripNameAddr,
      'nCurTotalTrip': nCurTotalTrip,
      'nTotalTripInfo': nTotalTripInfo,
      'nTotalWarnName': nTotalWarnName,
      'nFirstWarnNameAddr': nFirstWarnNameAddr,
      'nCurTotalWarn': nCurTotalWarn,
      'nTotalWarnInfo': nTotalWarnInfo,
      'pTripName': tripNameList,
      'pWarnName': warnNameList,
      'pTripAddr': tripAddrList,
      'pWarnAddr': warnAddrList,
      'pTripInfoData': tripInfoDataList,
      'pWarnInfoData': warnInfoDataList,
    };
  }
}

//=================================================================================================
// MsgSpec 클래스: 메시지 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class MsgSpec {
  int nTotalMsg = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> msgInfoList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  MsgSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => totalMessagePath;
  int get size => totalMessageSize;
  //-----------------------------------------------------------------------------------------------
  String get totalMessagePath => '/Message Spec/Total Message';
  int get totalMessageSize => 4;
  //-----------------------------------------------------------------------------------------------
  String get msgTitleNumPath => '/Message Spec/Msg Title Num';
  int get msgTitleNumSize => 4;
  //-----------------------------------------------------------------------------------------------
  String get msgTitlePath => '/Message Spec/Msg Title';
  int get msgTitleSize => 30; // MESSAGE_TITLE
  int get msgInfoSize => 16; // MESSAGE_INFO
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    nTotalMsg = 0;
    msgInfoList.clear();

    if (buffer.isNotEmpty) {
      nTotalMsg = _readU32(buffer, 0);
      if (nTotalMsg > 0) {
        Stream msgTitleNumStream = Stream(storage!, msgTitleNumPath);
        Stream msgTitleStream = Stream(storage!, msgTitlePath);

        final tempNum = Uint8List(msgTitleNumSize); // 4
        final tempTitle = Uint8List(msgTitleSize); // 30

        int nCount = nTotalMsg;
        for (int x = 0; x < nCount; x++) {
          int msgTitleNum = 0;
          if (await msgTitleNumStream.read(tempNum, msgTitleNumSize) > 0) {
            if ((msgTitleNum = _readU32(tempNum, 0)) > 0) {
              List<String> msgTitleList = [];
              for (int y = 0; y < msgTitleNum; y++) {
                if (await msgTitleStream.read(tempTitle, msgTitleSize) > 0) {
                  msgTitleList.add(_readString(tempTitle, 0, msgTitleSize));
                }
              }

              Map<String, dynamic> map = {
                'nTotTitle': '$msgTitleNum',
                'pTitle': msgTitleList,
              };
              msgInfoList.add(map);
            }
          }
        }
      }
    }
    // print('PATH: $path');
    // print(' - nTotalMsg: $nTotalMsg');
    // print(' - pMsgInfo: $msgInfoList');

    return {'nTotalMsg': nTotalMsg, 'pMsgInfo': msgInfoList};
  }
}

//=================================================================================================
// CommonSpec 클래스: 공통 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class CommonSpec {
  int nTotCommonNo = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> commonInfoList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  CommonSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => totalCommonNoPath;
  int get size => totalCommonNoSize;
  //-----------------------------------------------------------------------------------------------
  String get totalCommonNoPath => '/Common Spec/Total Common';
  int get totalCommonNoSize => 4;
  //-----------------------------------------------------------------------------------------------
  String get commonInfoPath => '/Common Spec/Common Info';
  int get commonInfoSize => 72;
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    commonInfoList.clear();
    nTotCommonNo = 0;

    if (buffer.isNotEmpty) {
      nTotCommonNo = _readU32(buffer, 0);
      if (nTotCommonNo > 0) {
        Stream stream = Stream(storage!, commonInfoPath);
        final temp = Uint8List(commonInfoSize); // 4
        for (int i = 0; i < nTotCommonNo; i++) {
          if (await stream.read(temp, commonInfoSize) > 0) {
            Map<String, dynamic> map = {
              'nCommAddr': _readU32(temp, 0),
              'strName': _readString(temp, 4, 30), // 30+2
              'nDefault': _readU32(temp, 36),
              'nMax': _readU32(temp, 40),
              'nMin': _readU32(temp, 44),
              'nDataType': _readU32(temp, 48),
              'nPointMsg': _readU32(temp, 52),
              'strUnit': _readString(temp, 56, 10), // 10+2
              'nAttribute': _readU32(temp, 68),
            };
            commonInfoList.add(map);
          }
        }
      }
    }

    // print('PATH: $path');
    // print(' - nTotCommonNo: $nTotCommonNo');
    // print(' - pCommonInfo: $commonInfoList');

    return {'nTotCommonNo': nTotCommonNo, 'pCommonInfo': commonInfoList};
  }
}

//=================================================================================================
// ParameterSpec 클래스: 파라미터 사양 정보 파싱
//-------------------------------------------------------------------------------------------------
class ParameterSpec {
  int nTotGroup = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> parmGrpList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  ParameterSpec(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => totalGroupPath;
  int get size => totalGroupSize;
  //-----------------------------------------------------------------------------------------------
  String get totalGroupPath => '/Parameter Spec/Total Group';
  int get totalGroupSize => 4;
  //-----------------------------------------------------------------------------------------------
  String get groupInfoPath => '/Parameter Spec/Group-%1/Group Info';
  int get groupInfoSize => 24;
  //-----------------------------------------------------------------------------------------------
  String get parameterPath => '/Parameter Spec/Group-%1/Parameter';
  int get parameterSize => 100;
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    parmGrpList.clear();
    nTotGroup = 0;

    if (buffer.isNotEmpty) {
      nTotGroup = _readU32(buffer, 0);
      if (nTotGroup > 0) {
        final infoButter = Uint8List(groupInfoSize);
        final parmButter = Uint8List(parameterSize);

        //print('ParameterSpec::_parseData() - nTotGroup: $nTotGroup');

        for (int i = 0; i < nTotGroup; i++) {
          final groupInfoPath = '/Parameter Spec/Group-$i/Group Info';
          final parameterPath = '/Parameter Spec/Group-$i/Parameter';

          //print('ParameterSpec::_parseData() - groupInfoPath: $groupInfoPath');
          //print('ParameterSpec::_parseData() - parameterPath: $parameterPath');

          Stream groupInfoStream = Stream(storage!, groupInfoPath);
          Stream parameterStream = Stream(storage!, parameterPath);

          //Map<String, dynamic> grpParamMap = {};
          Map<String, dynamic> paramMap = {};
          int nTotParm = 0;

          if (!groupInfoStream.fail() && !parameterStream.fail()) {
            if (await groupInfoStream.read(infoButter, groupInfoSize) > 0) {
              //Map<String, dynamic> map = {
              paramMap = {
                'nGrpNum': _readU32(infoButter, 0),
                'strGrpName': _readString(infoButter, 4, 10), // 10+2
                'nAttribute': _readU32(infoButter, 16),
                'nTotParm': _readU32(infoButter, 20),
              };
              nTotParm = paramMap['nTotParm'];
              //grpParamMap['GrpInfo'] = map;
              // grpParamMap.addAll({
              //   'GrpInfo': map,
              // });
            }
            //print('ParameterSpec::_parseData() - nTotParm: $nTotParm');
            //print('paramMap -$paramMap');

            List<Map<String, dynamic>> parmTypeList = [];
            for (int nParmCnt = 0; nParmCnt < nTotParm; nParmCnt++) {
              if (await parameterStream.read(parmButter, parameterSize) > 0) {
                Map<String, dynamic> typeMap = {
                  'nCodeNum': _readU32(parmButter, 0),
                  'strNameHz': _readString(parmButter, 4, 30), //
                  'strNameRpm': _readString(parmButter, 34, 30), //
                  'nDefault': _readU32(parmButter, 64),
                  'nMax': _readU32(parmButter, 68),
                  'nMin': _readU32(parmButter, 72),
                  'nDataType': _readU32(parmButter, 76),
                  'nPointMsg': _readU32(parmButter, 80),
                  'strUnit': _readString(parmButter, 84, 10), // 10+2
                  'nAttribute': _readU32(parmButter, 96),
                };
                parmTypeList.add(typeMap);
              }
            }
            //grpParamMap['pParmType'] = parmTypeList;
            // grpParamMap.addAll({
            //   'pParmType': parmTypeList,
            // });

            Map<String, dynamic> grpParamMap = {
              'GrpInfo': paramMap,
              'pParmType': parmTypeList,
            };
            parmGrpList.add(grpParamMap);
          }
        }
      }
    }

    //print('PATH: $path');
    //print(' - nTotGroup: $nTotGroup');
    //print(' - pParmGrp: $parmGrpList');

    return {'nTotGroup': nTotGroup, 'pParmGrp': parmGrpList};
  }
}

//=================================================================================================
// InitOrder 클래스: 초기화 순서 정보 파싱
//-------------------------------------------------------------------------------------------------
class InitOrder {
  int nTotInitOder = 0;
  //-----------------------------------------------------------------------------------------------
  List<int> orderAddrList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage? storage;
  //===============================================================================================
  InitOrder(this.storage);
  //-----------------------------------------------------------------------------------------------
  String get path => totalInitOrderPath;
  int get size => totalInitOrderSize;
  //-----------------------------------------------------------------------------------------------
  String get totalInitOrderPath => '/Init Order/Total Init Order';
  int get totalInitOrderSize => 4;
  //-----------------------------------------------------------------------------------------------
  String get initOrderParaAddrPath => '/Init Order/Init Order Para Addr';
  int get initOrderParaAddrSize => 4;
  //-----------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> parse() async {
    try {
      if (storage == null) {
        throw Exception('storage is null');
      }
      Stream stream = Stream(storage!, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      stream.read(buffer, size);
      return _parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {'error': e.toString()};
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> _parseData(Uint8List buffer) async {
    orderAddrList.clear();
    nTotInitOder = 0;

    if (buffer.isNotEmpty) {
      nTotInitOder = _readU32(buffer, 0);
      if (nTotInitOder > 0) {
        Stream stream = Stream(storage!, initOrderParaAddrPath);
        final temp = Uint8List(initOrderParaAddrSize);
        for (int i = 0; i < nTotInitOder; i++) {
          if (stream.read(temp, initOrderParaAddrSize) > 0) {
            orderAddrList.add(_readU32(temp, 0));
          }
        }
      }
    }

    // print('PATH: $path');
    // print(' - nTotInitOder: $nTotInitOder');

    return {'nTotInitOder': nTotInitOder, 'pOrderAddr': orderAddrList};
  }
}

//=================================================================================================
// JSON 데이터를 클래스 멤버 변수에 설정하는 함수들
//-------------------------------------------------------------------------------------------------
class _TitleFromJson {
  //String jsonFilePath = ''; // 'assets/S300_1_00_Title.json';
  Map<String, dynamic> _jsonData = {};
  final Map<int, String> _mapTitle = {};

  _TitleFromJson();

  Future<bool> load(String filePath, {bool isAssets = true}) async {
    try {
      if (isAssets) {
        return await _loadAssets(filePath);
      } else {
        return await _loadFile(filePath);
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _loadAssets(String filePath) async {
    //=============================================================================================
    // pubspec.yaml 파일에서 아래 처럼 assets에서 파일 위치를 정해 주어야 함.
    //---------------------------------------------------------------------------------------------
    // flutter:
    //  assets:
    //    - assets/S300_1_00.json
    //    - assets/S300_1_00_Title.json
    //    - assets/LSIS/S300/S300_1_00.json
    //    - assets/LSIS/S300/S300_1_00_Title.json
    //---------------------------------------------------------------------------------------------

    // print('_TitleFromJson::loadAssets() - 파일 경로: $filePath');
    try {
      // assets 폴더의 파일을 읽기 위해 rootBundle 사용, 'assets/S300_1_00.json';
      final jsonString = await rootBundle.loadString(filePath);
      _jsonData = json.decode(jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('JSON 파일 로드 중 오류 발생: $e');
      }
      _jsonData = {};
      return false;
    }

    return true;
  }

  // 현재는 사용하지 않음. 모두 assets 에서 파일을 로드함.
  Future<bool> _loadFile(String filePath) async {
    //print('_TitleFromJson::loadFile() - 파일 경로: $filePath');
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      _jsonData = json.decode(jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('JSON 파일 로드 중 오류 발생: $e');
      }
      _jsonData = {};
      return false;
    }

    return true;
  }

  Map<int, String> titles() {
    _mapTitle.clear();
    try {
      final parser = _jsonData['Titles'];
      if (parser != null && parser is List) {
        for (var element in parser) {
          final id = element['id'];
          final text = element['Text'];

          //print('_TitleFromJson::titles() - id: $id, text: $text');

          _mapTitle[id] = text;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TitleSpec JSON 파싱 중 오류 발생: $e');
      }
    }

    return _mapTitle;
  }
}

//=================================================================================================
// JSON 데이터를 클래스 멤버 변수에 설정하는 함수들
//-------------------------------------------------------------------------------------------------
class SpecFromJson {
  //String jsonFilePath = ''; // 'assets/S300_1_00.json';
  Map<String, dynamic> _jsonData = {};
  //Map<int, String> _mapTitle = {};
  //_TitleFromJson titleFromJson = _TitleFromJson();
  Map<int, String>? _mapTitle;
  final Map<int, String> _mapUnits = {};

  //===============================================================================================
  SpecFromJson();
  //-----------------------------------------------------------------------------------------------
  //Map<int, String> get _mapTitle => titleFromJson._mapTitle;
  String titieFileName(String filePath) {
    final index = filePath.indexOf('.json'); // 'assets/S300_1_00.json';
    if (index != -1) {
      final fileNameWithoutExt = filePath.substring(0, index);
      return '${fileNameWithoutExt}_Title.json'; // 'S300_1_00_Title.json'
      // if (Platform.isWindows) {
      //   final fileNameWithoutExt = filePath.substring(0, index);
      //   return '${fileNameWithoutExt}_Title.json'; // 'S300_1_00_Title.json'
      // } else {
      //   final fileNameWithoutExt = filePath.substring(0, index);
      //   final fileName = fileNameWithoutExt.split('/').last;
      //   return 'assets/DataFile/LSIS/S300/${fileName}_Title.json'; // 'S300_1_00_Title.json'
      //   //return 'assets/${fileName}_Title.json'; // 'S300_1_00_Title.json'
      // }
    }
    return '';
  }

  //-----------------------------------------------------------------------------------------------
  Future<bool> load(String filePath, {bool isAssets = true}) async {
    try {
      if (isAssets) {
        return await loadAssets(filePath);
      } else {
        return await _loadFile(filePath);
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> loadAssets(String filePath) async {
    //=============================================================================================
    // pubspec.yaml 파일에서 아래 처럼 assets에서 파일 위치를 정해 주어야 함.
    //---------------------------------------------------------------------------------------------
    // flutter:
    //  assets:
    //    - assets/S300_1_00.json
    //    - assets/S300_1_00_Title.json
    //    - assets/LSIS/S300/S300_1_00.json
    //    - assets/LSIS/S300/S300_1_00_Title.json
    //---------------------------------------------------------------------------------------------

    _jsonData = {};
    _mapTitle = null;
    try {
      // assets 폴더의 파일을 읽기 위해 rootBundle 사용, 'assets/S300_1_00.json';
      final jsonString = await rootBundle.loadString(filePath);
      _jsonData = json.decode(jsonString);

      // print('SpecFromJson::loadAssetsJson() - 파일 경로: $filePath');

      final titlePath = titieFileName(filePath);
      if (titlePath.isNotEmpty) {
        // print('SpecFromJson::loadAssetsJson() - 원본 파일명: $fileName');
        // print('SpecFromJson::loadAssetsJson() - Title 파일명: $titleFileName');
        // print('SpecFromJson::loadAssetsJson() - Title 파일 경로: $titlePath');

        // Title 파일 로드 시도
        _TitleFromJson titleFromJson = _TitleFromJson();
        if (await titleFromJson.load(titlePath)) {
          //final res = titleFromJson.titles();
          _mapTitle = titleFromJson.titles();
          // print(
          //     'SpecFromJson::loadAssetsJson() - Title 파일 로드 성공: ${titleFromJson._mapTitle.length}개 항목');
        } else {
          if (kDebugMode) {
            print(
              'SpecFromJson::loadAssetsJson() - Title 파일 로드 실패 또는 파일 없음 !!! $titlePath',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print('SpecFromJson::loadAssetsJson() - Title 파일 없음 !!! $filePath');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('JSON 파일 로드 중 오류 발생: $e');
      }
      return false;
    }

    return true;
  }

  // 현재는 사용하지 않음. 모두 assets 에서 파일을 로드함.
  Future<bool> _loadFile(String filePath) async {
    _jsonData = {};
    _mapTitle = null;
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      _jsonData = json.decode(jsonString);

      // print('SpecFromJson::loadJson() - 파일 경로: $filePath');

      final titlePath = titieFileName(filePath);
      if (titlePath.isNotEmpty) {
        // print('SpecFromJson::loadJson() - 원본 파일명: $fileName');
        // print('SpecFromJson::loadJson() - Title 파일명: $titleFileName');
        // print('SpecFromJson::loadJson() - Title 파일 경로: $titlePath');

        // Title 파일 로드 시도
        _TitleFromJson titleFromJson = _TitleFromJson();
        if (await titleFromJson.load(titlePath, isAssets: false)) {
          //final res = titleFromJson.titles();
          _mapTitle = titleFromJson.titles();
          // print(
          //     'SpecFromJson::loadJson() - Title 파일 로드 성공: ${titleFromJson._mapTitle.length}개 항목');
        } else {
          if (kDebugMode) {
            print(
              'SpecFromJson::loadJson() - Title 파일 로드 실패 또는 파일 없음 !!! $titlePath',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print('SpecFromJson::loadJson() - Title 파일 없음 !!! $filePath');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('JSON 파일 로드 중 오류 발생: $e');
      }
      return false;
    }

    return true;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> deviceSpec(DeviceSpec spec) {
    Map<String, dynamic> result = {};
    try {
      //final DeviceSpec spec = DeviceSpec(null);
      final parser = _jsonData['Device'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      spec.strDataFileVer = parser['DataFileVersion'] ?? '';
      spec.nInvModelNo = parser['ModelNo'] ?? 0;
      spec.strInvModelName = parser['Model'] ?? '';
      spec.strInvSWVer = parser['InvSwVersion'] ?? '';
      spec.strInvCodeVer = parser['DataFileVersion'] ?? '';
      spec.nCommOffset = _parseHexAddress(parser['KeypadCommOffset16'] ?? '0');
      spec.nTotalDiagNum = 0; // ???
      spec.nModelNoCommAddr = _parseHexAddress(
        parser['ModelNoCommAddr'] ?? '0',
      );
      spec.nCodeVerCommAddr = 0; // ???
      spec.nMotorStatusCommAddr = _parseHexAddress(
        parser['MotorStatusCommAddr'] ?? '0',
      );
      spec.nInvStatusCommAddr = _parseHexAddress(
        parser['InvStatusCommAddr'] ?? '0',
      );
      spec.nInvControlCommAddr = _parseHexAddress(
        parser['InvControlCommAddr'] ?? '0',
      );
      spec.nParameterSaveCommAddr = _parseHexAddress(
        parser['ParaSaveCommAddr'] ?? '0',
      );

      // diagNumList 설정
      spec.diagNumList.clear();

      result = {
        'strDataFileVer': spec.strDataFileVer,
        'nInvModelNo': spec.nInvModelNo,
        'strInvModelName': spec.strInvModelName,
        'strInvSWVer': spec.strInvSWVer,
        'strInvCodeVer': spec.strInvCodeVer,
        'nCommOffset': spec.nCommOffset,
        'nTotalDiagNum': spec.nTotalDiagNum,
        'nModelNoCommAddr': spec.nModelNoCommAddr,
        'nCodeVerCommAddr': spec.nCodeVerCommAddr,
        'nMotorStatusCommAddr': spec.nMotorStatusCommAddr,
        'nInvStatusCommAddr': spec.nInvStatusCommAddr,
        'nInvControlCommAddr': spec.nInvControlCommAddr,
        'nParameterSaveCommAddr': spec.nParameterSaveCommAddr,
        'pDiagNum': <dynamic>[], // 빈 리스트로 반환
        'pDiagNumDetails': <dynamic>[], // 빈 리스트로 반환
      };
    } catch (e) {
      print('DeviceSpec JSON 파싱 중 오류 발생: $e');
      return result;
    }

    // print(' - strDataFileVer: ${spec.strDataFileVer}');
    // print(' - nInvModelNo: ${spec.nInvModelNo}');
    // print(' - strInvModelName: ${spec.strInvModelName}');
    // print(' - strInvSWVer: ${spec.strInvSWVer}');
    // print(' - strInvCodeVer: ${spec.strInvCodeVer}');
    // print(' - nCommOffset: ${spec.nCommOffset}');
    // print(' - nTotalDiagNum: ${spec.nTotalDiagNum}');
    // // print('   - diagNumber: $spec.diagNumList');
    // // if (spec.diagNumList.isNotEmpty) {
    // //   for (int i = 0; i < spec.diagNumList.length; i++) {
    // //     print('     - diagNum[$i]: ${spec.diagNumList[i]}');
    // //   }
    // // }
    // print(' - nModelNoCommAddr: ${spec.nModelNoCommAddr}');
    // print(' - nCodeVerCommAddr: ${spec.nCodeVerCommAddr}');
    // print(' - nMotorStatusCommAddr: ${spec.nMotorStatusCommAddr}');
    // print(' - nInvStatusCommAddr: ${spec.nInvStatusCommAddr}');
    // print(' - nInvControlCommAddr: ${spec.nInvControlCommAddr}');
    // print(' - nParameterSaveCommAddr: ${spec.nParameterSaveCommAddr}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> ioSpec(IoSpec spec, MsgSpec? msgSpec) {
    Map<String, dynamic> result = {};
    try {
      //final IoSpec spec = IoSpec(null);
      final parser = _jsonData['IO'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      spec.inputTermInfoList.clear();
      spec.inputFuncMsgList.clear();

      spec.outputTermInfoList.clear();
      spec.outputFuncMsgList.clear();

      final inputData = parser['Input'];
      final outputData = parser['Output'];

      Map<String, dynamic> msgRes = {};
      if (msgSpec != null) {
        msgRes = {
          'nTotalMsg': msgSpec.nTotalMsg,
          'pMsgInfo': msgSpec.msgInfoList,
        };
      } else {
        msgRes = _MessageFromJson();
      }

      // Input 데이터 처리
      if (inputData != null) {
        int nTotalNumOfExt = inputData['TotalNumOfExt'] ?? 0;
        spec.nNormalInput = inputData['TotalNumOfBasic'] ?? 0;
        spec.nTotalInput = spec.nNormalInput + nTotalNumOfExt;
        spec.nTotalInputFuncTitle = 0; // ???
        spec.nAddInputStatus = _parseHexAddress(
          inputData['StatusCommAddr'] ?? '0',
        );

        // inputTermInfoList 설정
        final termInfoData = inputData['BasicTerminalInfo'];
        if (termInfoData is List) {
          for (int nCnt = 0;
              nCnt < spec.nNormalInput && nCnt < termInfoData.length;
              nCnt++) {
            final info = termInfoData[nCnt];
            Map<String, dynamic> map = {
              'strName': makeTitleWithAtValue(
                _MapTitleName(info['Title::id']),
                info['AtValue'] ?? '',
              ),
              'nCommAddr': _parseHexAddress(info['CommAddr'] ?? '0'),
            };
            spec.inputTermInfoList.add(map);
          }
        }

        final extTerminalInfo = inputData['ExtTerminalInfo'];
        if (extTerminalInfo is List) {
          for (int nCnt = 0;
              nCnt < nTotalNumOfExt && nCnt < extTerminalInfo.length;
              nCnt++) {
            final info = extTerminalInfo[nCnt];
            Map<String, dynamic> map = {
              'strName': makeTitleWithAtValue(
                _MapTitleName(info['Title::id']),
                info['AtValue'] ?? '',
              ),
              'nCommAddr': _parseHexAddress(info['CommAddr'] ?? '0'),
            };
            spec.inputTermInfoList.add(map);
          }
        }

        // inputFuncMsgList 설정
        final msgId = inputData['Message::id'];
        if (msgId != null && msgId is int) {
          if (msgRes.isNotEmpty) {
            final msgInfoList = msgRes['pMsgInfo'];
            final element = msgInfoList[msgId];
            if (element.containsKey('pTitle')) {
              final titles = element['pTitle'] as List<String>;
              spec.inputFuncMsgList.addAll(titles);
            }
          }
        }
      }

      // Output 데이터 처리
      if (outputData != null) {
        int nTotalNumOfExt = outputData['TotalNumOfExt'] ?? 0;
        spec.nNormalOutput = outputData['TotalNumOfBasic'] ?? 0;
        spec.nTotalOutput = spec.nNormalOutput + nTotalNumOfExt;
        spec.nTotalOutputFuncTitle = 0; // ???
        spec.nAddOutputStatus = _parseHexAddress(
          outputData['StatusCommAddr'] ?? '0',
        );

        // outputTermInfoList 설정
        spec.outputTermInfoList.clear();
        final termInfoData = outputData['BasicTerminalInfo'];
        if (termInfoData is List) {
          for (int nCnt = 0;
              nCnt < spec.nNormalOutput && nCnt < termInfoData.length;
              nCnt++) {
            final info = termInfoData[nCnt];
            Map<String, dynamic> map = {
              'strName': makeTitleWithAtValue(
                _MapTitleName(info['Title::id']),
                info['AtValue'] ?? '',
              ),
              'nCommAddr': _parseHexAddress(info['CommAddr'] ?? '0'),
            };
            spec.outputTermInfoList.add(map);
          }
        }

        final extTerminalInfo = outputData['ExtTerminalInfo'];
        if (extTerminalInfo is List) {
          for (int nCnt = 0;
              nCnt < nTotalNumOfExt && nCnt < extTerminalInfo.length;
              nCnt++) {
            final info = extTerminalInfo[nCnt];
            Map<String, dynamic> map = {
              'strName': makeTitleWithAtValue(
                _MapTitleName(info['Title::id']),
                info['AtValue'] ?? '',
              ),
              'nCommAddr': _parseHexAddress(info['CommAddr'] ?? '0'),
            };
            spec.outputTermInfoList.add(map);
          }
        }

        // outputFuncMsgList 설정
        final msgId = outputData['Message::id'];
        if (msgId != null && msgId is int) {
          if (msgRes.isNotEmpty) {
            final msgInfoList = msgRes['pMsgInfo'];
            final element = msgInfoList[msgId];
            if (element.containsKey('pTitle')) {
              final titles = element['pTitle'] as List<String>;
              spec.outputFuncMsgList.addAll(titles);
            }
          }
        }
      }
      result = {
        'nTotalInput': spec.nTotalInput,
        'nNormalInput': spec.nNormalInput,
        'nTotalInputFuncTitle': spec.nTotalInputFuncTitle,
        'nAddInputStatus': spec.nAddInputStatus,
        'pInputTermInfo': spec.inputTermInfoList,
        'pInputFuncMsg': spec.inputFuncMsgList,
        'nTotalOutput': spec.nTotalOutput,
        'nNormalOutput': spec.nNormalOutput,
        'nTotalOutputFuncTitle': spec.nTotalOutputFuncTitle,
        'nAddOutputStatus': spec.nAddOutputStatus,
        'pOutputTermInfo': spec.outputTermInfoList,
        'pOutputFuncMsg': spec.outputFuncMsgList,
      };
    } catch (e) {
      print('IoSpec JSON 파싱 중 오류 발생: $e');
    }

    // print(' - nTotalInput: ${spec.nTotalInput}');
    // print(' - nNormalInput: ${spec.nNormalInput}');
    // print(' - nTotalInputFuncTitle: ${spec.nTotalInputFuncTitle}');
    // print(' - nTotalOutput: ${spec.nTotalOutput}');
    // print(' - nNormalOutput: ${spec.nNormalOutput}');
    // print(' - nTotalOutputFuncTitle: ${spec.nTotalOutputFuncTitle}');
    // print(' - nAddInputStatus: ${spec.nAddInputStatus}');
    // print(' - nAddOutputStatus: ${spec.nAddOutputStatus}');
    // print('   - pInputTermInfo: ${spec.inputTermInfoList}');
    // print('   - pOutputTermInfo: ${spec.outputTermInfoList}');
    // print('   - pInputFuncMsg: ${spec.inputFuncMsgList}');
    // print('   - pOutputFuncMsgTitle: ${spec.outputFuncMsgList}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> tripSpec(TripSpec spec, MsgSpec? msgSpec) {
    Map<String, dynamic> result = {};
    try {
      // LoadSpecTrips
      //final TripSpec spec = TripSpec(null);
      final parser = _jsonData['Trips'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      Map<String, dynamic> msgRes = {};
      Map<int, String> units = _UnitsFromJson();

      // LoadSpecTripInfo
      final statusInfo = parser['StatusInfo'];
      if (statusInfo == null) {
        throw 'parse error: LoadSpecTripInfo';
      }
      List<Map<String, dynamic>> statusInfoHash = [];

      // print('SpecFromJson::tripSpec()  1');
      if (statusInfo is List) {
        for (var info in statusInfo) {
          String pMessage = '';
          String strUnit = '';
          final msgId = info['Message::id'];
          if (msgId != null && msgId is int) {
            if (msgRes.isEmpty) {
              msgRes = _MsgFromMsg(msgSpec);
            }
            if (msgRes.isNotEmpty) {
              pMessage = msgRes['pMsgInfo'][msgId]['pTitle'][0]; //.at(0);
            }
          }

          if (units.isNotEmpty) {
            int nUnit = info['Unit::id'];
            if (nUnit > 0 && units.containsKey(nUnit)) {
              strUnit = units[info['Unit::id']] ?? '';
            } else {
              strUnit = '';
            }
          }

          Map<String, dynamic> map = {
            'nID': info['id'],
            'strName': makeTitleWithAtValue(
              _MapTitleName(info['Title::id']),
              info['AtValue'] ?? '',
            ),
            'nDataType': info['DataType'],
            'nPoint': info['Point16'],
            'pMessage': pMessage,
            'strUnit': strUnit,
          };
          statusInfoHash.add(map);
        }
      }

      // LoadSpecTripCurTrip
      final currentTrip = parser['CurrentTrip'];
      if (currentTrip == null) {
        throw 'parse error: LoadSpecTripCurTrip';
      }
      spec.nFirstTripNameAddr = _parseHexAddress(
        currentTrip['FirstTripAddr'] ?? '0',
      );

      spec.tripAddrList.clear();
      final tripAddrs = currentTrip['TripAddr'];
      if (tripAddrs is List) {
        for (var addr in tripAddrs) {
          spec.tripAddrList.add(_parseHexAddress(addr));
        }
      }

      spec.tripInfoDataList.clear();
      final tripInfoData = currentTrip['StatusInfoData'];
      if (tripInfoData is List) {
        spec.nTotalTripInfo = tripInfoData.length;
        for (var element in tripInfoData) {
          final statusInfoId = element['StatusInfo::id'];
          int? statusInfoIndex;

          if (statusInfoId is int) {
            statusInfoIndex = statusInfoId;
          } else if (statusInfoId is String) {
            statusInfoIndex = int.tryParse(statusInfoId);
          }

          if (statusInfoIndex != null &&
              statusInfoIndex >= 0 &&
              statusInfoIndex < statusInfoHash.length) {
            final info = statusInfoHash[statusInfoIndex];
            if (info.isNotEmpty) {
              Map<String, dynamic> map = {
                'nCommAddr': _parseHexAddress(element['CommAddr'].toString()),
                'strName': info['strName'],
                'nDataType': info['nDataType'],
                'nPointMsg': info['nPoint'],
                'strUnit': info['strUnit'],
              };
              spec.tripInfoDataList.add(map);
            }
          } else {
            print('TripSpec: StatusInfo::id 변환 실패: $statusInfoId');
          }
        }
      }

      spec.tripNameList.clear();
      final tripMsgIdRaw = currentTrip['Message::id'];
      int? tripMsgId = 0;
      if (tripMsgIdRaw != null && tripMsgIdRaw is int) {
        tripMsgId = tripMsgIdRaw;
      }

      // print('SpecFromJson::tripSpec()  3 $tripMsgIdRaw, $tripMsgId');
      if (msgRes.isNotEmpty) {
        final pMsgInfo = msgRes['pMsgInfo'][tripMsgId];
        //spec.nTotalTripName = pMsgInfo['nTotTitle'];

        final titles = pMsgInfo['pTitle'] as List<String>;
        for (var title in titles) {
          spec.tripNameList.add(title);
        }
        spec.nTotalTripName = spec.tripNameList.length;
      }

      // LoadSpecTripCurWarn
      final currentWarning = parser['CurrentWarning'];
      if (currentWarning == null) {
        throw 'parse error: LoadSpecTripCurWarn';
      }

      spec.nFirstWarnNameAddr = _parseHexAddress(
        currentWarning['FirstWarnAddr'] ?? '0',
      );

      spec.warnAddrList.clear();
      final warnAddrs = currentWarning['WarnAddr'];
      if (warnAddrs is List) {
        for (var addr in warnAddrs) {
          spec.warnAddrList.add(_parseHexAddress(addr));
        }
      }

      spec.warnInfoDataList.clear();
      final warnInfoData = currentTrip['StatusInfoData'];
      if (warnInfoData is List) {
        spec.nTotalWarnInfo = warnInfoData.length;
        for (var element in warnInfoData) {
          final statusInfoId = element['StatusInfo::id'];
          int? statusInfoIndex;

          if (statusInfoId is int) {
            statusInfoIndex = statusInfoId;
          } else if (statusInfoId is String) {
            statusInfoIndex = int.tryParse(statusInfoId);
          }

          if (statusInfoIndex != null &&
              statusInfoIndex >= 0 &&
              statusInfoIndex < statusInfoHash.length) {
            final info = statusInfoHash[statusInfoIndex];
            if (info.isNotEmpty) {
              Map<String, dynamic> map = {
                'nCommAddr': _parseHexAddress(element['CommAddr'].toString()),
                'strName': info['strName'],
                'nDataType': info['nDataType'],
                'nPointMsg': info['nPoint'],
                'strUnit': info['strUnit'],
              };
              spec.warnInfoDataList.add(map);
            }
          } else {
            print('TripSpec: StatusInfo::id 변환 실패: $statusInfoId');
          }
        }
      }

      spec.warnNameList.clear();
      final warnMsgIdRaw = currentWarning['Message::id'];
      int warnMsgId = 0;
      if (warnMsgIdRaw != null && tripMsgIdRaw is int) {
        warnMsgId = warnMsgIdRaw;
      }

      if (msgRes.isNotEmpty) {
        final pMsgInfo = msgRes['pMsgInfo'][warnMsgId];
        //spec.nTotalWarnName = pMsgInfo['nTotTitle'];
        final titles = pMsgInfo['pTitle'] as List<String>;
        for (var title in titles) {
          spec.warnNameList.add(title);
        }
        spec.nTotalWarnName = spec.warnNameList.length;
      }

      // not implimented
      // LoadSpecTripHistory
      // final tripHistory = parser['TripHistory'];
      // if (tripHistory == null) {
      //   throw 'parse error: LoadSpecTripHistory';
      // }

      result = {
        'nTotalTripName': spec.nTotalTripName,
        'nFirstTripNameAddr': spec.nFirstTripNameAddr,
        'nCurTotalTrip': spec.nCurTotalTrip,
        'nTotalTripInfo': spec.nTotalTripInfo,
        'nTotalWarnName': spec.nTotalWarnName,
        'nFirstWarnNameAddr': spec.nFirstWarnNameAddr,
        'nCurTotalWarn': spec.nCurTotalWarn,
        'nTotalWarnInfo': spec.nTotalWarnInfo,
        'pTripName': spec.tripNameList,
        'pWarnName': spec.warnNameList,
        'pTripAddr': spec.tripAddrList,
        'pWarnAddr': spec.warnAddrList,
        'pTripInfoData': spec.tripInfoDataList,
        'pWarnInfoData': spec.warnInfoDataList,
      };
    } catch (e) {
      print('TripSpec JSON 파싱 중 오류 발생: $e');
      return result;
    }

    // print(' - nTotalTripName: ${spec.nTotalTripName}');
    // print(' - nFirstTripNameAddr: ${spec.nFirstTripNameAddr}');
    // print(' - nCurTotalTrip: ${spec.nCurTotalTrip}');
    // print(' - nTotalTripInfo: ${spec.nTotalTripInfo}');
    // print(' - nTotalWarnName: ${spec.nTotalWarnName}');
    // print(' - nFirstWarnNameAddr: ${spec.nFirstWarnNameAddr}');
    // print(' - nCurTotalWarn: ${spec.nCurTotalWarn}');
    // print(' - nTotalWarnInfo: ${spec.nTotalWarnInfo}');
    // print('   - pTripName: ${spec.tripNameList}');
    // print('   - pWarnName: ${spec.warnNameList}');
    // print('   - pTripAddr: ${spec.tripAddrList}');
    // print('   - pWarnAddr: ${spec.warnAddrList}');
    // print('   - pWarnAddr: ${spec.tripInfoDataList}');
    // print('   - pWarnInfoData: ${spec.warnInfoDataList}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> messageSpec(MsgSpec spec) {
    Map<String, dynamic> result = _MessageFromJson();
    if (result.isNotEmpty) {
      spec.nTotalMsg = result['nTotalMsg'];
      spec.msgInfoList.addAll(result['pMsgInfo']);
    } else {
      spec.nTotalMsg = 0;
      spec.msgInfoList.clear();
    }

    // print(' - nTotalMsg: ${spec.nTotalMsg}');
    // print(' - pMsgInfo: ${spec.msgInfoList}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> commonSpec(CommonSpec spec) {
    Map<String, dynamic> result = {};
    try {
      //final CommonSpec spec = CommonSpec(null);
      final parser = _jsonData['CommonParameters'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      spec.commonInfoList.clear();
      spec.nTotCommonNo = parser.length;

      Map<int, String> units = _UnitsFromJson();

      for (var element in parser) {
        int nPointMsg = element['Point32'] ?? 0;
        final msgId = element['Message::id'];
        if (msgId != null && msgId is int) {
          nPointMsg = msgId;
        }
        Map<String, dynamic> map = {
          'nCodeNum': element['CodeNum'],
          'nCommAddr': _parseHexAddress(element['CommAddr']),
          'strName': makeTitleWithAtValue(
            _mapTitle?[element['Title::id']] ?? '',
            element['AtValue'] ?? '',
          ),
          'nDefault': element['Def'],
          'nMax': element['Max'],
          'nMin': element['Min'],
          'nDataType': element['DataType'],
          'nPointMsg': nPointMsg,
          'strUnit': units[element['Unit::id']] ?? '',
          'nAttribute': _parseHexAddress(element['Attr']),
        };
        spec.commonInfoList.add(map);
      }
      result = {
        'nTotCommonNo': spec.commonInfoList.length,
        'pCommonInfo': spec.commonInfoList,
      };
    } catch (e) {
      print('CommonSpec JSON 파싱 중 오류 발생: $e');
      return result;
    }

    // print(' - nTotCommonNo: ${spec.nTotCommonNo}');
    // print(' - pCommonInfo: ${spec.commonInfoList}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> parameterSpec(ParameterSpec spec) {
    Map<String, dynamic> result = {};
    try {
      //final ParameterSpec spec = ParameterSpec(null);
      final parser = _jsonData['ParameterGroups'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      spec.parmGrpList.clear();
      spec.nTotGroup = parser.length;

      int nTotParm = 0;
      Map<String, dynamic> paramMap = {};
      Map<int, String> units = _UnitsFromJson();

      for (var group in parser) {
        Map<String, dynamic> paramMap = {
          'nGrpNum': group['GroupNum'],
          'strGrpName': (_mapTitle?[group['Title::id']] ?? '').replaceAll(
            ' Group',
            '',
          ),
          'nAttribute': _parseHexAddress(group['GroupAttr']),
          'nTotParm': group['Parameters'].length,
        };
        final paramList = group['Parameters'];
        List<Map<String, dynamic>> parmTypeList = [];
        if (paramList != null && paramList is List) {
          for (var element in paramList) {
            int nPointMsg = element['Point32'] ?? 0;
            final msgId = element['Message::id'];
            if (msgId != null && msgId is int) {
              nPointMsg = msgId;
            }
            Map<String, dynamic> typeMap = {
              'nCodeNum': element['CodeNum'],
              'strNameHz': makeTitleWithAtValue(
                _mapTitle?[element['Title::id']] ?? '',
                element['AtValue'] ?? '',
              ),
              'strNameRpm': makeTitleWithAtValue(
                _mapTitle?[element['Title::id']] ?? '',
                element['AtValue'] ?? '',
              ),
              'nDefault': element['Def'],
              'nMax': element['Max'],
              'nMin': element['Min'],
              'nDataType': element['DataType'],
              'nPointMsg': nPointMsg,
              'strUnit': units[element['Unit::id']] ?? '',
              'nAttribute': _parseHexAddress(element['Attr']),
            };
            parmTypeList.add(typeMap);
          }
        }
        spec.parmGrpList.add({'GrpInfo': paramMap, 'pParmType': parmTypeList});
      }
      spec.nTotGroup = spec.parmGrpList.length;
      result = {'nTotGroup': spec.nTotGroup, 'pParmGrp': spec.parmGrpList};
    } catch (e) {
      print('ParameterSpec JSON 파싱 중 오류 발생: $e');
      return result;
    }

    // print(' - nTotGroup: ${spec.nTotGroup}');
    // print(' - pParmGrp: ${spec.parmGrpList}');

    return result;
  }

  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> initOrder(InitOrder spec) {
    Map<String, dynamic> result = {};
    try {
      //final InitOrder spec = InitOrder(null);
      final parser = _jsonData['InitOrder'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }
    } catch (e) {
      print('InitOrder JSON 파싱 중 오류 발생: $e');
      return result;
    }
    return result;
  }

  //===============================================================================================
  // private:
  Map<int, String> _UnitsFromJson() {
    _mapUnits.clear();
    try {
      final parser = _jsonData['Units'];
      if (parser != null && parser is List) {
        for (var element in parser) {
          final id = element['id'];
          final text = element['Text'];

          if (id != null && text != null) {
            _mapUnits[id] = text.toString();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('_UnitsFromJson JSON 파싱 중 오류 발생: $e');
      }
    }

    return _mapUnits;
  }

  String _MapTitleName(int id) {
    if (_mapTitle != null) {
      return _mapTitle![id] ?? '';
    }
    return '';
  }

  Map<String, dynamic> _MessageFromJson() {
    Map<String, dynamic> result = {};

    try {
      final parser = _jsonData['Messages'];
      if (parser == null) {
        throw 'parse error: LoadSpecTrips';
      }

      if (parser is List) {
        int nTotalMsg = 0;
        List<Map<String, dynamic>> msgInfoList = [];

        int nTotTitle = 0;
        for (var msginfo in parser) {
          final titleinfo = msginfo['TitleInfo'];

          nTotTitle = titleinfo.length;
          if (nTotTitle > 0) {
            List<String> msgTitleList = [];

            for (var title in titleinfo) {
              if (title is Map<String, dynamic>) {
                msgTitleList.add(
                  makeTitleWithAtValue(
                    _MapTitleName(title['Title::id']),
                    title['AtValue'] ?? '',
                  ),
                );
              }
            }

            Map<String, dynamic> map = {
              'nTotTitle': '$nTotTitle',
              'pTitle': msgTitleList,
            };
            nTotalMsg++;
            msgInfoList.add(map);
          }
        }

        //spec.nTotalMsg = parser.length;
        result = {'nTotalMsg': nTotalMsg, 'pMsgInfo': msgInfoList};
      }
    } catch (e) {
      if (kDebugMode) {
        print('MessageSpec JSON 파싱 중 오류 발생: $e');
      }
      return result;
    }

    return result;
  }

  Map<String, dynamic> _MsgFromMsg(MsgSpec? msgSpec) {
    Map<String, dynamic> result = {};
    if (msgSpec != null) {
      result = {
        'nTotalMsg': msgSpec.nTotalMsg,
        'pMsgInfo': msgSpec.msgInfoList,
      };
    } else {
      result = _MessageFromJson();
    }
    return result;
  }

  //===============================================================================================
}

//=================================================================================================
