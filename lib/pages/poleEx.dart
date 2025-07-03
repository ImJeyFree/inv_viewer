import 'dart:io';
import 'package:flutter/services.dart';

/// POLE_EX - Portable Dart library to access OLE Storage (memory version)
/// Ported from pole_ex.h / pole_ex.cpp, 참고: pole.dart

//=================================================================================================
// signature, or magic identifier
//-------------------------------------------------------------------------------------------------
final List<int> poleMagic = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

//=================================================================================================
// Special block values (AllocTable)
//-------------------------------------------------------------------------------------------------
final int poleEof = 0xffffffff;
final int poleAvail = 0xfffffffe;
final int poleBat = 0xfffffffd;
final int poleMetaBat = 0xfffffffc;
final int dirTreeEnd = 0xffffffff;

//=================================================================================================
// Default values
//-------------------------------------------------------------------------------------------------
final int signature = 0xE11AB1A1E011CFD0; // poleMagic
final int version = 0x3E; // 62
final int sectorSize = 0x200; // 512
final int shortSectorSize = 0x40; // 64
final int maxBlockSize = 0x1000; // 4096
final int maxBbatCount = 0x80; // 128
final int maxSbatCount = 0x80; // 128
final int initialBlockSize = 0x80; // 128
final int maxSmallBlockSize = 0x100; // 256

//=================================================================================================
// a presumably reasonable size for the read cache
//-------------------------------------------------------------------------------------------------
final int poleCACHEBUFSIZE = 4096;

//=================================================================================================

int _readU16(Uint8List buffer, int offset) {
  return buffer[offset] | (buffer[offset + 1] << 8);
}

void _writeU16(Uint8List buffer, int offset, int value) {
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

// optimize this with better search
bool alreadyExist(List<int> chain, int item) {
  for (int i = 0; i < chain.length; i++) {
    if (chain[i] == item) return true;
  }
  return false;
}

//=================================================================================================
// Header class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class Header {
  List<int> id = List.filled(8, 0); // signature, or magic identifier
  int bShift = 0; // bbat.blockSize = 1 << b_shift
  int sShift = 0; // sbat.blockSize = 1 << s_shift
  int numBat = 0; // blocks allocated for big bat

  int direntStart = 0; // starting block for directory info
  int threshold = 0; // switch from small to big file (usually 4K)
  int sbatStart = 0; // starting block index to store small bat
  int numSbat = 0; // blocks allocated for small bat
  int mbatStart = 0; // starting block to store meta bat
  int numMbat = 0; // blocks allocated for meta bat

  final List<int> bbBlocks = List.filled(109, poleAvail);
  bool dirty = false; // Needs to be written
  //===============================================================================================
  Header() {
    init();
  }

  void init() {
    id.setRange(0, 8, poleMagic);
    //bbBlocks.setRange(0, 109, List.filled(109, poleAvail));

    // Set default values
    bShift = 9;
    sShift = 6;
    threshold = 4096;
    numBat = 0;
    direntStart = 0;
    sbatStart = 0;
    numSbat = 0;
    numMbat = 0;
    mbatStart = poleEof;
    dirty = true;
  }

  bool valid() {
    if (threshold != 4096) return false;
    if (numBat == 0) return false;
    if ((numBat < 109) && (numMbat != 0)) return false;
    if ((numBat > 109) && (numBat > (numBat * 127) + 109)) return false;

    if (sShift > bShift) return false;
    if (bShift <= 6) return false;
    if (bShift >= 31) return false;

    return true;
  }

  void load(Uint8List buffer) {
    bShift = _readU16(buffer, 0x1e);
    sShift = _readU16(buffer, 0x20);

    numBat = _readU32(buffer, 0x2c);

    direntStart = _readU32(buffer, 0x30);
    threshold = _readU32(buffer, 0x38);
    sbatStart = _readU32(buffer, 0x3c);
    numSbat = _readU32(buffer, 0x40);
    mbatStart = _readU32(buffer, 0x44);
    numMbat = _readU32(buffer, 0x48);

    // for (int i = 0; i < 8; i++) { id[i] = buffer[i]; }
    id.setRange(0, 8, buffer.sublist(0, 8));

    // [4C = 76)
    for (int i = 0; i < 109; i++) {
      bbBlocks[i] = _readU32(buffer, 0x4C + i * 4);
    }
    dirty = false;
  }

  void save(Uint8List buffer) {
    buffer.fillRange(0, buffer.length, 0);

    // root is fixed as "Root Entry"
    // for (int i = 0; i < 8; i++) {
    //   buffer[i] = poleMagic[i]; // ole signature
    // }
    buffer.setRange(0, 8, poleMagic); // ole signature

    _writeU32(buffer, 0x08, 0); // unknown
    _writeU32(buffer, 0x0C, 0); // unknown
    _writeU32(buffer, 0x10, 0); // unknown

    _writeU16(buffer, 0x18, 0x003E); // revision ?
    _writeU16(buffer, 0x1A, 3); // version ?
    _writeU16(buffer, 0x1C, 0xfffe); // unknown
    _writeU16(buffer, 0x1E, bShift);
    _writeU16(buffer, 0x20, sShift);

    _writeU32(buffer, 0x2C, numBat);
    _writeU32(buffer, 0x30, direntStart);
    _writeU32(buffer, 0x38, threshold);
    _writeU32(buffer, 0x3C, sbatStart);
    _writeU32(buffer, 0x40, numSbat);
    _writeU32(buffer, 0x44, mbatStart);
    _writeU32(buffer, 0x48, numMbat);

    // 0x4C = 76
    for (int i = 0; i < 109; i++) {
      _writeU32(buffer, 0x4C + i * 4, bbBlocks[i]);
    }
  }

  void debug() {
    print('Header:');
    print('  id: ${id.map((b) => b.toRadixString(16)).join(' ')}');
    print('  bShift: $bShift');
    print('  sShift: $sShift');
    print('  numBat: $numBat');
    print('  direntStart: $direntStart');
    print('  threshold: $threshold');
    print('  sbatStart: $sbatStart');
    print('  numSbat: $numSbat');
    print('  mbatStart: $mbatStart');
    print('  numMbat: $numMbat');
    //print('  dirty: $dirty');
    print('  bbBlocks: ${bbBlocks.take(10).toList()} ...');
    print('  bat blocks: ');
    for (int i = 0; i < numBat; i++) {
      print('    bbBlocks[$i]: ${bbBlocks[i].toString()}');
    }
  }
}

class AllocTable {
  int blockSize = 4096;
  final List<int> data = [];

  AllocTable() {
    resize(128);
  }

  int operator [](int index) {
    if (index < 0 || index >= data.length) return poleEof;
    return data[index];
  }

  void clear() => data.clear();

  int count() => data.length;

  void resize(int newsize) {
    int oldsize = data.length;
    if (newsize >= oldsize) {
      for (int i = oldsize; i < newsize; i++) {
        data.add(poleAvail);
      }
    } else {
      data.removeRange(newsize, oldsize);
    }
  }

  // make sure there're still free blocks
  void preserve(int n) {
    final pre = <int>[];
    for (int i = 0; i < n; i++) {
      pre.add(unused());
    }
  }

  void set(int index, int value) {
    if (index >= data.length) {
      resize(index + 1);
    }
    data[index] = value;
  }

  void setChain(List<int> chain) {
    if (chain.isNotEmpty) {
      for (int i = 0; i < chain.length - 1; i++) {
        set(chain[i], chain[i + 1]);
      }
      set(chain[chain.length - 1], poleEof);
    }
  }

  List<int> follow(int start) {
    List<int> chain = [];
    if (start >= count()) return chain;

    int p = start;
    while (p < count()) {
      if (p == poleEof) break;
      if (p == poleBat) break;
      if (p == poleMetaBat) break;

      if (alreadyExist(chain, p)) break;

      chain.add(p);

      if (data[p] >= count()) break;

      p = data[p];
    }
    return chain;
  }

  int unused() {
    // find first available block
    for (int i = 0; i < data.length; i++) {
      if (data[i] == poleAvail) return i;
    }

    // completely full, so enlarge the table
    int block = data.length;
    resize(data.length + 10);
    return block;
  }

  void load(Uint8List buffer, int len) {
    resize(len ~/ 4);
    for (int i = 0; i < count(); i++) {
      set(i, _readU32(buffer, i * 4));
    }
  }

  int size() => data.length * 4;

  void save(Uint8List buffer) {
    for (int i = 0; i < count(); i++) {
      _writeU32(buffer, i * 4, data[i]);
    }
  }

  void debug() {
    print("AllocTable:");
    print("  block size: ${data.length}");
    for (int i = 0; i < data.length; i++) {
      if (data[i] == poleAvail) continue;
      String output = "  $i: ";
      if (data[i] == poleEof) {
        output += "[Eof]";
      } else if (data[i] == poleBat) {
        output += "[Bat]";
      } else if (data[i] == poleMetaBat) {
        output += "[Metabat]";
      } else {
        output += data[i].toString();
      }
      print(output);
    }
  }
}

//=================================================================================================
// OLE 파일의 디렉터리 항목을 나타내는 클래스
// - 각 항목은 스트림(파일)이거나 저장소(디렉터리)일 수 있다.
//-------------------------------------------------------------------------------------------------
class DirEntry {
  bool valid = false; // 항목이 유효한지 여부
  String name = ''; // 항목의 이름
  bool dir = false; // // 항목이 디렉터리(저장소)인지 여부
  int size =
      0; // 스트림의 크기 (바이트 단위). 디렉터리인 경우 0. MS-CFB 명세에는 64비트지만, POLE C++ 구현은 load/save 시 32비트로 처리
  int start = 0; // 스트림/저장소 데이터의 시작 블록 인덱스
  int prev = 0; // 이전 형제 항목의 인덱스 (DirTree 내)
  int next = 0; // 다음 형제 항목의 인덱스 (DirTree 내)
  int child = 0; // 첫 번째 자식 항목의 인덱스 (디렉터리인 경우, DirTree 내)
  //===============================================================================================
  DirEntry();
  int compare(DirEntry other) {
    return name.compareTo(other.name);
  }

  int compareName(String name2) {
    //return name.compareTo(name2);
    if (name.length < name2.length) {
      return -1;
    } else if (name.length > name2.length) {
      return 1;
    }

    return name.compareTo(name2);
  }

  void debug() {
    print('DirEntry:');
    print('  name: $name');
    print('  valid: $valid');
    print('  dir: $dir');
    print('  size: $size');
    print('  child: $child');
    print('  child: $child');
    print('  child: $child');
    print('  start: $start');
    print('  size: $size');
  }
}

//=================================================================================================
// Directory Tree class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class DirTree {
  //final end = dirTreeEnd;
  final List<DirEntry> entries = [];
  //===============================================================================================
  DirTree() {
    clear();
  }

  void clear() {
    // leave only root entry
    entries.clear();
    entries.add(DirEntry()
      ..valid = true
      ..name = "Root Entry"
      ..dir = true
      ..size = 0
      ..start = dirTreeEnd
      ..prev = dirTreeEnd
      ..next = dirTreeEnd
      ..child = dirTreeEnd);
  }

  int entryCount() => entries.length;

  DirEntry? entry(int index) {
    if (index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  int indexOf(DirEntry? e) {
    for (int i = 0; i < entryCount(); i++) {
      if (entry(i) == e) return i;
    }
    return -1;
  }

  int parent(int index) {
    // brute-force, basically we iterate for each entries, find its children
    // and check if one of the children is 'index'
    for (int j = 0; j < entryCount(); j++) {
      List<int> chi = children(j);
      for (int i = 0; i < chi.length; i++) {
        if (chi[i] == index) return j;
      }
    }
    return -1;
  }

  String fullName(int index) {
    if (index < 0 || index >= entries.length) return '';

    // don't use root name ("Root Entry"), just give "/"
    if (index == 0) return "/";

    String result = entry(index)?.name ?? "";
    result = "/$result";

    int p = parent(index);
    while (p > 0) {
      DirEntry? e = entry(p);
      if (e != null && e.dir && e.valid) {
        result = "/${e.name}$result";
      }
      index = --p;
      if (index <= 0) break;
    }
    //print('DirTree::fullName() - fullname: $result');
    return result;
  }

  // given a fullname (e.g "/ObjectPool/_1020961869"), find the entry
  // if not found and create is false, return 0
  // if create is true, a new entry is returned
  DirEntry? entryByName(String name, {bool create = false}) {
    if (name.isEmpty) return null;

    // quick check for "/" (that's root)
    if (name == '/') return entry(0);

    // split the names, e.g  "/ObjectPool/_1020961869" will become:
    // "ObjectPool" and "_1020961869"
    List<String> names = name.split('/');
    if (names.isEmpty) return null;

    if (names.length > 1) {
      if (names.first.isEmpty) {
        names.removeAt(0);
      }
      if (names.last.isEmpty) {
        names.removeLast();
      }
    }

    // Start from root
    int index = 0;

    // Navigate through the tree
    for (int i = 0; i < names.length; i++) {
      // find among the children of index
      final childList = children(index);

      int child = 0;
      for (int j = 0; j < childList.length; j++) {
        //for (var element in childList) {
        var element = childList[j];
        final e = entry(element);
        if (e != null) {
          if (e.valid && e.name.isNotEmpty) {
            if (e.name == names[i]) {
              child = element;
              //break;
            }
          }
        }
      }

      // traverse to the child
      if (child > 0) {
        index = child;
      } else {
        // not found among children
        if (!create) {
          // print('DirTree::entryByName() - child: $child, index: $index !!!!!!!!!!!!!!!!!!!!!!!!!');
          return null;
        }

        // create a new entry
        int parent = index;
        index = entryCount() - 1;

        // entries.add(DirEntry()
        //   ..valid = true
        //   ..name = names[i]
        //   ..dir = false
        //   ..size = 0
        //   ..start = 0
        //   ..child = dirTreeEnd
        //   ..prev = dirTreeEnd
        //   ..next = entry(parent)?.child ?? dirTreeEnd);

        entries.add(DirEntry());
        DirEntry? e = entry(index);
        if (e != null) {
          e.valid = true;
          e.name = names[i];
          e.dir = false;
          e.size = 0;
          e.start = 0;
          e.child = dirTreeEnd;
          e.prev = dirTreeEnd;
          e.next = entry(parent)?.child ?? dirTreeEnd;
        }
        entry(parent)?.child = index;
      }
    }

    return entry(index);
  }

  // helper function: recursively find siblings of index
  void findSiblings(DirTree? dirtree, List<int>? result, int index) {
    if (result == null) return;
    DirEntry? e = dirtree?.entry(index);
    if (e == null || !e.valid) return;

    // prevent infinite loop
    for (int i = 0; i < result.length; i++) {
      if (result[i] == index) return;
    }

    // add myself
    result.add(index);

    // visit previous sibling, don't go infinitely
    int idx = e.prev;
    if (idx > 0 && idx < dirtree!.entryCount()) {
      for (int i = 0; i < result.length; i++) {
        if (result[i] == idx) idx = 0;
      }
      if (idx > 0) findSiblings(dirtree, result, idx);
    }

    // visit next sibling, don't go infinitely
    idx = e.next;
    if ((idx > 0) && (idx < dirtree!.entryCount())) {
      for (int i = 0; i < result.length; i++) {
        if (result[i] == idx) idx = 0;
      }
      if (idx > 0) findSiblings(dirtree, result, idx);
    }
  }

  List<int> children(int index) {
    List<int> result = [];
    DirEntry? e = entry(index);
    if (e != null) {
      if (e.valid && e.child < entryCount()) {
        findSiblings(this, result, e.child);
      }
    }
    return result;
  }

  void load(Uint8List buffer, int size) {
    entries.clear();

    int maxEntries = size ~/ 128;
    for (int i = 0; i < maxEntries; i++) {
      int offset = i * 128;

      // would be < 32 if first char in the name isn't printable
      //int prefix = 32;

      // parse name of this entry, which stored as Unicode 16-bit
      // 이름(UTF-16LE, 최대 32바이트)
      String name = '';
      int nameLen = _readU16(buffer, 0x40 + offset);
      if (nameLen > 64) nameLen = 64;

      for (int j = 0; j < nameLen && buffer[j + offset] != 0; j += 2) {
        name += String.fromCharCode(buffer[j + offset]);
      }

      // first char isn't printable ? remove it... 첫 글자가 출력 불가 문자면 제거
      if (buffer[offset] < 32) {
        // prefix = buffer[offset];
        if (name.length > 1) {
          name = name.substring(1);
        }
      }

      // 2 = file (aka stream), 1 = directory (aka storage), 5 = root
      int type = buffer[0x42 + offset];

      var e = DirEntry();
      e.valid = true; //(type != 0); // buffer[offset + 0x42] != 0;
      e.dir = (type != 2); // buffer[offset + 0x43] != 0;
      e.name = name;

      // Read other fields
      e.start = _readU32(buffer, offset + 0x74);
      e.size = _readU32(buffer, offset + 0x78);
      e.prev = _readU32(buffer, offset + 0x44);
      e.next = _readU32(buffer, offset + 0x48);
      e.child = _readU32(buffer, offset + 0x4C);

      // sanity checks
      if ((type != 2) && (type != 1) && (type != 5)) e.valid = false;
      if (nameLen < 1) e.valid = false;

      // // There is a space at the last. Parsing을 못한건지 확인 해야함.
      // if (type != 0 && name.isNotEmpty) {
      //   //entries[i] = e;
      //   entries.add(e);
      // }
      entries.add(e);
    }
  }

  // return space required to save this dirtree
  int size() => entryCount() * 128;

  void save(Uint8List buffer) {
    // for (int i = 0; i < size(); i++)  buffer[i] = 0; }
    buffer.fillRange(0, buffer.length, 0);

    // root is fixed as "Root Entry"
    DirEntry root = entry(0)!;
    String name = "Root Entry";

    for (int i = 0; i < name.length; i++) {
      buffer[i * 2] = name.codeUnitAt(i);
    }

    _writeU16(buffer, 0x40, name.length * 2 + 2);

    _writeU32(buffer, 0x74, dirTreeEnd); // 0xffffffff
    _writeU32(buffer, 0x78, 0);
    _writeU32(buffer, 0x44, dirTreeEnd); // 0xffffffff
    _writeU32(buffer, 0x48, dirTreeEnd); // 0xffffffff
    _writeU32(buffer, 0x4c, root.child);

    buffer[0x42] = 5;
    buffer[0x43] = 1;

    for (int i = 0; i < entries.length; i++) {
      DirEntry? e = entry(i);
      if (e == null) continue;
      if (e.dir) {
        e.start = dirTreeEnd; // 0xffffffff;
        e.size = 0;
      }

      // max length for name is 32 chars
      String name = e.name;
      if (name.length > 32) {
        //name.erase( 32, name.length() );
        name = name.substring(0, 32);
      }

      int offset = i * 128;

      // write name as Unicode 16-bit
      for (int j = 0; j < name.length; j++) {
        buffer[offset + j * 2] = name.codeUnitAt(j);
      }

      buffer[offset + 0x42] = e.dir ? 1 : 2;
      buffer[offset + 0x43] = 1; // always black

      // Write other fields
      _writeU16(buffer, offset + 0x40, name.length * 2 + 2);

      _writeU32(buffer, offset + 0x74, e.start);
      _writeU32(buffer, offset + 0x78, e.size);
      _writeU32(buffer, offset + 0x44, e.prev);
      _writeU32(buffer, offset + 0x48, e.next);
      _writeU32(buffer, offset + 0x4c, e.child);
    }
  }

  void debug() {
    print('DirTree:');
    print('  entries: ${entries.length}');
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].name.isEmpty) continue;
      print('  $i: ${entries[i].name.toString()}');
    }
  }
}

//=================================================================================================
// Storage I/O class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class StorageIO {
  Storage _storage;
  Uint8List fileData;
  int dataLength;

  int result = Storage.ok; // result of operation (0=Ok)
  bool opened = false; // true if file is opened
  int filesize = 0; // size of the file

  Header header = Header(); // storage header
  DirTree dirtree = DirTree(); // directory tree
  AllocTable bbat = AllocTable(); // allocation table for big blocks
  AllocTable sbat = AllocTable(); // allocation table for small blocks

  List<int> sbBlocks = []; // blocks for "small" files
  List<StreamIO> streams = [];

  //===============================================================================================
  StorageIO(this._storage, this.fileData, this.dataLength) {
    bbat.blockSize = 1 << header.bShift;
    sbat.blockSize = 1 << header.sShift;
  }

  // Storage 인스턴스 가져오기
  Storage? get storage => _storage;

  bool open() {
    try {
      if (opened) close();
      opened = true;
      load();
    } catch (e) {
      print('StorageIO::open() 오류: $e');
      return false;
    }
    return result == Storage.ok;
  }

  void close() {
    try {
      if (!opened) return;
      //FSTREAM file.close();
      for (var stream in streams) {
        stream.clear();
      }
      streams.clear();
      opened = false;
    } catch (e) {
      print('StorageIO::close() 오류: $e');
    }
  }

  void load() {
    int buflen = 0;

    // open the file, check for error
    result = Storage.openFailed;

    // find size of input file
    filesize = dataLength;

    // load header
    if (filesize > 0) {
      Uint8List buffer = Uint8List(512);
      //buffer.fillRange(0, 512, 0);
      buffer.setRange(0, 512, fileData);
      header.load(buffer);
    }

    // check OLE magic id
    result = Storage.notOLE;
    for (int i = 0; i < 8; i++) {
      if (header.id[i] != poleMagic[i]) return;
    }

    // sanity checks
    result = Storage.badOLE;
    if (!header.valid()) return;
    if (header.threshold != 4096) return;

    // important block size
    bbat.blockSize = 1 << header.bShift;
    sbat.blockSize = 1 << header.sShift;

    // find blocks allocated to store big bat
    // the first 109 blocks are in header, the rest in meta bat
    List<int> blocks1 = List.filled(header.numBat, 0);
    for (int i = 0; i < 109; i++) {
      if (i >= header.numBat) {
        break;
      } else {
        blocks1[i] = header.bbBlocks[i];
      }
    }

    if ((header.numBat > 109) && (header.numMbat > 0)) {
      Uint8List buffer = Uint8List(bbat.blockSize);
      int k = 109;
      int mblock = header.mbatStart;
      for (int r = 0; r < header.numMbat; r++) {
        loadBigBlock(mblock, buffer, bbat.blockSize);
        for (int s = 0; s < bbat.blockSize - 4; s += 4) {
          if (k >= header.numBat) {
            break;
          } else {
            blocks1[k++] = _readU32(buffer, s);
          }
        }
        mblock = _readU32(buffer, bbat.blockSize - 4);
      }
    }

    // load big bat
    buflen = blocks1.length * bbat.blockSize;
    print('StorageIO::load() !!!! 1 buflen: $buflen');
    if (buflen > 0) {
      Uint8List buffer = Uint8List(buflen);
      buffer.fillRange(0, buflen, 0);
      loadBigBlocks(blocks1, buffer, buflen);

      //bbat.clear();
      bbat.load(buffer, buflen);
    }

    // load small bat
    List<int> blocks2 = bbat.follow(header.sbatStart);
    buflen = blocks2.length * bbat.blockSize;
    if (buflen > 0) {
      Uint8List buffer = Uint8List(buflen);
      buffer.fillRange(0, buflen, 0);
      loadBigBlocks(blocks2, buffer, buflen);

      //sbat.clear();
      sbat.load(buffer, buflen);
    }

    // load directory tree
    List<int> blocks3 = bbat.follow(header.direntStart);
    buflen = blocks3.length * bbat.blockSize;

    if (buflen > 0) {
      Uint8List buffer = Uint8List(buflen);
      buffer.fillRange(0, buflen, 0);

      loadBigBlocks(blocks3, buffer, buflen);

      dirtree.load(buffer, buflen);
      int sbStart = _readU32(buffer, 0x74);

      // fetch block chain as data for small-files
      sbBlocks.clear();
      sbBlocks.addAll(bbat.follow(sbStart)); // small files
    }

    // for troubleshooting, just enable this block
    // header.debug();
    // sbat.debug();
    // bbat.debug();
    // dirtree.debug();

    // so far so good
    result = Storage.ok;
    opened = true;
  }

  void create() {
    // so far so good
    opened = true;
    result = Storage.ok;
  }

  Future<void> flush() async {
    /* Note on Microsoft implementation:
     - directory entries are stored in the last block(s)
     - BATs are as second to the last
     - Meta BATs are third to the last
     */
  }

  StreamIO? streamIO(String name) {
    // print('StorageIO::streamIO() - name: $name');
    // sanity check
    if (name.isEmpty) {
      // print('streamIO::streamIO() - name.isEmpty !!!');
      return null;
    }

    // search in the entries
    DirEntry? entry = dirtree.entryByName(name);
    if (entry == null || entry.dir) {
      return null;
    }

    StreamIO result = StreamIO(this, entry);
    result.fullName = name;

    // print(
    //     'StorageIO::streamIO() - fullName: ${result.fullName}, blocks.length: ${result.blocks.length}');
    return result;
  }

  int loadBigBlocks(List<int> blocks, Uint8List data, int maxlen) {
    // sentinel
    if (blocks.isEmpty || maxlen == 0) return 0;

    // read block one by one, seems fast enough
    int bytes = 0;
    for (int i = 0; (i < blocks.length) && (bytes < maxlen); i++) {
      int block = blocks[i];
      int pos = bbat.blockSize * (block + 1);
      int p =
          (bbat.blockSize < maxlen - bytes) ? bbat.blockSize : maxlen - bytes;
      if (pos + p > filesize) p = filesize - pos;

      // 핵심 복사 부분
      data.setRange(bytes, bytes + p, fileData.getRange(pos, pos + p));
      bytes += p;
    }
    return bytes;
  }

  int loadBigBlock(int block, Uint8List data, int maxlen) {
    // wraps call for loadBigBlocks
    List<int> blocks = [];
    blocks.add(block);
    return loadBigBlocks(blocks, data, maxlen);
  }

  // return number of bytes which has been read
  int loadSmallBlocks(List<int> blocks, Uint8List? data, int maxlen) {
    // sentinel
    if (data == null) return 0;
    if (blocks.isEmpty) return 0;
    if (maxlen == 0) return 0;

    // our own local buffer
    Uint8List buf = Uint8List(bbat.blockSize);

    // read small block one by one
    int bytes = 0;
    for (int i = 0; (i < blocks.length) & (bytes < maxlen); i++) {
      int block = blocks[i];

      // find where the small-block exactly is
      int pos = block * sbat.blockSize;
      int bbindex = pos ~/ bbat.blockSize;
      if (bbindex >= sbBlocks.length) break;

      loadBigBlock(sbBlocks[bbindex], buf, bbat.blockSize);

      // copy the data
      int offset = pos % bbat.blockSize;
      int p = (maxlen - bytes < bbat.blockSize - offset)
          ? maxlen - bytes
          : bbat.blockSize - offset;
      p = (sbat.blockSize < p) ? sbat.blockSize : p;

      data.setRange(bytes, bytes + p, buf, offset);
      bytes += p;
    }

    return bytes;
  }

  int loadSmallBlock(int block, Uint8List? data, int maxlen) {
    // sentinel
    if (data == null) return 0;

    // wraps call for loadSmallBlocks
    List<int> blockList = [];
    blockList.add(block);
    return loadSmallBlocks(blockList, data, maxlen);
  }
}

//=================================================================================================
// Stream I/O class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class StreamIO {
  final StorageIO io;
  final DirEntry entry;

  String fullName = '';
  bool eof = false;
  bool fail = false;

  int mPos = 0;
  List<int> blocks = [];

  int cachePos = 0;
  int cacheSize = 4096;
  Uint8List cacheData = Uint8List(4096);

  //===============================================================================================
  StreamIO(this.io, this.entry) {
    if (entry.size >= io.header.threshold) {
      blocks = io.bbat.follow(entry.start);
    } else {
      blocks = io.sbat.follow(entry.start);
    }

    // prepare cache
    //cacheData = Uint8List(cacheSize);
    updateCache();
  }

  void clear() {}

  void seek(int pos) {
    mPos = pos;
  }

  int tell() => mPos;

  int getch() {
    // past end-of-file ?
    if (mPos > entry.size) return -1;

    // need to update cache ?
    if (cacheSize > 0 || (mPos < cachePos) || (mPos >= cachePos + cacheSize)) {
      updateCache();
    }

    // something bad if we don't get good cache
    if (cacheSize <= 0) return -1;

    int data = cacheData[mPos - cachePos];
    mPos++;

    return data;
  }

  int read3(int pos, Uint8List data, int maxlen) {
    // sanity checks
    if (maxlen == 0) return 0;

    int totalbytes = 0;
    if (entry.size < io.header.threshold) {
      // small file
      int index = pos ~/ io.sbat.blockSize;

      if (index >= blocks.length) return 0;

      Uint8List buf = Uint8List(io.sbat.blockSize);
      int offset = pos % io.sbat.blockSize;

      while (totalbytes < maxlen) {
        if (index >= blocks.length) break;

        io.loadSmallBlock(blocks[index], buf, io.bbat.blockSize);
        int count = io.sbat.blockSize - offset;

        if (count > maxlen - totalbytes) count = maxlen - totalbytes;

        data.setRange(totalbytes, totalbytes + count, buf, offset);
        totalbytes += count;

        offset = 0;
        index++;
      }
      //buf.clear();
    } else {
      // big file
      int index = pos ~/ io.bbat.blockSize;

      if (index >= blocks.length) return 0;

      Uint8List buf = Uint8List(io.bbat.blockSize);
      int offset = pos % io.bbat.blockSize;

      while (totalbytes < maxlen) {
        if (index >= blocks.length) break;

        io.loadBigBlock(blocks[index], buf, io.bbat.blockSize);
        int count = io.bbat.blockSize - offset;

        if (count > maxlen - totalbytes) count = maxlen - totalbytes;

        data.setRange(totalbytes, totalbytes + count, buf, offset);
        totalbytes += count;

        offset = 0;
        index++;
      }
      //buf.clear();
    }

    return totalbytes;
  }

  int read(Uint8List data, int maxlen) {
    int bytes = read3(tell(), data, maxlen);
    mPos += bytes;
    return bytes;
  }

  void updateCache() {
    // sanity check
    //if (cacheData) return;
    // print('StreamIO::updateCache() - 1 !!!!!');

    cachePos = mPos - (mPos % cacheSize);
    int bytes = cacheSize;
    if (cachePos + bytes > entry.size) bytes = entry.size - cachePos;
    cacheSize = read3(cachePos, cacheData, bytes);
  }
}

//=================================================================================================
// Storage class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class Storage {
  final String fileName;
  final bool _isAssets;
  late StorageIO io;
  late Uint8List dataBuffer; // = Uint8List(0);

  //===============================================================================================
  // Result codes: 0=Ok, 1=OpenFailed, 2=NotOLE, 3=BadOLE, 4=UnknownError
  //-----------------------------------------------------------------------------------------------
  static const int ok = 0;
  static const int openFailed = 1;
  static const int notOLE = 2;
  static const int badOLE = 3;
  static const int unknownError = 4;

  //===============================================================================================
  //Storage(this.bytes);
  Storage({required this.fileName, bool isAssets = false})
      : _isAssets = isAssets {
    print('Storage::Storage() - $fileName');
    if (_isAssets) {
      //getAssetsStream(fileName);
    } else {
      //getFileStream(fileName);
    }
    //io = StorageIO(this, dataBuffer, dataBuffer.length);
  }
  //-----------------------------------------------------------------------------------------------
  Future<bool> getFileStream(String filename) async {
    File file = File(filename);
    if (!await file.exists()) {
      print('getFileStream: 파일 경로 오류 또는 파일 로드 실패 !!!: $filename');
      return false;
    }

    RandomAccessFile raf = await file.open(mode: FileMode.read);
    int filesize = await file.length();
    dataBuffer = Uint8List(filesize);

    await raf.setPosition(0);
    await raf.readInto(dataBuffer);
    await raf.close();

    io = StorageIO(this, dataBuffer, dataBuffer.length);
    return true;
  }

  Future<bool> getAssetsStream(String filename) async {
    try {
      final ByteData byteData = await rootBundle.load(filename);
      dataBuffer = Uint8List.view(byteData.buffer, 0, byteData.lengthInBytes);
      io = StorageIO(this, dataBuffer, dataBuffer.length);
    } catch (e) {
      print('getAssetsStream: asset($filename) 경로 오류 또는 파일 로드 실패: $e');
      return false;
    }
    return true;
  }

  //-----------------------------------------------------------------------------------------------
  // Opens the storage. Returns true if no error occurs.
  Future<bool> open() async {
    print('Storage::open() - $fileName');
    if (_isAssets) {
      await getAssetsStream(fileName);
    } else {
      await getFileStream(fileName);
    }
    return io.open();
  }

  // Closes the storage.
  void close() {
    io.close();
    //dataBuffer.clear();
  }

  // Returns the error code of last operation.
  int get result => io.result;

  // Finds all stream and directories in given path.
  List<String> entries([String path = "/"]) {
    List<String> result = [];
    DirTree dt = io.dirtree;
    DirEntry? e = dt.entryByName(path);
    if (e != null && e.dir) {
      int parent = dt.indexOf(e);
      var children = dt.children(parent);
      for (int i = 0; i < children.length; i++) {
        result.add(dt.entry(children[i])?.name ?? '');
      }
    }
    return result;
  }

  // Returns true if specified entry name is a directory.
  bool isDirectory(String name) {
    var entry = io.dirtree.entryByName(name);
    if (entry == null) {
      return false;
    }
    return entry.dir;
  }

  DirTree get dirtree => io.dirtree;

  StorageIO get storageIO => io;

  List<DirEntry> dirEntries(String path) {
    List<DirEntry> result = [];
    DirTree dt = io.dirtree;
    DirEntry? e = dt.entryByName(path);
    if (e != null && e.dir) {
      int parent = dt.indexOf(e);
      var children = dt.children(parent);
      for (int i = 0; i < children.length; i++) {
        //result.add(dt.entry(children[i]));
        var entry = dt.entry(children[i]);
        if (entry != null) {
          result.add(entry);
        }
      }
    }

    return result;
  }
}

//=================================================================================================
// Stream class for OLE2 file format
//-------------------------------------------------------------------------------------------------
class Stream {
  late StreamIO io;

  Stream(Storage storage, String name) {
    io = storage.io.streamIO(name)!;
  }

  // Returns the full stream name.
  String fullName() => io.fullName;

  // Returns the current read/write position.
  int tell() => io.tell();

  // Sets the read/write position.
  void seek(int newPos) => io.seek(newPos);

  // Returns the stream size.
  int size() => io.entry.size;

  // Reads a byte.
  int getch() => io.getch();

  // Reads a block of data.
  int read(Uint8List data, int maxlen) => io.read(data, maxlen);

  // Returns true if the read/write position is past the file.
  bool eof() => io.eof;

  // Returns true if the last operation failed.
  bool fail() => io.fail;
}
