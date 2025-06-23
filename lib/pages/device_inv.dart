import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

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

void _writeU16(Uint8List buffer, int offset, int value) {
  if (offset < 0 || offset + 2 > buffer.length) {
    throw RangeError('Offset out of range: $offset');
  }
  buffer[offset] = value & 0xFF;
  buffer[offset + 1] = (value >> 8) & 0xFF;
}

int _readU32(Uint8List buffer, int offset) {
  return buffer[offset] |
      (buffer[offset + 1] << 8) |
      (buffer[offset + 2] << 16) |
      (buffer[offset + 3] << 24);
}

void _writeU32(Uint8List buffer, int offset, int value) {
  buffer[offset] = value & 0xFF;
  buffer[offset + 1] = (value >> 8) & 0xFF;
  buffer[offset + 2] = (value >> 16) & 0xFF;
  buffer[offset + 3] = (value >> 24) & 0xFF;
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

String _readString(Uint8List buffer, int offset, int length) {
  List<int> bytes = [];
  for (int i = 0; i < length; i++) {
    if (buffer[offset + i] == 0) break;
    bytes.add(buffer[offset + i]);
  }
  return String.fromCharCodes(bytes);
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
// 10 + 4 + 30 + 10 + 10 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 = 96 bytes
// /Device Spec/Device Info (100)
const int deviceInfoSize = 100; //96;

class DeviceInfo {
//final class DeviceInfo extends Struct {
  // @Array(10) // Fixed-size array of 10 bytes
  // external Array<Uint8> strDataFileVer;
  // @Int32()
  // external int nInvModelNo;
  // @Array(30) // Fixed-size array of 30 bytes
  // external Array<Uint8> strInvModelName;
  // @Array(10) // Fixed-size array of 10 bytes
  // external Array<Uint8> strInvSWVer;
  // @Array(10) // Fixed-size array of 10 bytes
  // external Array<Uint8> strInvCodeVer;

  // @Int32()
  // external int nCommOffset;
  // @Int32()
  // external int nTotalDiagNum;
  // @Int32() // 모델번호 가져오기 주소
  // external int nModelNoCommAddr;
  // @Int32() // Code Version 가져오기 주소
  // external int nCodeVerCommAddr;
  // @Int32() // Moter Status 가져오기 주소
  // external int nMotorStatusCommAddr;
  // @Int32() //인버터 상태 가져오기 주소
  // external int nInvStatusCommAddr;
  // @Int32()
  // external int nInvControlCommAddr;
  // @Int32()
  // external int nParameterSaveCommAddr;

  DeviceInfo() {
    // 문자열 배열 초기화 - Array<Uint8>는 외부에서 초기화됨
    // strDataFileVer, strInvModelName, strInvSWVer, strInvCodeVer는
    // Struct의 external 필드이므로 생성자에서 직접 초기화할 수 없음

    // 정수 변수 초기화
    // nInvModelNo = 0;
    // nCommOffset = 0;
    // nTotalDiagNum = 0;
    // nModelNoCommAddr = 0;
    // nCodeVerCommAddr = 0;
    // nMotorStatusCommAddr = 0;
    // nInvStatusCommAddr = 0;
    // nInvControlCommAddr = 0;
    // nParameterSaveCommAddr = 0;
  }
  // 바이트 배열을 DeviceInfo로 파싱하는 헬퍼 메서드
  static Map<String, dynamic> parse(Uint8List buffer) {
    int offset = 0;

    // strDataFileVer (10 bytes)
    final strDataFileVer = _readString(buffer, offset, dmdfSmallSize);
    print('DeviceInfo::parse() - strDataFileVer: $strDataFileVer');
    offset += dmdfSmallSize;
    offset += 2;

    // nInvModelNo (4 bytes)
    // final nInvModelNo = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nInvModelNo = _readU32(buffer, offset);
    print('DeviceInfo::parse() - nInvModelNo: $nInvModelNo');
    offset += 4;
    //offset += 2;

    // strInvModelName (30 bytes)
    final strInvModelName = _readString(buffer, offset, dmdfTitleSize);
    offset += dmdfTitleSize;
    offset += 2;

    // strInvSWVer (10 bytes)
    final strInvSWVer = _readString(buffer, offset, dmdfSmallSize);
    offset += dmdfSmallSize;

    // strInvCodeVer (10 bytes)
    final strInvCodeVer = _readString(buffer, offset, dmdfSmallSize);
    offset += dmdfSmallSize;
    //offset += 2;

    // 나머지 정수 필드들 (각각 4 bytes)
    // final nCommOffset = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nCommOffset = _readU32(buffer, offset);
    offset += 4;
    // final nTotalDiagNum = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nTotalDiagNum = _readU32(buffer, offset);
    offset += 4;
    // final nModelNoCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nModelNoCommAddr = _readU32(buffer, offset);
    offset += 4;
    // final nCodeVerCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nCodeVerCommAddr = _readU32(buffer, offset);
    offset += 4;
    // final nMotorStatusCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nMotorStatusCommAddr = _readU32(buffer, offset);
    offset += 4;
    // final nInvStatusCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nInvStatusCommAddr = _readU32(buffer, offset);
    offset += 4;
    // final nInvControlCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nInvControlCommAddr = _readU32(buffer, offset);
    offset += 4;
    // final nParameterSaveCommAddr = buffer.buffer.asByteData(offset, 4).getInt32(0, Endian.little);
    final nParameterSaveCommAddr = _readU32(buffer, offset);

    print('DeviceInfo::parse() - strInvModelName: $strInvModelName');
    print('DeviceInfo::parse() - strInvSWVer: $strInvSWVer');
    print('DeviceInfo::parse() - strInvCodeVer: $strInvCodeVer');
    print('DeviceInfo::parse() - nCommOffset: $nCommOffset');
    print('DeviceInfo::parse() - nTotalDiagNum: $nTotalDiagNum');
    print('DeviceInfo::parse() - nModelNoCommAddr: $nModelNoCommAddr');
    print('DeviceInfo::parse() - nCodeVerCommAddr: $nCodeVerCommAddr');
    print('DeviceInfo::parse() - nMotorStatusCommAddr: $nMotorStatusCommAddr');
    print('DeviceInfo::parse() - nInvStatusCommAddr: $nInvStatusCommAddr');
    print('DeviceInfo::parse() - nInvControlCommAddr: $nInvControlCommAddr');
    print(
        'DeviceInfo::parse() - nParameterSaveCommAddr: $nParameterSaveCommAddr');

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
    };
  }
}

//=================================================================================================
// typedef struct _DEVICE_INFO { ... } DEVICE_INFO
//-------------------------------------------------------------------------------------------------
// 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 = 32 bytes
const int ioInfoSize = 32;

final class IoInfo extends Struct {
  @Int32()
  external int nTotalInput;
  @Int32()
  external int nNormalInput;
  @Int32()
  external int nTotalInputFuncTitle;
  @Int32()
  external int nTotalOutput;
  @Int32()
  external int nNormalOutput;
  @Int32()
  external int nTotalOutputFuncTitle;

  @Int32() //입력 단자 상태 정보 통신주소
  external int nAddInputStatus;
  @Int32() //출력 단자 상태 정보 동신주소
  external int nAddOutputStatus;

  IoInfo() {
    nTotalInput = 0;
    nNormalInput = 0;
    nTotalInputFuncTitle = 0;
    nTotalOutput = 0;
    nNormalOutput = 0;
    nTotalOutputFuncTitle = 0;
    nAddInputStatus = 0;
    nAddOutputStatus = 0;
  }

  static Map<String, dynamic> parse(Uint8List buffer) {
    int offset = 0;
    final byteData = buffer.buffer.asByteData();

    int readInt32() {
      //final value = byteData.getInt32(offset, Endian.little);
      final value = _readU32(buffer, offset);
      offset += 4;
      return value;
    }

    final nTotalInput = readInt32();
    print('IoInfo::parse() - nTotalInput: $nTotalInput');
    final nNormalInput = readInt32();
    print('IoInfo::parse() - nNormalInput: $nNormalInput');
    final nTotalInputFuncTitle = readInt32();
    print('IoInfo::parse() - nTotalInputFuncTitle: $nTotalInputFuncTitle');
    final nTotalOutput = readInt32();
    print('IoInfo::parse() - nTotalOutput: $nTotalOutput');
    final nNormalOutput = readInt32();
    print('IoInfo::parse() - nNormalOutput: $nNormalOutput');
    final nTotalOutputFuncTitle = readInt32();
    print('IoInfo::parse() - nTotalOutputFuncTitle: $nTotalOutputFuncTitle');
    final nAddInputStatus = readInt32();
    print('IoInfo::parse() - nAddInputStatus: $nAddInputStatus');
    final nAddOutputStatus = readInt32();
    print('IoInfo::parse() - nAddOutputStatus: $nAddOutputStatus');

    return {
      'nTotalInput': nTotalInput,
      'nNormalInput': nNormalInput,
      'nTotalInputFuncTitle': nTotalInputFuncTitle,
      'nTotalOutput': nTotalOutput,
      'nNormalOutput': nNormalOutput,
      'nTotalOutputFuncTitle': nTotalOutputFuncTitle,
      'nAddInputStatus': nAddInputStatus,
      'nAddOutputStatus': nAddOutputStatus,
    };
  }
}
