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
      //List<String> result = await readDeviceInfo(storage);
      List<String> result = await readIoInfo(storage);
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

  Future<List<String>> readDeviceInfo(Storage storage) async {
    List<String> result = [];

    try {
      Stream? stream = Stream(storage, defPathDeviceInfo);
      result.add(
          'readDeviceInfo: $defPathDeviceInfo (${stream?.size() ?? 0} bytes)');

      // DeviceInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(deviceInfoSize);
      int res = await stream?.read(buffer, deviceInfoSize) ?? 0;

      result.add(
          'DeviceInfo read successfully: res: $res, ${buffer.length} bytes');

      // 바이트 배열을 DeviceInfo 구조체로 파싱
      final deviceInfo = DeviceInfo.parse(buffer);
      result.add('Parsed DeviceInfo:');
      result.add('  DataFileVer: ${deviceInfo['strDataFileVer']}');
      result.add('  InvModelNo: ${deviceInfo['nInvModelNo']}');
      result.add('  InvModelName: ${deviceInfo['strInvModelName']}');
      result.add('  InvSWVer: ${deviceInfo['strInvSWVer']}');
      result.add('  InvCodeVer: ${deviceInfo['strInvCodeVer']}');
      result.add('  CommOffset: ${deviceInfo['nCommOffset']}');
      result.add('  TotalDiagNum: ${deviceInfo['nTotalDiagNum']}');

      result.add('  ModelNoCommAddr: ${deviceInfo['nModelNoCommAddr']}');
      result.add('  CodeVerCommAddr: ${deviceInfo['nCodeVerCommAddr']}');
      result
          .add('  MotorStatusCommAddr: ${deviceInfo['nMotorStatusCommAddr']}');
      result.add('  InvStatusCommAddr: ${deviceInfo['nInvStatusCommAddr']}');
      result.add('  InvControlCommAddr: ${deviceInfo['nInvControlCommAddr']}');
      result.add(
          '  ParameterSaveCommAddr: ${deviceInfo['nParameterSaveCommAddr']}');
    } catch (e) {
      result.add('readDeviceInfo error: $e');
    }

    return result;
  }

  Future<List<String>> readIoInfo(Storage storage) async {
    List<String> result = [];
    try {
      Stream? stream = Stream(storage, defPathIoInfo);
      result.add('readIoInfo: $defPathIoInfo (${stream?.size() ?? 0} bytes)');

      // IoInfo 구조체 크기만큼 바이트 배열로 읽기
      final buffer = Uint8List(ioInfoSize);
      await stream?.read(buffer, ioInfoSize);

      result.add('IoInfo read successfully: ${buffer.length} bytes');

      // 바이트 배열을 DeviceInfo 구조체로 파싱
      final ioInfo = IoInfo.parse(buffer);
      result.add('Parsed IoInfo:');
      result.add('  TotalInput: ${ioInfo['nTotalInput']}');
      result.add('  NormalInput: ${ioInfo['nNormalInput']}');
      result.add('  TotalInputFuncTitle: ${ioInfo['nTotalInputFuncTitle']}');
      result.add('  TotalOutput: ${ioInfo['nTotalOutput']}');
      result.add('  NormalOutput: ${ioInfo['nNormalOutput']}');
      result.add('  TotalOutputFuncTitle: ${ioInfo['nTotalOutputFuncTitle']}');
      result.add('  AddInputStatus: ${ioInfo['nAddInputStatus']}');
      result.add('  AddOutputStatus: ${ioInfo['nAddOutputStatus']}');
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
