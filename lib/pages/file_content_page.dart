import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

import 'pole.dart';
import 'device_inv.dart';

class FileContentPage extends StatefulWidget {
  final String fileName;
  const FileContentPage({super.key, required this.fileName});

  @override
  State<FileContentPage> createState() => _FileContentPageState();
}

class _FileContentPageState extends State<FileContentPage> {
  List<String> entries = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      Storage storage = Storage(fileName: widget.fileName);
      bool res = await storage.open();
      if (!res) throw Exception('Storage open failed');
      //List<String> result = await _visit(0, storage, '/');
      //List<String> result = await readDeviceSpec(storage);
      //List<String> result = await readIoSpec(storage);
      List<String> result = await readTripSpec(storage);
      //List<String> result = await readMsgSpec(storage);
      //List<String> result = await readCommonSpec(storage);

      //List<String> result = await readInitOrder(storage);

      setState(() {
        entries = result;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<List<String>> _visit(int indent, Storage storage, String path) async {
    List<String> result = [];
    List<String> ents = await storage.entries(path);

    result.add('Visit: $path (${ents.length} entries)');

    for (String name in ents) {
      String fullname = path + name;
      try {
        Stream? stream = Stream(storage, fullname);
        result.add('${'    ' * indent}$name   (${stream.size()})');
      } catch (e) {
        result.add('${'    ' * indent}$name');
      }
      if (await storage.isDirectory(fullname)) {
        List<String> subEntries =
            await _visit(indent + 1, storage, '$fullname/');
        result.addAll(subEntries);
      }
    }
    return result;
  }

  Future<List<String>> readDeviceSpec(Storage storage) async {
    List<String> result = [];

    DeviceSpec spec = DeviceSpec(storage);
    final res = await spec.parse();

    result.add('Parsed DeviceSpec:');
    result.add('  DataFileVer: ${res['strDataFileVer']}');
    result.add('  InvModelNo: ${res['nInvModelNo']}');
    result.add('  InvModelName: ${res['strInvModelName']}');
    result.add('  InvSWVer: ${res['strInvSWVer']}');
    result.add('  InvCodeVer: ${res['strInvCodeVer']}');
    result.add('  CommOffset: ${res['nCommOffset']}');
    result.add('  TotalDiagNum: ${res['nTotalDiagNum']}');
    result.add('  ModelNoCommAddr: ${res['nModelNoCommAddr']}');
    result.add('  CodeVerCommAddr: ${res['nCodeVerCommAddr']}');
    result.add('  MotorStatusCommAddr: ${res['nMotorStatusCommAddr']}');
    result.add('  InvStatusCommAddr: ${res['nInvStatusCommAddr']}');
    result.add('  InvControlCommAddr: ${res['nInvControlCommAddr']}');
    result.add('  ParameterSaveCommAddr: ${res['nParameterSaveCommAddr']}');

    result.add('  diagNumber: ${res['diagNumber']}');
    if (spec.nTotalDiagNum > 0) {
      result.add('  diagNumber: ${spec.diagNumberList}');
    }

    return result;
  }

  Future<List<String>> readIoSpec(Storage storage) async {
    List<String> result = [];
    try {
      IoSpec spec = IoSpec(storage);
      final res = await spec.parse();

      result.add('Parsed IoSpec:');
      result.add('  TotalInput: ${res['nTotalInput']}, ${spec.nTotalInput}');
      result.add('  NormalInput: ${res['nNormalInput']}');
      result.add('  TotalInputFuncTitle: ${res['nTotalInputFuncTitle']}');
      result.add('  TotalOutput: ${res['nTotalOutput']}');
      result.add('  NormalOutput: ${res['nNormalOutput']}');
      result.add('  TotalOutputFuncTitle: ${res['nTotalOutputFuncTitle']}');
      result.add('  AddInputStatus: ${res['nAddInputStatus']}');
      result.add('  AddOutputStatus: ${res['nAddOutputStatus']}');

      result.add('  inputTerminalInfoList: ${res['inputTerminalInfoList']}');
      result.add('  outputTerminalInfoList: ${res['outputTerminalInfoList']}');

      result.add('  inputFuncMsgTitleList: ${res['inputFuncMsgTitleList']}');
      result.add('  outputFuncMsgTitleList: ${res['outputFuncMsgTitleList']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  Future<List<String>> readTripSpec(Storage storage) async {
    List<String> result = [];
    try {
      TripSpec spec = TripSpec(storage);
      final res = await spec.parse();

      result.add('Parsed TripSpec:');
      result.add(
          '  nTotalTripName: ${res['nTotalTripName']}, ${spec.nTotalTripName}');
      result.add('  nFirstTripNameAddr: ${res['nFirstTripNameAddr']}');
      result.add('  nCurTotalTrip: ${res['nCurTotalTrip']}');
      result.add('  nTotalTripInfo: ${res['nTotalTripInfo']}');
      result.add('  nTotalWarnName: ${res['nTotalWarnName']}');
      result.add('  nFirstWarnNameAddr: ${res['nFirstWarnNameAddr']}');
      result.add('  nCurTotalWarn: ${res['nCurTotalWarn']}');
      result.add('  nTotalWarnInfo: ${res['nTotalWarnInfo']}');

      result.add('  tripNameList: ${res['tripNameList']}');
      result.add('  warnNameList: ${res['warnNameList']}');

      result.add('  tripAddrList: ${res['tripAddrList']}');
      result.add('  warnAddrList: ${res['warnAddrList']}');

      result.add('  tripInfoDataList: ${res['tripInfoDataList']}');
      result.add('  warnInfoDataList: ${res['warnInfoDataList']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  Future<List<String>> readMsgSpec(Storage storage) async {
    List<String> result = [];
    try {
      MsgSpec spec = MsgSpec(storage);
      final res = await spec.parse();

      result.add('Parsed TripSpec:');
      result.add('  nTotalMsg: ${res['nTotalMsg']}, ${spec.nTotalMsg}');
      result.add('  pMsgInfo: ${res['pMsgInfo']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  Future<List<String>> readCommonSpec(Storage storage) async {
    List<String> result = [];
    try {
      CommonSpec spec = CommonSpec(storage);
      final res = await spec.parse();

      result.add('Parsed TripSpec:');
      result
          .add('  nTotCommonNo: ${res['nTotCommonNo']}, ${spec.nTotCommonNo}');
      result.add('  pCommonInfo: ${res['pCommonInfo']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  Future<List<String>> readInitOrder(Storage storage) async {
    List<String> result = [];
    try {
      InitOrder spec = InitOrder(storage);
      final res = await spec.parse();

      result.add('Parsed TripSpec:');
      result
          .add('  nTotInitOder: ${res['nTotInitOder']}, ${spec.nTotInitOder}');
      result.add('  pOrderAddr: ${res['pOrderAddr']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName.split(Platform.pathSeparator).last),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('오류: $error'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(entries[index]),
                    );
                  },
                ),
    );
  }
}
