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
      //List<String> result = await readTripSpec(storage);
      //List<String> result = await readMsgSpec(storage);
      //List<String> result = await readCommonSpec(storage);
      //List<String> result = await readParameterSpec(storage);
      //List<String> result = await readInitOrder(storage);

      List<String> result = await readINV(storage);

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

  Future<List<String>> readINV(Storage storage) async {
    List<String> result = [];

    final resDeviceSpec = await readDeviceSpec(storage);
    result.addAll(resDeviceSpec);

    final resIoSpec = await readIoSpec(storage);
    result.addAll(resIoSpec);

    final resTripSpec = await readTripSpec(storage);
    result.addAll(resTripSpec);

    final resMsgSpec = await readMsgSpec(storage);
    result.addAll(resMsgSpec);

    final resCommonSpec = await readCommonSpec(storage);
    result.addAll(resCommonSpec);

    final resParameterSpec = await readParameterSpec(storage);
    result.addAll(resParameterSpec);

    final resInitOrder = await readInitOrder(storage);
    result.addAll(resInitOrder);

    return result;
  }

  Future<List<String>> readDeviceSpec(Storage storage) async {
    List<String> result = [];

    DeviceSpec spec = DeviceSpec(storage);
    final res = await spec.parse();

    result.add('Parsed DeviceSpec:');
    result.add('  strDataFileVer: ${res['strDataFileVer']}');
    result.add('  nInvModelNo: ${res['nInvModelNo']}');
    result.add('  strInvModelName: ${res['strInvModelName']}');
    result.add('  strInvSWVer: ${res['strInvSWVer']}');
    result.add('  strInvCodeVer: ${res['strInvCodeVer']}');
    result.add('  nCommOffset: ${res['nCommOffset']}');
    result.add('  nTotalDiagNum: ${res['nTotalDiagNum']}');
    result.add('  nModelNoCommAddr: ${res['nModelNoCommAddr']}');
    result.add('  nCodeVerCommAddr: ${res['nCodeVerCommAddr']}');
    result.add('  nMotorStatusCommAddr: ${res['nMotorStatusCommAddr']}');
    result.add('  nInvStatusCommAddr: ${res['nInvStatusCommAddr']}');
    result.add('  nInvControlCommAddr: ${res['nInvControlCommAddr']}');
    result.add('  ParameterSaveCommAddr: ${res['nParameterSaveCommAddr']}');

    result.add('  pDiagNum: ${res['pDiagNum']}');
    if (spec.nTotalDiagNum > 0) {
      result.add('  pDiagNum: ${spec.diagNumList}');
    }

    return result;
  }

  Future<List<String>> readIoSpec(Storage storage) async {
    List<String> result = [];
    try {
      IoSpec spec = IoSpec(storage);
      final res = await spec.parse();

      result.add('Parsed IoSpec:');
      result.add('  nTotalInput: ${res['nTotalInput']}, ${spec.nTotalInput}');
      result.add('  nNormalInput: ${res['nNormalInput']}');
      result.add('  nTotalInputFuncTitle: ${res['nTotalInputFuncTitle']}');
      result.add('  nTotalOutput: ${res['nTotalOutput']}');
      result.add('  nNormalOutput: ${res['nNormalOutput']}');
      result.add('  nTotalOutputFuncTitle: ${res['nTotalOutputFuncTitle']}');
      result.add('  nAddInputStatus: ${res['nAddInputStatus']}');
      result.add('  nAddOutputStatus: ${res['nAddOutputStatus']}');

      result.add('  pInputTermInfo: ${res['pInputTermInfo']}');
      result.add('  pOutputTermInfo: ${res['pOutputTermInfo']}');

      result.add('  pInputFuncMsg: ${res['pOutputTermInfo']}');
      result.add('  pOutputFuncMsgTitle: ${res['pOutputFuncMsgTitle']}');
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

      result.add('  pTripName: ${res['pTripName']}');
      result.add('  pWarnName: ${res['pWarnName']}');

      result.add('  pTripAddr: ${res['pTripAddr']}');
      result.add('  pWarnAddr: ${res['pWarnAddr']}');

      result.add('  pTripInfoData: ${res['pTripInfoData']}');
      result.add('  pWarnInfoData: ${res['pWarnInfoData']}');
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

      result.add('Parsed readMsgSpec:');
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

      result.add('Parsed CommonSpec:');
      result
          .add('  nTotCommonNo: ${res['nTotCommonNo']}, ${spec.nTotCommonNo}');
      result.add('  pCommonInfo: ${res['pCommonInfo']}');
    } catch (e) {
      result.add('readIoInfo error: $e');
    }
    return result;
  }

  Future<List<String>> readParameterSpec(Storage storage) async {
    List<String> result = [];
    try {
      ParameterSpec spec = ParameterSpec(storage);
      final res = await spec.parse();

      result.add('Parsed ParameterSpec:');
      result.add('  nTotGroup: ${res['nTotGroup']}, ${spec.nTotGroup}');
      result.add('  pParmGrp: ${res['pParmGrp']}');
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

      result.add('Parsed InitOrder:');
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
