import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'pages/file_content_page.dart';
import 'pages/json_content_page.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INV(MS-CFB) Viewer',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // pubspec.yaml에 등록된 주요 assets 리스트 (직접 하드코딩)
  static const List<String> assetFiles = [
    'assets/DataFile/LSIS/S300/S300_1_00.json',
    'assets/DataFile/LSIS/S300/S300_1_00_Title.json',
    'assets/DataFile/LSIS/S300/S300_1_01.json',
    'assets/DataFile/LSIS/S300/S300_1_01_Title.json',
    'assets/DataFile/LSIS/G100/G100_1_00.inv',
    'assets/DataFile/LSIS/G100/G100_1_10.INV',
    'assets/DataFile/LSIS/G100/G100_1_30.INV',
    'assets/DataFile/LSIS/G100/G100_1_40.INV',
  ];

  Future<void> _pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        if (context.mounted) {
          if (result.files.single.path!
              .toLowerCase()
              .toString()
              .endsWith('.inv')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FileContentPage(
                  fileName: result.files.single.path!,
                ),
              ),
            );
          }
          if (result.files.single.path!
              .toLowerCase()
              .toString()
              .endsWith('.json')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JsonContentPage(
                  filePath: result.files.single.path!,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일을 읽는 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _openAssetFile(BuildContext context, String assetPath) {
    if (assetPath.toLowerCase().endsWith('.json')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JsonContentPage(filePath: assetPath),
        ),
      );
    } else if (assetPath.toLowerCase().endsWith('.inv')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileContentPage(fileName: assetPath),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INV(MS-CFB) Viewer')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isWindows)
              ElevatedButton(
                onPressed: () => _pickFile(context),
                child: const Text('파일 선택'),
              ),
            if (!Platform.isWindows) ...[
              const SizedBox(height: 24),
              const Text('Assets 파일 목록',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: assetFiles.length,
                  itemBuilder: (context, index) {
                    final asset = assetFiles[index];
                    return ListTile(
                      title: Text(asset),
                      onTap: () => _openAssetFile(context, asset),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
