import 'package:flutter/material.dart';
import 'dart:io';
import 'pole.dart';

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
      List<String> result = await _visit(0, storage, '/');
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
