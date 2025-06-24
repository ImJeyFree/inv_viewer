import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'pole.dart';

//=================================================================================================
// Ref : docs\src\DriveView 9\include\DataFileDefine.h
//-------------------------------------------------------------------------------------------------

//=================================================================================================
// 크기 상수
//-------------------------------------------------------------------------------------------------
const int dmdfTitleSize = 30; // DMDF_TITLE_SIZE
const int dmdfUnitSize = 10; // DMDF_UNIT_SIZE
const int dmdfSmallSize = 10; // DMDF_SMALL_SIZE

//=================================================================================================
// for inv
//-------------------------------------------------------------------------------------------------
const String defPathDeviceInfo = "/Device Spec/Device Info";
const String defPathDiagNumber = "/Device Spec/Diag Number";
const String defPathIoInfo = "/IO Spec/IO Info";
const String defPathTerminalInfo = "/IO Spec/Terminal Info";
const String defPathIoFuncMsgTitle = "/IO Spec/IO Func Msg Title";
const String defPathTripInfo = "/Trip Spec/Trip Info";
const String defPathTripName = "/Trip Spec/Trip Name";
const String defPathCommAddr = "/Trip Spec/Comm Addr";
const String defPathTripInfoData = "/Trip Spec/Trip Info Data";
const String defPathTotalMessage = "/Message Spec/Total Message";
const String defPathMsgTitle = "/Message Spec/Msg Title";
const String defPathMsgTitleNum = "/Message Spec/Msg Title Num";
const String defPathCommonInfo = "/Common Spec/Common Info";
const String defPathTotalCommon = "/Common Spec/Total Common";
const String defPathTotalGroup = "/Parameter Spec/Total Group";
const String defPathParameter = "/Parameter Spec/Group-%1/Parameter";
const String defPathGroupInfo = "/Parameter Spec/Group-%1/Group Info";
const String defPathTotalInitOrder = "/Init Order/Total Init Order";
const String defPathInitOrderParaAddr = "/Init Order/Init Order Para Addr";

//=================================================================================================
int _readU16(Uint8List buffer, int offset) {
  if (offset < 0 || offset + 2 > buffer.length) {
    throw RangeError('Offset out of range: $offset');
  }
  return buffer[offset] | (buffer[offset + 1] << 8);
}

int _readU32(Uint8List buffer, int offset) {
  return buffer[offset] |
      (buffer[offset + 1] << 8) |
      (buffer[offset + 2] << 16) |
      (buffer[offset + 3] << 24);
}

int _readU64(Uint8List buffer, int offset) {
  if (offset < 0 || offset + 8 > buffer.length) {
    throw RangeError('Offset out of range: $offset');
  }
  return buffer[offset] |
      (buffer[offset + 1] << 8) |
      (buffer[offset + 2] << 16) |
      (buffer[offset + 3] << 24) |
      (buffer[offset + 4] << 32) |
      (buffer[offset + 5] << 40) |
      (buffer[offset + 6] << 48) |
      (buffer[offset + 7] << 56);
}

String _readString(Uint8List buffer, int offset, int length) {
  List<int> bytes = [];
  for (int i = 0; i < length; i++) {
    if (buffer[offset + i] == 0) break;
    bytes.add(buffer[offset + i]);
  }
  return String.fromCharCodes(bytes);
}

int _readArray(Array<Uint8> dst, Uint8List src, int offset, int length) {
  for (int i = 0; i < length; i++) {
    if (src[offset + i] == 0) break;
    dst[i] = src[offset + i];
  }
  return length;
}

void _writeU16(Uint8List buffer, int offset, int value) {
  if (offset < 0 || offset + 2 > buffer.length) {
    throw RangeError('Offset out of range: $offset');
  }
  buffer[offset] = value & 0xFF;
  buffer[offset + 1] = (value >> 8) & 0xFF;
}

void _writeU32(Uint8List buffer, int offset, int value) {
  buffer[offset] = value & 0xFF;
  buffer[offset + 1] = (value >> 8) & 0xFF;
  buffer[offset + 2] = (value >> 16) & 0xFF;
  buffer[offset + 3] = (value >> 24) & 0xFF;
}

void _writeU64(Uint8List buffer, int offset, int value) {
  if (offset < 0 || offset + 8 > buffer.length) {
    throw RangeError('Offset out of range: $offset');
  }
  buffer[offset] = value & 0xFF;
  buffer[offset + 1] = (value >> 8) & 0xFF;
  buffer[offset + 2] = (value >> 16) & 0xFF;
  buffer[offset + 3] = (value >> 24) & 0xFF;
  buffer[offset + 4] = (value >> 32) & 0xFF;
  buffer[offset + 5] = (value >> 40) & 0xFF;
  buffer[offset + 6] = (value >> 48) & 0xFF;
  buffer[offset + 7] = (value >> 56) & 0xFF;
}

void _writeString(Uint8List buffer, int offset, String value, int length) {
  List<int> bytes = value.codeUnits;
  for (int i = 0; i < length; i++) {
    buffer[offset + i] = i < bytes.length ? bytes[i] : 0;
  }
}

//=================================================================================================
// typedef struct _DEVICE_INFO { ... } DEVICE_INFO
//-------------------------------------------------------------------------------------------------
// 10 + 4 + 30 + 10 + 10 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 = 96 bytes, padding 때문에 100 bytes
// /Device Spec/Device Info (100)
//const int deviceInfoSize = 100;

// final class DeviceInfo extends Struct {
//   @Array(10) // Fixed-size array of 10 bytes
//   external Array<Uint8> strDataFileVer;
//   @Int32()
//   external int nInvModelNo;
//   @Array(30) // Fixed-size array of 30 bytes
//   external Array<Uint8> strInvModelName;
//   @Array(10) // Fixed-size array of 10 bytes
//   external Array<Uint8> strInvSWVer;
//   @Array(10) // Fixed-size array of 10 bytes
//   external Array<Uint8> strInvCodeVer;

//   @Int32()
//   external int nCommOffset;
//   @Int32()
//   external int nTotalDiagNum;
//   @Int32() // 모델번호 가져오기 주소
//   external int nModelNoCommAddr;
//   @Int32() // Code Version 가져오기 주소
//   external int nCodeVerCommAddr;
//   @Int32() // Moter Status 가져오기 주소
//   external int nMotorStatusCommAddr;
//   @Int32() //인버터 상태 가져오기 주소
//   external int nInvStatusCommAddr;
//   @Int32()
//   external int nInvControlCommAddr;
//   @Int32()
//   external int nParameterSaveCommAddr;

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
  // Diag Number list
  List<int> diagNumberList = [];
  //-----------------------------------------------------------------------------------------------
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // DeviceInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    if (buffer.isNotEmpty) {
      int offset = 0;
      //final byteData = buffer.buffer.asByteData();

      // strDataFileVer (10 bytes)
      strDataFileVer = _readString(buffer, offset, dmdfSmallSize);
      //_readArray(strDataFileVer, buffer, offset, dmdfSmallSize);
      offset += dmdfSmallSize;
      offset += 2; // because padding

      // nInvModelNo (4 bytes)
      // final nInvModelNo = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
      nInvModelNo = _readU32(buffer, offset);
      offset += 4;

      // strInvModelName (30 bytes)
      strInvModelName = _readString(buffer, offset, dmdfTitleSize);
      offset += dmdfTitleSize;
      offset += 2; // because padding

      // strInvSWVer (10 bytes)
      strInvSWVer = _readString(buffer, offset, dmdfSmallSize);
      offset += dmdfSmallSize;

      // strInvCodeVer (10 bytes)
      strInvCodeVer = _readString(buffer, offset, dmdfSmallSize);
      offset += dmdfSmallSize;

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
        Stream stream = Stream(storage, diagNumberPath);
        final temp = Uint8List(diagNumberSize); // 4:sizeof(int)
        for (int i = 0; i < count; i++) {
          if (await stream.read(temp, diagNumberSize) > 0) {
            diagNumberList.add(_readU32(temp, 0));
          }
        }
      }
    }

    print('PATH: $path');
    print(' - strDataFileVer: $strDataFileVer');
    print(' - nInvModelNo: $nInvModelNo');
    print(' - strInvModelName: $strInvModelName');
    print(' - strInvSWVer: $strInvSWVer');
    print(' - strInvCodeVer: $strInvCodeVer');
    print(' - nCommOffset: $nCommOffset');
    print(' - nTotalDiagNum: $nTotalDiagNum');
    print('   - diagNumber: $diagNumberList');
    print(' - nModelNoCommAddr: $nModelNoCommAddr');
    print(' - nCodeVerCommAddr: $nCodeVerCommAddr');
    print(' - nMotorStatusCommAddr: $nMotorStatusCommAddr');
    print(' - nInvStatusCommAddr: $nInvStatusCommAddr');
    print(' - nInvControlCommAddr: $nInvControlCommAddr');
    print(' - nParameterSaveCommAddr: $nParameterSaveCommAddr');

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
      'diagNumber': diagNumberList,
    };
  }
}

//=================================================================================================
// typedef struct _IO_INFO { ... } IO_INFO
//-------------------------------------------------------------------------------------------------
// 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 = 32 bytes
// /IO Spec/IO Info  (32)
//const int ioInfoSize = 32;

// final class IoInfo extends Struct {
//   @Int32()
//   external int nTotalInput;
//   @Int32()
//   external int nNormalInput;
//   @Int32()
//   external int nTotalInputFuncTitle;
//   @Int32()
//   external int nTotalOutput;
//   @Int32()
//   external int nNormalOutput;
//   @Int32()
//   external int nTotalOutputFuncTitle;

//   @Int32() //입력 단자 상태 정보 통신주소
//   external int nAddInputStatus;
//   @Int32() //출력 단자 상태 정보 동신주소
//   external int nAddOutputStatus;

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
  List<Map<String, dynamic>> inputTerminalInfoList = [];
  List<Map<String, dynamic>> outputTerminalInfoList = [];
  //-----------------------------------------------------------------------------------------------
  // IO Func Msg Title
  List<String> inputFuncMsgTitleList = [];
  List<String> outputFuncMsgTitleList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // IoInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    int offset = 0;
    //final byteData = buffer.buffer.asByteData();

    int readInt32() {
      //final value = byteData.getInt32(offset, Endian.little);
      final value = _readU32(buffer, offset);
      offset += 4;
      return value;
    }

    inputTerminalInfoList.clear();
    outputTerminalInfoList.clear();
    inputFuncMsgTitleList.clear();
    outputFuncMsgTitleList.clear();

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
        Stream stream = Stream(storage, terminalInfoPath);
        if (!stream.fail()) {
          final temp = Uint8List(terminalInfoSize); // 36
          for (int i = 0; i < nTotalInput; i++) {
            if (await stream.read(temp, terminalInfoSize) > 0) {
              Map<String, dynamic> map = {
                'strName': _readString(temp, 0, 30),
                'nCommAddr': _readU32(temp, 32)
              };
              inputTerminalInfoList.add(map);
            }
          }
          for (int i = 0; i < nTotalOutput; i++) {
            if (await stream.read(temp, terminalInfoSize) > 0) {
              Map<String, dynamic> map = {
                'strName': _readString(temp, 0, 30),
                'nCommAddr': _readU32(temp, 32)
              };
              outputTerminalInfoList.add(map);
            }
          }
        }
      }

      count = nTotalInputFuncTitle + nTotalOutputFuncTitle;
      if (count > 0) {
        Stream stream = Stream(storage, funcMsgTitlePath);
        if (!stream.fail()) {
          final temp = Uint8List(funcMsgTitleSize); // 30
          for (int i = 0; i < nTotalInputFuncTitle; i++) {
            if (await stream.read(temp, funcMsgTitleSize) > 0) {
              inputFuncMsgTitleList.add(_readString(temp, 0, funcMsgTitleSize));
            }
          }
          for (int i = 0; i < nTotalOutputFuncTitle; i++) {
            if (await stream.read(temp, funcMsgTitleSize) > 0) {
              outputFuncMsgTitleList
                  .add(_readString(temp, 0, funcMsgTitleSize));
            }
          }
        }
      }
    }

    print('PATH: $path');
    print(' - nTotalInput: $nTotalInput');
    print(' - nNormalInput: $nNormalInput');
    print(' - nTotalInputFuncTitle: $nTotalInputFuncTitle');
    print(' - nTotalOutput: $nTotalOutput');
    print(' - nNormalOutput: $nNormalOutput');
    print(' - nTotalOutputFuncTitle: $nTotalOutputFuncTitle');
    print(' - nAddInputStatus: $nAddInputStatus');
    print(' - nAddOutputStatus: $nAddOutputStatus');
    print('   - inputTerminalInfoList: $inputTerminalInfoList');
    print('   - outputTerminalInfoList: $outputTerminalInfoList');
    print('   - inputFuncMsgTitleList: $inputFuncMsgTitleList');
    print('   - outputFuncMsgTitleList: $outputFuncMsgTitleList');

    return {
      'nTotalInput': nTotalInput,
      'nNormalInput': nNormalInput,
      'nTotalInputFuncTitle': nTotalInputFuncTitle,
      'nTotalOutput': nTotalOutput,
      'nNormalOutput': nNormalOutput,
      'nTotalOutputFuncTitle': nTotalOutputFuncTitle,
      'nAddInputStatus': nAddInputStatus,
      'nAddOutputStatus': nAddOutputStatus,
      'inputTerminalInfoList': inputTerminalInfoList,
      'outputTerminalInfoList': outputTerminalInfoList,
      'inputFuncMsgTitleList': inputFuncMsgTitleList,
      'outputFuncMsgTitleList': outputFuncMsgTitleList,
    };
  }
}

//=================================================================================================
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
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
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
        Stream stream = Stream(storage, tripNamePath);
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
        Stream stream = Stream(storage, commAddrPath);
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
        Stream stream = Stream(storage, tripInfoDataPath);
        if (!stream.fail()) {
          final temp = Uint8List(tripInfoDataSize); // 36
          for (int i = 0; i < nTotalTripInfo; i++) {
            if (await stream.read(temp, tripInfoDataSize) > 0) {
              Map<String, dynamic> map = {
                'nCommAddr': _readU32(temp, 0), // 4
                'strName': _readString(temp, 4, 30), // 30+2
                'nDataType': _readU32(temp, 36), // 4
                'nPointMsg': _readU32(temp, 40), // 4
                'strUnit': _readString(temp, 44, 10) // 10+2
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
                'strUnit': _readString(temp, 44, 10) // 10+2
              };
              warnInfoDataList.add(map);
            }
          }
        }
      }
    }

    print('PATH: $path');
    print(' - nTotalTripName: $nTotalTripName');
    print(' - nFirstTripNameAddr: $nFirstTripNameAddr');
    print(' - nCurTotalTrip: $nCurTotalTrip');
    print(' - nTotalTripInfo: $nTotalTripInfo');
    print(' - nTotalWarnName: $nTotalWarnName');
    print(' - nFirstWarnNameAddr: $nFirstWarnNameAddr');
    print(' - nCurTotalWarn: $nCurTotalWarn');
    print(' - nTotalWarnInfo: $nTotalWarnInfo');
    print('   - tripNameList: $tripNameList');
    print('   - warnNameList: $warnNameList');
    print('   - tripAddrList: $tripAddrList');
    print('   - warnAddrList: $warnAddrList');
    print('   - tripInfoDataList: $tripInfoDataList');
    print('   - warnInfoDataList: $warnInfoDataList');

    return {
      'nTotalTripName': nTotalTripName,
      'nFirstTripNameAddr': nFirstTripNameAddr,
      'nCurTotalTrip': nCurTotalTrip,
      'nTotalTripInfo': nTotalTripInfo,
      'nTotalWarnName': nTotalWarnName,
      'nFirstWarnNameAddr': nFirstWarnNameAddr,
      'nCurTotalWarn': nCurTotalWarn,
      'nTotalWarnInfo': nTotalWarnInfo,
      'tripNameList': tripNameList,
      'warnNameList': warnNameList,
      'tripAddrList': tripAddrList,
      'warnAddrList': warnAddrList,
      'tripInfoDataList': tripInfoDataList,
      'warnInfoDataList': warnInfoDataList,
    };
  }
}

//=================================================================================================
class MsgSpec {
  int nTotalMsg = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> msgInfoList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    nTotalMsg = 0;
    msgInfoList.clear();

    if (buffer.isNotEmpty) {
      nTotalMsg = _readU32(buffer, 0);
      if (nTotalMsg > 0) {
        Stream msgTitleNumStream = Stream(storage, msgTitleNumPath);
        Stream msgTitleStream = Stream(storage, msgTitlePath);

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
                'pTitle': msgTitleList
              };
              msgInfoList.add(map);
            }
          }
        }
      }
    }

    print('PATH: $path');
    print(' - nTotalMsg: $nTotalMsg');
    print(' - pMsgInfo: $msgInfoList');

    return {
      'nTotalMsg': nTotalMsg,
      'pMsgInfo': msgInfoList,
    };
  }
}

//=================================================================================================
class CommonSpec {
  int nTotCommonNo = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> commonInfoList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    commonInfoList.clear();
    nTotCommonNo = 0;

    if (buffer.isNotEmpty) {
      nTotCommonNo = _readU32(buffer, 0);
      if (nTotCommonNo > 0) {
        Stream stream = Stream(storage, commonInfoPath);
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
              'nAttribute': _readU32(temp, 68)
            };
            commonInfoList.add(map);
          }
        }
      }
    }

    print('PATH: $path');
    print(' - nTotCommonNo: $nTotCommonNo');
    print(' - pCommonInfo: $commonInfoList');

    return {
      'nTotCommonNo': nTotCommonNo,
      'pCommonInfo': commonInfoList,
    };
  }
}

//=================================================================================================
class ParameterSpec {
  int nTotGroup = 0;
  //-----------------------------------------------------------------------------------------------
  List<Map<String, dynamic>> parmGrpList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    return {};
  }
}

// const String defPathTotalInitOrder = "/Init Order/Total Init Order";
// const String defPathInitOrderParaAddr = "/Init Order/Init Order Para Addr";

//=================================================================================================
class InitOrder {
  int nTotInitOder = 0;
  //-----------------------------------------------------------------------------------------------
  List<int> orderAddrList = [];
  //-----------------------------------------------------------------------------------------------
  //int steamSize = 0;
  Storage storage;
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
      Stream stream = Stream(storage, path);
      //steamSize = stream.size();
      // 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(size);
      await stream.read(buffer, size);
      return parseData(buffer);
    } catch (e) {
      //steamSize = 0;
      return {
        'error': e.toString(),
      };
    }
  }

  // 바이트 배열을 파싱하는 헬퍼 메서드
  Future<Map<String, dynamic>> parseData(Uint8List buffer) async {
    orderAddrList.clear();
    nTotInitOder = 0;

    if (buffer.isNotEmpty) {
      nTotInitOder = _readU32(buffer, 0);
      if (nTotInitOder > 0) {
        Stream stream = Stream(storage, initOrderParaAddrPath);
        final temp = Uint8List(initOrderParaAddrSize);
        for (int i = 0; i < nTotInitOder; i++) {
          if (await stream.read(temp, initOrderParaAddrSize) > 0) {
            orderAddrList.add(_readU32(temp, 0));
          }
        }
      }
    }

    print('PATH: $path');
    print(' - nTotInitOder: $nTotInitOder');

    return {
      'nTotInitOder': nTotInitOder,
      'pOrderAddr': orderAddrList,
    };
  }
}

//=================================================================================================
