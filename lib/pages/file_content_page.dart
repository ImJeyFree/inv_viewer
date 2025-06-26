import 'package:flutter/material.dart';
import 'dart:io';

import 'pole.dart';
import 'device_inv.dart';

class FileContentPage extends StatefulWidget {
  final String fileName;
  final Storage? storage;
  const FileContentPage({super.key, required this.fileName, this.storage});

  @override
  State<FileContentPage> createState() => _FileContentPageState();
}

class _FileContentPageState extends State<FileContentPage> {
  List<String> entries = [];
  bool loading = true;
  String? error;
  Map<String, dynamic>? invData;

  @override
  void initState() {
    super.initState();
    // 파일명 없거나 확장자 .inv/.INV가 아니면 예외 처리
    if (widget.fileName.isEmpty ||
        !(widget.fileName.toLowerCase().endsWith('.inv'))) {
      setState(() {
        loading = false;
        error = '지원하지 않는 파일입니다: ${widget.fileName}';
      });
      return;
    }
    // print('FileContentPage::initState() - ');
    _loadFile();
  }

  Future<void> _loadFile() async {
    // print('FileContentPage::_loadFile() - ${widget.fileName}');
    try {
      setState(() {
        loading = true;
        error = null;
      });

      // print('FileContentPage::_loadFile() - storage create');
      Storage storage = widget.storage ?? Storage(fileName: widget.fileName);
      if (widget.storage == null) {
        bool res = await storage.open();
        // print('FileContentPage::_loadFile() - storage.open() end');
        if (!res) {
          print(
              'FileContentPage::_loadFile() - storage.open() : Storage open failed !!!');
          throw Exception('Storage open failed');
        } else {
          // print('FileContentPage::_loadFile() - storage.open() : success !!!');
        }
      }

      // INV 파일인지 확인
      if (widget.fileName.toLowerCase().endsWith('.inv')) {
        invData = await parseINVData(storage);
        entries = await readINV(storage);
      } else {
        entries = await _visit(0, storage, '');
      }

      setState(() {
        loading = false;
        //print('invData(setState): ' + invData.toString());
      });
      //print('최종 invData: ' + invData.toString());
    } catch (e) {
      // print('FileContentPage 파싱 에러: ' + e.toString());
      setState(() {
        loading = false;
        error = e.toString();
        print('invData(setState, error): ' + invData.toString());
      });
      // print('최종 invData(에러): ' + invData.toString());
    }
    // print('FileContentPage::_loadFile() - loading: $loading');
  }

  Future<Map<String, dynamic>> parseINVData(Storage storage) async {
    // print('FileContentPage::parseINVData() - ');

    Map<String, dynamic> result = {};

    try {
      DeviceSpec deviceSpec = DeviceSpec(storage);
      result['deviceSpec'] = await deviceSpec.parse();
    } catch (e) {
      result['deviceSpec'] = {'error': e.toString()};
    }

    try {
      IoSpec ioSpec = IoSpec(storage);
      result['ioSpec'] = await ioSpec.parse();
    } catch (e) {
      result['ioSpec'] = {'error': e.toString()};
    }

    try {
      TripSpec tripSpec = TripSpec(storage);
      result['tripSpec'] = await tripSpec.parse();
    } catch (e) {
      result['tripSpec'] = {'error': e.toString()};
    }

    try {
      MsgSpec msgSpec = MsgSpec(storage);
      result['msgSpec'] = await msgSpec.parse();
    } catch (e) {
      result['msgSpec'] = {'error': e.toString()};
    }

    try {
      CommonSpec commonSpec = CommonSpec(storage);
      result['commonSpec'] = await commonSpec.parse();
    } catch (e) {
      result['commonSpec'] = {'error': e.toString()};
    }

    try {
      ParameterSpec parameterSpec = ParameterSpec(storage);
      result['parameterSpec'] = await parameterSpec.parse();
    } catch (e) {
      result['parameterSpec'] = {'error': e.toString()};
    }

    try {
      InitOrder initOrder = InitOrder(storage);
      result['initOrder'] = await initOrder.parse();
    } catch (e) {
      result['initOrder'] = {'error': e.toString()};
    }

    return result;
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
    // print('FileContentPage::readINV() - ');

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
    // print('FileContentPage::readDeviceSpec() - ');

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
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                widget.fileName.split(Platform.pathSeparator).last,
                overflow: TextOverflow.ellipsis,
              ),
              if (invData != null) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => INVDataTablePage(
                            invData: invData!, fileName: widget.fileName),
                      ),
                    );
                  },
                  tooltip: '표 형태로 보기',
                ),
              ],
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('오류: $error'))
              : invData != null
                  ? INVDataViewPage()
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

  Widget INVDataViewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard('Device Spec', invData!['deviceSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('IO Spec', invData!['ioSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('Trip Spec', invData!['tripSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('Message Spec', invData!['msgSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('Common Spec', invData!['commonSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('Parameter Spec', invData!['parameterSpec']),
          const SizedBox(height: 16),
          _buildSectionCard('Init Order', invData!['initOrder']),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Map<String, dynamic> data) {
    return Card(
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDataTable(data),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(Map<String, dynamic> data) {
    List<DataRow> rows = [];

    data.forEach((key, value) {
      if (value is List) {
        if (value.isNotEmpty && value.first is Map) {
          // List<Map> 형태인 경우
          rows.add(DataRow(
            cells: [
              DataCell(Text(key)),
              DataCell(Text('${value.length}개 항목')),
            ],
          ));
          for (int i = 0; i < value.length; i++) {
            Map<String, dynamic> item = value[i];
            item.forEach((itemKey, itemValue) {
              rows.add(DataRow(
                cells: [
                  DataCell(Text('  $itemKey')),
                  DataCell(Text(itemValue.toString())),
                ],
              ));
            });
          }
        } else {
          // 일반 List인 경우
          rows.add(DataRow(
            cells: [
              DataCell(Text(key)),
              DataCell(Text(value.toString())),
            ],
          ));
        }
      } else {
        rows.add(DataRow(
          cells: [
            DataCell(Text(key)),
            DataCell(Text(value.toString())),
          ],
        ));
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('필드명')),
          DataColumn(label: Text('값')),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildDeviceSpecDetail() {
    final data = invData?['deviceSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Device Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Data File Version')),
              DataCell(Text(data['strDataFileVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Model No')),
              DataCell(Text(data['nInvModelNo']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Model Name')),
              DataCell(Text(data['strInvModelName'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('SW Version')),
              DataCell(Text(data['strInvSWVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Code Version')),
              DataCell(Text(data['strInvCodeVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Comm Offset')),
              DataCell(Text(data['nCommOffset']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Diag Num')),
              DataCell(Text(data['nTotalDiagNum']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildBasicInfoTable('통신 주소 정보', [
            DataRow(cells: [
              DataCell(Text('Model No Comm Addr')),
              DataCell(Text(data['nModelNoCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Code Ver Comm Addr')),
              DataCell(Text(data['nCodeVerCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Motor Status Comm Addr')),
              DataCell(Text(data['nMotorStatusCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Inv Status Comm Addr')),
              DataCell(Text(data['nInvStatusCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Inv Control Comm Addr')),
              DataCell(Text(data['nInvControlCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Parameter Save Comm Addr')),
              DataCell(Text(data['nParameterSaveCommAddr']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable(
              'Diagnostic Numbers', data['pDiagNum'] as List? ?? []),
          if (data['pDiagNumDetails'] != null &&
              (data['pDiagNumDetails'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDiagNumDetailsTable(
                'Diagnostic Numbers Details', data['pDiagNumDetails'] as List),
          ],
        ],
      ),
    );
  }

  Widget _buildIoSpecDetail() {
    final data = invData?['ioSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('IO Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Input')),
              DataCell(Text(data['nTotalInput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Normal Input')),
              DataCell(Text(data['nNormalInput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Input Func Title')),
              DataCell(Text(data['nTotalInputFuncTitle']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Output')),
              DataCell(Text(data['nTotalOutput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Normal Output')),
              DataCell(Text(data['nNormalOutput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Output Func Title')),
              DataCell(Text(data['nTotalOutputFuncTitle']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Add Input Status')),
              DataCell(Text(data['nAddInputStatus']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Add Output Status')),
              DataCell(Text(data['nAddOutputStatus']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Input Terminal Info',
              (data['pInputTermInfo'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Output Terminal Info',
              (data['pOutputTermInfo'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildListTable(
              'Input Function Messages', data['pInputFuncMsg'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Output Function Messages',
              data['pOutputFuncMsgTitle'] as List? ?? []),
        ],
      ),
    );
  }

  Widget _buildTripSpecDetail() {
    final data = invData?['tripSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Trip Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Trip Name')),
              DataCell(Text(data['nTotalTripName']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('First Trip Name Addr')),
              DataCell(Text(data['nFirstTripNameAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Cur Total Trip')),
              DataCell(Text(data['nCurTotalTrip']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Trip Info')),
              DataCell(Text(data['nTotalTripInfo']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Warn Name')),
              DataCell(Text(data['nTotalWarnName']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('First Warn Name Addr')),
              DataCell(Text(data['nFirstWarnNameAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Cur Total Warn')),
              DataCell(Text(data['nCurTotalWarn']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Warn Info')),
              DataCell(Text(data['nTotalWarnInfo']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable('Trip Names', data['pTripName'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Warning Names', data['pWarnName'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Trip Addresses', data['pTripAddr'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable(
              'Warning Addresses', data['pWarnAddr'] as List? ?? []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Trip Info Data',
              (data['pTripInfoData'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Warning Info Data',
              (data['pWarnInfoData'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
        ],
      ),
    );
  }

  Widget _buildMsgSpecDetail() {
    final data = invData?['msgSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Message Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Msg')),
              DataCell(Text(data['nTotalMsg']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMsgInfoTable('Message Info',
              (data['pMsgInfo'] as List?)?.cast<Map<String, dynamic>>() ?? []),
        ],
      ),
    );
  }

  Widget _buildCommonSpecDetail() {
    final data = invData?['commonSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Common Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Common No')),
              DataCell(Text(data['nTotCommonNo']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Common Info',
              (data['pCommonInfo'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
        ],
      ),
    );
  }

  Widget _buildParameterSpecDetail() {
    final data = invData?['parameterSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Parameter Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Group')),
              DataCell(Text(data['nTotGroup']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildParameterGroupTable('Parameter Groups',
              (data['pParmGrp'] as List?)?.cast<Map<String, dynamic>>() ?? []),
        ],
      ),
    );
  }

  Widget _buildInitOrderDetail() {
    final data = invData?['initOrder'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Init Order 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Init Order')),
              DataCell(Text(data['nTotInitOder']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable('Order Addresses', data['pOrderAddr'] as List? ?? []),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTable(String title, List<DataRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('필드명')),
                  DataColumn(label: Text('값')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTable(String title, List list) {
    List<DataRow> rows = [];
    for (int i = 0; i < list.length; i++) {
      rows.add(DataRow(
        cells: [
          DataCell(Text('항목 ${i + 1}')),
          DataCell(Text(list[i].toString())),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('번호')),
                  DataColumn(label: Text('값')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapListTable(String title, List<Map<String, dynamic>> mapList) {
    if (mapList.isEmpty) return const SizedBox.shrink();

    // 첫 번째 맵의 키들을 컬럼으로 사용
    final keys = mapList.first.keys.toList();
    List<DataColumn> columns = [
      const DataColumn(label: Text('번호')),
      ...keys.map((key) => DataColumn(label: Text(key))),
    ];

    List<DataRow> rows = [];
    for (int i = 0; i < mapList.length; i++) {
      List<DataCell> cells = [DataCell(Text('${i + 1}'))];
      for (String key in keys) {
        cells.add(DataCell(Text(mapList[i][key]?.toString() ?? '')));
      }
      rows.add(DataRow(cells: cells));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns,
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMsgInfoTable(
      String title, List<Map<String, dynamic>> msgInfoList) {
    List<DataRow> rows = [];
    for (int i = 0; i < msgInfoList.length; i++) {
      final msgInfo = msgInfoList[i];
      rows.add(DataRow(
        cells: [
          DataCell(Text('${i + 1}')),
          DataCell(Text(msgInfo['nTotTitle']?.toString() ?? '')),
          DataCell(Text((msgInfo['pTitle'] as List?)?.join(', ') ?? '')),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('번호')),
                  DataColumn(label: Text('Total Title')),
                  DataColumn(label: Text('Titles')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterGroupTable(
      String title, List<Map<String, dynamic>> paramGroups) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...paramGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return ExpansionTile(
                title: Text('Group ${index + 1}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (group['GrpInfo'] != null) ...[
                          Text(
                            'Group Info',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildMapTable(
                              group['GrpInfo'] as Map<String, dynamic>),
                          const SizedBox(height: 16),
                        ],
                        if (group['pParmType'] != null) ...[
                          Text(
                            'Parameters',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildMapListTable('',
                              group['pParmType'] as List<Map<String, dynamic>>),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTable(Map<String, dynamic> map) {
    List<DataRow> rows = [];
    map.forEach((key, value) {
      rows.add(DataRow(
        cells: [
          DataCell(Text(key)),
          DataCell(Text(value.toString())),
        ],
      ));
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('필드명')),
          DataColumn(label: Text('값')),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildDiagNumDetailsTable(String title, List diagNumDetails) {
    List<DataRow> rows = [];
    for (int i = 0; i < diagNumDetails.length; i++) {
      final detail = diagNumDetails[i] as Map<String, dynamic>?;
      if (detail != null) {
        final index = detail['index']?.toString() ?? '';
        final value = detail['value']?.toString() ?? '';
        rows.add(DataRow(
          cells: [
            DataCell(Text(index)),
            DataCell(Text(value)),
          ],
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Index')),
                  DataColumn(label: Text('Value')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class INVDataTablePage extends StatelessWidget {
  final Map<String, dynamic> invData;
  final String fileName;

  const INVDataTablePage(
      {super.key, required this.invData, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${fileName.split(Platform.pathSeparator).last} 데이터 표'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Device Spec'),
              Tab(text: 'IO Spec'),
              Tab(text: 'Trip Spec'),
              Tab(text: 'Message Spec'),
              Tab(text: 'Common Spec'),
              Tab(text: 'Parameter Spec'),
              Tab(text: 'Init Order'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDeviceSpecDetail(),
            _buildIoSpecDetail(),
            _buildTripSpecDetail(),
            _buildMsgSpecDetail(),
            _buildCommonSpecDetail(),
            _buildParameterSpecDetail(),
            _buildInitOrderDetail(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSpecDetail() {
    final data = invData['deviceSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Device Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Data File Version')),
              DataCell(Text(data['strDataFileVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Model No')),
              DataCell(Text(data['nInvModelNo']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Model Name')),
              DataCell(Text(data['strInvModelName'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('SW Version')),
              DataCell(Text(data['strInvSWVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Code Version')),
              DataCell(Text(data['strInvCodeVer'] ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Comm Offset')),
              DataCell(Text(data['nCommOffset']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Diag Num')),
              DataCell(Text(data['nTotalDiagNum']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildBasicInfoTable('통신 주소 정보', [
            DataRow(cells: [
              DataCell(Text('Model No Comm Addr')),
              DataCell(Text(data['nModelNoCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Code Ver Comm Addr')),
              DataCell(Text(data['nCodeVerCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Motor Status Comm Addr')),
              DataCell(Text(data['nMotorStatusCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Inv Status Comm Addr')),
              DataCell(Text(data['nInvStatusCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Inv Control Comm Addr')),
              DataCell(Text(data['nInvControlCommAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Parameter Save Comm Addr')),
              DataCell(Text(data['nParameterSaveCommAddr']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable(
              'Diagnostic Numbers', data['pDiagNum'] as List? ?? []),
          if (data['pDiagNumDetails'] != null &&
              (data['pDiagNumDetails'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDiagNumDetailsTable(
                'Diagnostic Numbers Details', data['pDiagNumDetails'] as List),
          ],
        ],
      ),
    );
  }

  Widget _buildIoSpecDetail() {
    final data = invData['ioSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('IO Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Input')),
              DataCell(Text(data['nTotalInput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Normal Input')),
              DataCell(Text(data['nNormalInput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Input Func Title')),
              DataCell(Text(data['nTotalInputFuncTitle']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Output')),
              DataCell(Text(data['nTotalOutput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Normal Output')),
              DataCell(Text(data['nNormalOutput']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Output Func Title')),
              DataCell(Text(data['nTotalOutputFuncTitle']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Add Input Status')),
              DataCell(Text(data['nAddInputStatus']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Add Output Status')),
              DataCell(Text(data['nAddOutputStatus']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Input Terminal Info',
              (data['pInputTermInfo'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Output Terminal Info',
              (data['pOutputTermInfo'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildListTable(
              'Input Function Messages', data['pInputFuncMsg'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Output Function Messages',
              data['pOutputFuncMsgTitle'] as List? ?? []),
        ],
      ),
    );
  }

  Widget _buildTripSpecDetail() {
    final data = invData['tripSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Trip Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Trip Name')),
              DataCell(Text(data['nTotalTripName']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('First Trip Name Addr')),
              DataCell(Text(data['nFirstTripNameAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Cur Total Trip')),
              DataCell(Text(data['nCurTotalTrip']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Trip Info')),
              DataCell(Text(data['nTotalTripInfo']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Warn Name')),
              DataCell(Text(data['nTotalWarnName']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('First Warn Name Addr')),
              DataCell(Text(data['nFirstWarnNameAddr']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Cur Total Warn')),
              DataCell(Text(data['nCurTotalWarn']?.toString() ?? ''))
            ]),
            DataRow(cells: [
              DataCell(Text('Total Warn Info')),
              DataCell(Text(data['nTotalWarnInfo']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable('Trip Names', data['pTripName'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Warning Names', data['pWarnName'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable('Trip Addresses', data['pTripAddr'] as List? ?? []),
          const SizedBox(height: 24),
          _buildListTable(
              'Warning Addresses', data['pWarnAddr'] as List? ?? []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Trip Info Data',
              (data['pTripInfoData'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Warning Info Data',
              (data['pWarnInfoData'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
        ],
      ),
    );
  }

  Widget _buildMsgSpecDetail() {
    final data = invData['msgSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Message Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Msg')),
              DataCell(Text(data['nTotalMsg']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMsgInfoTable('Message Info',
              (data['pMsgInfo'] as List?)?.cast<Map<String, dynamic>>() ?? []),
        ],
      ),
    );
  }

  Widget _buildCommonSpecDetail() {
    final data = invData['commonSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Common Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Common No')),
              DataCell(Text(data['nTotCommonNo']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildMapListTable(
              'Common Info',
              (data['pCommonInfo'] as List?)?.cast<Map<String, dynamic>>() ??
                  []),
        ],
      ),
    );
  }

  Widget _buildParameterSpecDetail() {
    final data = invData['parameterSpec'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Parameter Spec 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Group')),
              DataCell(Text(data['nTotGroup']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildParameterGroupTable('Parameter Groups',
              (data['pParmGrp'] as List?)?.cast<Map<String, dynamic>>() ?? []),
        ],
      ),
    );
  }

  Widget _buildInitOrderDetail() {
    final data = invData['initOrder'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoTable('Init Order 기본 정보', [
            DataRow(cells: [
              DataCell(Text('Total Init Order')),
              DataCell(Text(data['nTotInitOder']?.toString() ?? ''))
            ]),
          ]),
          const SizedBox(height: 24),
          _buildListTable('Order Addresses', data['pOrderAddr'] as List? ?? []),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTable(String title, List<DataRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('필드명')),
                  DataColumn(label: Text('값')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTable(String title, List list) {
    List<DataRow> rows = [];
    for (int i = 0; i < list.length; i++) {
      rows.add(DataRow(
        cells: [
          DataCell(Text('항목 ${i + 1}')),
          DataCell(Text(list[i].toString())),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('번호')),
                  DataColumn(label: Text('값')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapListTable(String title, List<Map<String, dynamic>> mapList) {
    if (mapList.isEmpty) return const SizedBox.shrink();

    // 첫 번째 맵의 키들을 컬럼으로 사용
    final keys = mapList.first.keys.toList();
    List<DataColumn> columns = [
      const DataColumn(label: Text('번호')),
      ...keys.map((key) => DataColumn(label: Text(key))),
    ];

    List<DataRow> rows = [];
    for (int i = 0; i < mapList.length; i++) {
      List<DataCell> cells = [DataCell(Text('${i + 1}'))];
      for (String key in keys) {
        cells.add(DataCell(Text(mapList[i][key]?.toString() ?? '')));
      }
      rows.add(DataRow(cells: cells));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns,
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMsgInfoTable(
      String title, List<Map<String, dynamic>> msgInfoList) {
    List<DataRow> rows = [];
    for (int i = 0; i < msgInfoList.length; i++) {
      final msgInfo = msgInfoList[i];
      rows.add(DataRow(
        cells: [
          DataCell(Text('${i + 1}')),
          DataCell(Text(msgInfo['nTotTitle']?.toString() ?? '')),
          DataCell(Text((msgInfo['pTitle'] as List?)?.join(', ') ?? '')),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('번호')),
                  DataColumn(label: Text('Total Title')),
                  DataColumn(label: Text('Titles')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterGroupTable(
      String title, List<Map<String, dynamic>> paramGroups) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...paramGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return ExpansionTile(
                title: Text('Group ${index + 1}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (group['GrpInfo'] != null) ...[
                          Text(
                            'Group Info',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildMapTable(
                              group['GrpInfo'] as Map<String, dynamic>),
                          const SizedBox(height: 16),
                        ],
                        if (group['pParmType'] != null) ...[
                          Text(
                            'Parameters',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildMapListTable('',
                              group['pParmType'] as List<Map<String, dynamic>>),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTable(Map<String, dynamic> map) {
    List<DataRow> rows = [];
    map.forEach((key, value) {
      rows.add(DataRow(
        cells: [
          DataCell(Text(key)),
          DataCell(Text(value.toString())),
        ],
      ));
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('필드명')),
          DataColumn(label: Text('값')),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildDiagNumDetailsTable(String title, List diagNumDetails) {
    List<DataRow> rows = [];
    for (int i = 0; i < diagNumDetails.length; i++) {
      final detail = diagNumDetails[i] as Map<String, dynamic>?;
      if (detail != null) {
        final index = detail['index']?.toString() ?? '';
        final value = detail['value']?.toString() ?? '';
        rows.add(DataRow(
          cells: [
            DataCell(Text(index)),
            DataCell(Text(value)),
          ],
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Index')),
                  DataColumn(label: Text('Value')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
