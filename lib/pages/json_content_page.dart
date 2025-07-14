import 'dart:io';
import 'package:flutter/material.dart';
import 'device_inv.dart';
import 'file_content_page.dart';

class JsonContentPage extends StatefulWidget {
  final String filePath;
  const JsonContentPage({super.key, required this.filePath});

  @override
  State<JsonContentPage> createState() => _JsonContentPageState();
}

class _JsonContentPageState extends State<JsonContentPage> {
  Map<String, dynamic>? parsedData;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _parseSpecJson();
  }

  Future<void> _parseSpecJson() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final specFromJson = SpecFromJson();
      bool loaded = false;
      if (Platform.isWindows) {
        loaded = await specFromJson.load(widget.filePath, isAssets: false);
      } else {
        loaded = await specFromJson.loadAssets(widget.filePath);
      }

      if (!loaded) {
        setState(() {
          error = 'SpecFromJson 파싱 실패';
          loading = false;
        });
        return;
      }
      // 주요 Spec 객체 생성 및 파싱
      final deviceSpec = DeviceSpec(null);
      final ioSpec = IoSpec(null);
      final tripSpec = TripSpec(null);
      final msgSpec = MsgSpec(null);
      final commonSpec = CommonSpec(null);
      final parameterSpec = ParameterSpec(null);
      final initOrder = InitOrder(null);

      final data = <String, dynamic>{
        'deviceSpec': specFromJson.deviceSpec(deviceSpec),
        'ioSpec': specFromJson.ioSpec(ioSpec, null),
        'tripSpec': specFromJson.tripSpec(tripSpec, null),
        'msgSpec': specFromJson.messageSpec(msgSpec),
        'commonSpec': specFromJson.commonSpec(commonSpec),
        'parameterSpec': specFromJson.parameterSpec(parameterSpec),
        'initOrder': specFromJson.initOrder(initOrder),
      };
      setState(() {
        parsedData = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'SpecFromJson 파싱 중 오류 발생: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.filePath.split(Platform.pathSeparator).last),
      //   actions: [
      //     if (parsedData != null)
      //       IconButton(
      //         icon: const Icon(Icons.table_chart),
      //         tooltip: '표 형태로 보기',
      //         onPressed: () {},
      //       ),
      //   ],
      // ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : parsedData != null
                  ? INVDataTablePage(
                      invData: parsedData!, fileName: widget.filePath)
                  : const Center(child: Text('데이터 없음')),
    );
  }
}
