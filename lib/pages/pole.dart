import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

//=================================================================================================
// signature, or magic identifier
final List<int> poleMagic = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
// Default values
final int signature = 0xE11AB1A1E011CFD0;
final int version = 0x3E; // 62
final int sectorSize = 0x200; // 512
final int shortSectorSize = 0x40; // 64
final int maxBlockSize = 0x1000; // 4096
final int maxBbatCount = 0x80; // 128
final int maxSbatCount = 0x80; // 128
final int initialBlockSize = 0x80; // 128
final int maxSmallBlockSize = 0x100; // 256
// Special block values
final int poleEof = 0xffffffff; //-2;
final int poleAvail = 0xfffffffe; //-1;
final int poleBat = 0xfffffffd; //-3;
final int poleMetaBat = 0xfffffffc; //-4;
final int dirTreeEnd = 0xffffffff;

final int poleCACHEBUFSIZE =
    4096; //a presumably reasonable size for the read cache

//-------------------------------------------------------------------------------------------------
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

/// POLE - Portable Dart library to access OLE Storage
/// Original C++ version by Ariya Hidayat <ariya@kde.org>
/// Ported to Dart

// Header class for OLE2 file format
class Header {
  //final Uint8List id = Uint8List(8); // signature, or magic identifier
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

  Header() {
    init();
  }

  void init() {
    // Initialize header with OLE signature
    for (int i = 0; i < 8; i++) {
      id[i] = poleMagic[i];
    }

    // Set default values
    bShift =
        9; // [1EH,02] size of sectors in power-of-two; typically 9 indicating 512-byte sectors
    sShift =
        6; // [20H,02] size of mini-sectors in power-of-two; typically 6 indicating 64-byte mini-sectors
    threshold =
        4096; // [38H,04] maximum size for a mini stream; typically 4096 bytes

    numBat = 0; // [2CH,04] number of SECTs in the FAT chain
    direntStart = 0; // [30H,04] first SECT in the directory chain
    sbatStart = 0; // [3CH,04] first SECT in the MiniFAT chain
    numSbat = 0; // [40H,04] number of SECTs in the MiniFAT chain
    numMbat = 0; // [48H,04] number of SECTs in the DIFAT chain

    mbatStart = poleEof; // [44H,04] first SECT in the DIFAT chain
    dirty = true;
    // print('Header::Header() 1');
  }

  void initHeader() {
    // for (int i = 0; i < 8; i++) {
    //   id[i] = poleMagic[i];
    // }

    // // Set default values
    // bShift = 9;
    // sShift = 6;
    // threshold = 4096;

    // Initialize parts of the header, directory entries, and big and small allocation tables
    bbBlocks[0] = 0;
    direntStart = 1;
    sbatStart = 2;

    numBat = 1;
    numSbat = 1;
    dirty = true;

    // numMbat = 0;
    // mbatStart = poleEof;
  }

  bool valid() {
    // Check for OLE signature
    // return id[0] == 0xD0 && id[1] == 0xCF && id[2] == 0x11 && id[3] == 0xE0 && id[4] == 0xA1 && id[5] == 0xB1 && id[6] == 0x1A && id[7] == 0xE1;
    if (threshold != 4096) return false;
    if (numBat == 0) return false;
    //if( (numBat > 109) && (numBat > (numMbat * 127) + 109)) return false; // dima: incorrect check, number may be arbitrary larger
    if ((numBat < 109) && (numMbat != 0)) return false;
    if (sShift > bShift) return false;
    if (bShift <= 6) return false;
    if (bShift >= 31) return false;

    return true;
  }

  void load(Uint8List buffer) {
    //print('Header::load() - ${buffer.length} bytes}');
    bShift = _readU16(buffer,
        0x1e); // [1EH,02] size of sectors in power-of-two; typically 9 indicating 512-byte sectors and 12 for 4096
    //print('Header::load() - bShift : $bShift');
    sShift = _readU16(buffer,
        0x20); // [20H,02] size of mini-sectors in power-of-two; typically 6 indicating 64-byte mini-sectors
    //print('Header::load() - sShift : $sShift');

    numBat =
        _readU32(buffer, 0x2c); // [2CH,04] number of SECTs in the FAT chain
    //print('Header::load() - numBat : $numBat');
    direntStart =
        _readU32(buffer, 0x30); // [30H,04] first SECT in the directory chain
    //print('Header::load() - direntStart : $direntStart');
    threshold = _readU32(buffer,
        0x38); // [38H,04] maximum size for a mini stream; typically 4096 bytes
    //print('Header::load() - threshold : $threshold');
    sbatStart =
        _readU32(buffer, 0x3c); // [3CH,04] first SECT in the MiniFAT chain
    //print('Header::load() - sbatStart : $sbatStart');
    numSbat =
        _readU32(buffer, 0x40); // [40H,04] number of SECTs in the MiniFAT chain
    //print('Header::load() - numSbat : $numSbat');
    mbatStart =
        _readU32(buffer, 0x44); // [44H,04] first SECT in the DIFAT chain
    //print('Header::load() - mbatStart : $mbatStart');
    numMbat =
        _readU32(buffer, 0x48); // [48H,04] number of SECTs in the DIFAT chain
    //print('Header::load() - numMbat : $numMbat');

    // Initialize header with OLE signature
    //id.setAll(0, buffer.sublist(0, 8));
    for (int i = 0; i < 8; i++) {
      id[i] = buffer[i];
    }

    // [4CH,436] the SECTs of first 109 FAT sectors
    for (int i = 0; i < 109; i++) {
      bbBlocks[i] = _readU32(buffer, 0x4C + i * 4);
    }
    dirty = false;
  }

  void save(Uint8List buffer) {
    buffer.fillRange(0, buffer.length, 0);

    // root is fixed as "Root Entry"
    for (int i = 0; i < 8; i++) {
      buffer[i] = poleMagic[i]; // ole signature
    }

    _writeU32(buffer, 8, 0); // unknown
    _writeU32(buffer, 12, 0); // unknown
    _writeU32(buffer, 16, 0); // unknown

    _writeU16(buffer, 24, 0x003e); // revision ?
    _writeU16(buffer, 26, 3); // version ?
    _writeU16(buffer, 28, 0xfffe); // unknown
    _writeU16(buffer, 0x1e, bShift);
    _writeU16(buffer, 0x20, sShift);

    _writeU32(buffer, 44, numBat);
    _writeU32(buffer, 48, direntStart);
    _writeU32(buffer, 56, threshold);
    _writeU32(buffer, 60, sbatStart);
    _writeU32(buffer, 64, numSbat);
    _writeU32(buffer, 68, mbatStart);
    _writeU32(buffer, 72, numMbat);

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
      print('    [$i]: ${bbBlocks[i].toString()}');
    }
  }
}

// Allocation Table class for managing block allocation
class AllocTable {
  int blockSize = maxBlockSize;
  final List<int> data = [];
  final List<int> dirtyBlocks = [];
  bool maybeFragmented = true;

  AllocTable() {
    // print('AllocTable::AllocTable() 1 - ');
    blockSize = maxBlockSize;
    maybeFragmented = true;
    // print('AllocTable::AllocTable() 2 - ');
    resize(initialBlockSize);
    // print('AllocTable::AllocTable() 3');
  }

  int operator [](int index) {
    if (index < 0 || index >= data.length) return poleEof;
    return data[index];
  }

  void clear() {
    data.clear();
    dirtyBlocks.clear();
    maybeFragmented = false;
  }

  int count() => data.length;

  int unusedCount() {
    int count = 0;
    for (var value in data) {
      if (value == poleAvail) count++;
    }
    return count;
  }

  void resize(int newsize) {
    //print('AllocTable::resize()  - newsize : $newsize');

    int oldsize = data.length;
    //print('AllocTable::resize()  - 1, data.length: ${data.length}');
    //data.length = newsize;
    //data.take(newsize);

    if (newsize >= oldsize) {
      for (int i = oldsize; i < newsize; i++) {
        //data[i] = poleAvail;
        data.add(poleAvail);
      }
    } else {
      data.removeRange(newsize, oldsize);
    }
    // print(
    //     'AllocTable::resize() - newsize: $newsize, data.length: $oldsize -> ${data.length}');
  }

  void preserve(int n) {
    if (n > data.length) {
      resize(n);
    }
  }

  void set(int index, int value) {
    // if (value != 0) {
    //   print(
    //       'AllocTable::set() - index: $index, value: $value, data.length: ${data.length}');
    // }

    if (index >= data.length) {
      resize(index + 1);
    }
    //data[index] = value;

    if (index >= data.length) {
      data.add(value);
    } else {
      data[index] = value;
    }

    //if (!dirtyBlocks.contains(index)) {
    //  dirtyBlocks.add(index);
    //}
    if (value == poleAvail) {
      maybeFragmented = true;
    }
  }

  void setChain(List<int> chain) {
    for (int i = 0; i < chain.length - 1; i++) {
      set(chain[i], chain[i + 1]);
    }
    set(chain.last, poleEof);
  }

  bool alreadyExists(List<int> chain, int item) {
    return chain.contains(item);
  }

  List<int> follow(int start) {
    // print(
    //     'AllocTable::follow() - start: $start, count(): ${count()}'); //, data[start]: ${data[start]}');
    List<int> chain = [];
    if (start >= count()) return chain;

    int p = start;
    while (p < count()) {
      if (p == poleEof) break;
      if (p == poleBat) break;
      if (p == poleMetaBat) break;
      if (p == -2) break;
      if (p == -3) break;
      if (p == -4) break;
      if (p >= count()) break;
      chain.add(p);
      if (data[p] >= count()) break;
      //  if (alreadyExists(chain, p)) break;
      p = data[p];
      // print('AllocTable::follow() - p: $p, chain.length: ${chain.length}');
    }
    // print(
    //     'AllocTable::follow() - chain: ${chain.length}, data: ${data.length}');
    return chain;
  }

  void load(Uint8List buffer, int len) {
    //clear();
    int maxEntries = len ~/ 4;
    //data.length = maxEntries;
    //data = List.filled(maxEntries, 0);

    resize(maxEntries);

    int res = 0;
    // print(
    //     'AllocTable::load() - buffer: ${buffer.length}, len: $len, maxEntries: $maxEntries, data.length: ${data.length}');

    //data.clear();
    for (int i = 0; i < maxEntries; i++) {
      //data[i] = _readU32(buffer, i * 4);
      //data.add(_readU32(buffer, i * 4));
      res = _readU32(buffer, i * 4);
      //print('AllocTable::load() - [$i]: $res');
      set(i, res);
    }

    // print(
    //     'AllocTable::load() - data.length: ${data.length}, data[0]: ${data[0]}, data[1]: ${data[1]}, data[2]: ${data[2]} ');
  }

  void save(Uint8List buffer) {
    for (int i = 0; i < data.length; i++) {
      _writeU32(buffer, i * 4, data[i]);
    }
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

  int size() => data.length * 4;

  bool isDirty() => dirtyBlocks.isNotEmpty;

  // void markAsDirty(int dataIndex) {
  //   if (dataIndex < 0 || dataIndex >= data.length) {
  //     throw RangeError('Index out of range: $dataIndex');
  //   }
  //   if (!dirtyBlocks.contains(dataIndex)) {
  //     dirtyBlocks.add(dataIndex);
  //   }
  // }
  void markAsDirty(int dataIndex, int bigBlockSize) {
    int dbidx = dataIndex ~/ (bigBlockSize ~/ 4);
    for (int idx = 0; idx < dirtyBlocks.length; idx++) {
      if (dirtyBlocks[idx] == dbidx) return;
    }
    dirtyBlocks.add(dbidx);
  }

  void flush(List<int> blocks, StorageIO io, int bigBlockSize) {}

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

// Directory Entry class for OLE2 file format
class DirEntry {
  bool valid = false;
  String name = '';
  bool dir = false;
  int size = 0;
  int start = 0;
  int prev = 0;
  int next = 0;
  int child = 0;

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
    //print('  type: $type');
    //print('  color: $color');
    //print('  left: $left');
    //print('  right: $right');
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

class DriTreeEntry {
  int index = 0;
  int closest = dirTreeEnd;
}

// Directory Tree class for OLE2 file format
class DirTree {
  static const int end = -1;
  final List<DirEntry> entries = [];
  final List<int> dirtyBlocks = [];
  //final int bigBlockSize;

  DirTree(int bigBlockSize) {
    clear(bigBlockSize);
  }

  void clear(int bigBlockSize) {
    // leave only root entry
    entries.clear();
    //entries.length = 1;
    //entries[0] = DirEntry();
    entries.add(DirEntry());

    entries[0].valid = true;
    entries[0].name = "Root Entry";
    entries[0].dir = true;
    entries[0].size = 0;
    entries[0].start = dirTreeEnd;
    entries[0].prev = dirTreeEnd;
    entries[0].next = dirTreeEnd;
    entries[0].child = dirTreeEnd;

    dirtyBlocks.clear();
    dirtyBlocks.add(bigBlockSize);
    //markAsDirty(0, bigBlockSize);
  }

  int entryCount() => entries.length;

  // return space required to save this dirtree
  int size() => entryCount() * 128;

  int unusedEntryCount() {
    int count = 0;
    for (var entry in entries) {
      if (!entry.valid) count++;
    }
    return count;
  }

  int unused() {
    for (int idx = 0; idx < entryCount(); idx++) {
      if (!entries[idx].valid) {
        return idx;
      }
    }
    entries.add(DirEntry());
    return entryCount() - 1;
  }

  DirEntry? entry(int index) {
    // print(
    //     'DirEntry::entry() - index: $index, entries.length: ${entries.length}');

    if (index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  int indexOf(DirEntry? e) {
    for (int i = 0; i < entryCount(); i++) {
      if (entry(i) == e) {
        return i;
      }
    }
    return -1;
  }

  int parent(int index) {
    if (index < 0 || index >= entries.length) return -1;

    // brute-force, basically we iterate for each entries, find its children
    // and check if one of the children is 'index'
    for (int j = 0; j < entryCount(); j++) {
      List<int> chi = children(j);
      for (int i = 0; i < chi.length; i++) {
        if (chi[i] == index) {
          return j;
        }
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

  DirEntry? entryByName(String name,
      {bool create = false,
      int bigBlockSize = 0,
      StorageIO? io,
      int streamSize = 0}) {
    //print('DirEntry::entryByName() - name: $name');

    if (name.isEmpty) {
      //print('DirEntry::entryByName() - name: $name isEmpty !!!!!');
      return null;
    }

    // quick check for "/" (that's root)
    if (name == '/') {
      //print('DirEntry::entryByName() - name: $name !!!!!');
      return entry(0);
    }

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
      //String entryName = names[i];
      //if (entryName.isEmpty) continue;

      // Find child with matching name
      DriTreeEntry treeEntry = DriTreeEntry();
      //treeEntry.closest = dirTreeEnd;
      int childIndex = findChild(index, names[i], treeEntry);

      // print(
      //     'DirEntry::entryByName()  [$i] index: $index, name: ${names[i]}, childIndex: $childIndex, treeEntry.closest: ${treeEntry.closest}');

      // traverse to the child
      if (childIndex > 0) {
        index = childIndex;
      } else {
        // not found among children
        if (!create || (io?.writeable ?? false)) return null;

        // create a new entry
        int parent2 = index;
        index = unused();
        DirEntry? e = entry(index);
        if (e != null) {
          e.valid = true;
          e.name = names[i];
          e.dir = (i < names.length - 1);
          if (e.dir) {
            e.size = 0;
          } else {
            e.size = streamSize;
          }
          e.start = poleEof;
          e.child = DirTree.end;
          if (treeEntry.closest == dirTreeEnd) {
            e.prev = DirTree.end;
            e.next = entry(parent2)?.child ?? DirTree.end;
          } else {
            DirEntry? closeE = entry(treeEntry.closest);
            if (closeE != null) {
              if (closeE.compare(e) < 0) {
                e.prev = closeE.next;
                e.next = DirTree.end;
                closeE.next = index;
              } else {
                e.next = closeE.prev;
                e.prev = DirTree.end;
                closeE.prev = index;
              }
            }
            markAsDirty(treeEntry.closest, bigBlockSize);
          }
        }
        markAsDirty(index, bigBlockSize);

        int bbidx = (index ~/ (bigBlockSize ~/ 128));
        if (io != null) {
          List<int> blocks = io.bbat.follow(io.header.direntStart);
          while (blocks.length <= bbidx) {
            int nblock = io.bbat.unused();
            if (blocks.isNotEmpty) {
              io.bbat.set(blocks[blocks.length - 1], nblock);
              io.bbat.markAsDirty(blocks[blocks.length - 1], bigBlockSize);
            }
            io.bbat.set(nblock, poleEof);
            io.bbat.markAsDirty(nblock, bigBlockSize);
            blocks.add(nblock);
            int newBbidx = nblock ~/ (io.bbat.blockSize ~/ 8);
            while (newBbidx >= io.header.numBat) {
              io.addbbatBlock();
            }
          }
        }
      }
    }

    return entry(index);
  }

  // helper function: recursively find siblings of index
  void findSiblings(DirTree? dirtree, List<int>? result, int index) {
    DirEntry? e = dirtree?.entry(index);
    if (e == null) return;

    if (e.prev != dirTreeEnd) findSiblings(dirtree, result, e.prev);
    result?.add(index);
    if (e.next != dirTreeEnd) findSiblings(dirtree, result, e.next);
  }

  List<int> children(int index) {
    List<int> result = [];
    if (index < 0 || index >= entries.length) return result;

    DirEntry? e = entry(index);
    if (e != null && e.valid && e.child < entryCount()) {
      findSiblings(this, result, e.child);
    }
    return result;
  }

  int findSibling(
      DirTree? dirtree, int index, String name, DriTreeEntry? treeEntry) {
    if (dirtree == null) return 0;

    int count = dirtree.entryCount();
    DirEntry? e = dirtree.entry(index);
    if (e == null || !e.valid) return 0;

    int cval = e.compareName(name);
    if (cval == 0) return index;

    if (cval > 0) {
      if (e.prev > 0 && e.prev < count) {
        return findSibling(dirtree, e.prev, name, treeEntry);
      }
    } else {
      if (e.next > 0 && e.next < count) {
        return findSibling(dirtree, e.next, name, treeEntry);
      }
    }
    //treeEntry?.index = index;
    treeEntry?.closest = index;
    return 0;
  }

  int findChild(int index, String name, DriTreeEntry? treeEntry) {
    int count = entryCount();
    DirEntry? p = entry(index);

    // if (p != null) {
    //   print(
    //       'DirEntry::findChild() - index: $index, name: $name, p.valid: ${p.valid}, p.child: ${p.child}');
    // } else {
    //   print(
    //       'DirEntry::findChild() - index: $index, name: $name, DirEntry null !!!!!!');
    // }

    if (p != null && p.valid && p.child < count) {
      return findSibling(this, p.child, name, treeEntry);
    }

    return 0;
  }

  void load(Uint8List buffer, int len) {
    // print('DirEntry::load() - buffer.length: ${buffer.length}, len: $len');

    entries.clear();

    int maxEntries = len ~/ 128;
    //entries.length = maxEntries;

    for (int i = 0; i < maxEntries; i++) {
      int offset = i * 128;

      // would be < 32 if first char in the name isn't printable
      int prefix = 32;

      // Read name (first 64 bytes)
      // int nameLen = 0;
      // while (nameLen < 64 && buffer[offset + nameLen] != 0) {
      //   nameLen++;
      // }
      // String name = String.fromCharCodes(buffer.sublist(offset, offset + nameLen));

      // parse name of this entry, which stored as Unicode 16-bit
      String name = '';
      int nameLen = _readU16(buffer, 0x40 + offset);
      if (nameLen > 64) nameLen = 64;
      // print('DirEntry::load() - nameLen: $nameLen');

      for (int j = 0; j < nameLen && buffer[j + offset] != 0; j += 2) {
        name += String.fromCharCode(buffer[j + offset]);
      }
      // print('DirEntry::load() - 1 name: $name');

      // first char isn't printable ? remove it...
      if (nameLen > 0 && buffer[offset] < 32) {
        prefix = buffer[0];
        name = name.substring(1);
      }
      // print('DirEntry::load() - name: $name');

      // 2 = file (aka stream), 1 = directory (aka storage), 5 = root
      int type = buffer[0x42 + offset];
      //print('DirEntry::load() - type: $type, name: $name');

      var e = DirEntry();
      e.valid = (type != 0); // buffer[offset + 0x42] != 0;
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

      // print(
      //     'DirEntry::load() - type: $type, name: $name \n\t valid: ${e.valid},\n\t dir: ${e.dir},\n\t start: ${e.start},\n\t size: ${e.size},\n\t prev: ${e.prev},\n\t next: ${e.next},\n\t child: ${e.child}');

      // There is a space at the last. Parsing을 못한건지 확인 해야함.
      if (type != 0 && name.isNotEmpty) {
        //entries[i] = e;
        entries.add(e);
      }
    }
  }

  void save(Uint8List buffer) {
    // for (int i = 0; i < size(); i++) {
    //   buffer[i] = 0;
    // }
    buffer.fillRange(0, buffer.length, 0);

    // root is fixed as "Root Entry"
    DirEntry root = entry(0)!;

    String name = "Root Entry";
    for (int i = 0; i < name.length; i++) {
      buffer[i * 2] = name.codeUnitAt(i);
    }

    _writeU16(buffer, 0x40, name.length * 2 + 2);

    _writeU32(buffer, 0x74, DirTree.end); // 0xffffffff
    _writeU32(buffer, 0x78, 0);
    _writeU32(buffer, 0x44, DirTree.end); // 0xffffffff
    _writeU32(buffer, 0x48, DirTree.end); // 0xffffffff
    _writeU32(buffer, 0x4c, root.child);

    buffer[0x42] = 5;
    //buffer[0x43] = 1;

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

      if (!e.valid) {
        buffer[offset + 0x42] = 0; // STGTY_INVALID
      } else {
        buffer[offset + 0x42] = e.dir ? 1 : 2; // STGTY_STREAM or STGTY_STORAGE
      }

      // Write other fields
      _writeU16(buffer, offset + 0x40, name.length * 2 + 2);

      _writeU32(buffer, offset + 0x74, e.start);
      _writeU32(buffer, offset + 0x78, e.size);
      _writeU32(buffer, offset + 0x44, e.prev);
      _writeU32(buffer, offset + 0x48, e.next);
      _writeU32(buffer, offset + 0x4c, e.child);
    }
  }

  bool isDirty() => dirtyBlocks.isNotEmpty;

  void markAsDirty(int dataIndex, int bigBlockSize) {
    print('DirTree::markAsDirty()');

    int dbidx = dataIndex ~/ (bigBlockSize ~/ 4);
    for (int idx = 0; idx < dirtyBlocks.length; idx++) {
      if (dirtyBlocks[idx] == dbidx) {
        return;
      }
    }

    if (!dirtyBlocks.contains(dbidx)) {
      dirtyBlocks.add(dbidx);
    }
  }

  void flush(List<int> blocks, StorageIO io, int bigBlockSize, int sbStart,
      int sbSize) {}

  void findParentAndSib(
      int inIdx, String inFullName, int parentIdx, int sibIdx) {}
  int findSib(int inIdx, int sibIdx) {
    return 0;
  }

  void deleteEntry(DirEntry dirToDel, String inFullName, int bigBlockSize) {
    int parentIdx = 0;
    int sibIdx = 0;
    int inIdx = indexOf(dirToDel);
    int nEntries = entryCount();

    findParentAndSib(inIdx, inFullName, parentIdx, sibIdx);
    int replIdx = 0;

    if (dirToDel.next == 0 || dirToDel.next > nEntries) {
      replIdx = dirToDel.prev;
    } else {
      DirEntry? sibNext = entry(dirToDel.next);
      if (sibNext != null && (sibNext.prev == 0 || sibNext.prev > nEntries)) {
        replIdx = dirToDel.next;
        sibNext.prev = dirToDel.prev;
        markAsDirty(replIdx, bigBlockSize);
      } else {
        DirEntry? smlSib = sibNext;
        int smlIdx = dirToDel.next;
        DirEntry? smlrSib;
        int smlrIdx = -1;
        while (true) {
          if (smlSib == null) break;
          smlrIdx = smlSib.prev;
          smlrSib = entry(smlrIdx);
          if (smlrSib == null || smlrSib.prev == 0 || smlrSib.prev > nEntries) {
            break;
          }
          smlSib = smlrSib;
          smlIdx = smlrIdx;
        }
        if (smlSib != null && smlrSib != null) {
          replIdx = smlSib.prev;
          smlSib.prev = smlrSib.next;
          smlrSib.prev = dirToDel.prev;
          smlrSib.next = dirToDel.next;
          markAsDirty(smlIdx, bigBlockSize);
          markAsDirty(smlrIdx, bigBlockSize);
        }
      }
    }
    if (sibIdx != 0) {
      DirEntry? sib = entry(sibIdx);
      if (sib != null) {
        if (sib.next == inIdx) {
          sib.next = replIdx;
        } else {
          sib.prev = replIdx;
        }
        markAsDirty(sibIdx, bigBlockSize);
      }
    } else {
      DirEntry? parNode = entry(parentIdx);
      if (parNode != null) {
        parNode.child = replIdx;
        markAsDirty(parentIdx, bigBlockSize);
      }
    }
    dirToDel.valid = false; //indicating that this entry is not in use
    markAsDirty(inIdx, bigBlockSize);
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

// Storage I/O class for OLE2 file format
class StorageIO {
  final Storage storage;
  final String filename;

  //late File file;
  late RandomAccessFile raf;

  int result = Storage.ok;
  bool opened = false;
  int filesize = 0;
  bool writeable = false;

  late Header header;
  late DirTree dirtree;
  late AllocTable bbat;
  late AllocTable sbat;

  final List<int> sbBlocks = [];
  final List<int> mbatBlocks = [];
  final List<int> mbatData = [];
  bool mbatDirty = false;

  final List<Stream> streams = [];

  StorageIO({required Storage pole, required String fname})
      : storage = pole,
        filename = fname {
    // print('StorageIO::StorageIO() - filename: $filename');

    //file = File();
    header = Header();
    // print('StorageIO::StorageIO() 1 - filename: $filename');
    dirtree = DirTree(header.bShift);
    // print('StorageIO::StorageIO() 2 - filename: $filename');
    bbat = AllocTable();
    // print('StorageIO::StorageIO() 3 - filename: $filename');
    sbat = AllocTable();
    // print('StorageIO::StorageIO() 4 - filename: $filename');

    // print('StorageIO::StorageIO() 5 - filename: $filename');
    bbat.blockSize = 1 << header.bShift;
    sbat.blockSize = 1 << header.sShift;
    // print('StorageIO::StorageIO() 6 - filename: $filename');
  }

  Future<bool> open({bool writeAccess = false, bool create = false}) async {
    // print('StorageIO::open() - writeAccess: $writeAccess, create: $create');
    try {
      close();

      File file = File(filename);
      if (!await file.exists() && !create) {
        print('StorageIO::open() - file.exists(): openFailed');
        result = Storage.openFailed;
        return false;
      }

      if (create) {
        await file.create(recursive: true);
      }

      raf = await file.open(mode: writeAccess ? FileMode.write : FileMode.read);
      opened = true;
      writeable = writeAccess;

      // find size of input file
      filesize = await file.length();
      // print('StorageIO::open() - filesize: $filesize');

      if (create) {
        init();
      } else {
        await load(writeAccess);
      }

      result = Storage.ok;
      return true;
    } catch (e) {
      print('StorageIO::open() error - $errorPropertyTextConfiguration');
      close();

      result = Storage.openFailed;
      return false;
    }
  }

  Future<void> close() async {
    // print('StorageIO::close() - opened: $opened');
    if (opened) {
      await raf.close();
      streams.clear();
      opened = false;
    }
  }

  void init() {
    // Initialize parts of the header, directory entries, and big and small allocation tables
    header.initHeader();
    for (int i = 0; i < 4; i++) {
      bbat.set(i, poleEof);
      bbat.markAsDirty(i, bbat.blockSize);
    }
    sbBlocks.clear();
    sbBlocks.addAll(bbat.follow(3));
    mbatDirty = false;
  }

  Future<void> load(bool writeAccess) async {
    // print('StorageIO::load() - writeAccess: $writeAccess');

    // open the file, check for error
    result = Storage.openFailed;

    // Read header
    Uint8List buffer1 = Uint8List(512); // or filesize
    await raf.setPosition(0);
    int bytesRead = await raf.readInto(buffer1);
    if (bytesRead != 512) {
      result = Storage.badOLE;
      print('StorageIO::load() - badOLE !!! 512');
      return;
    }

    // print(
    //     'StorageIO::load() - load header !!! ${buffer1.length}, bytesRead: $bytesRead');
    header.load(buffer1);
    // check OLE magic id
    result = Storage.notOLE;
    for (int i = 0; i < 8; i++) {
      if (header.id[i] != poleMagic[i]) {
        print('StorageIO::load() - notOLE !!! poleMagic');
        return;
      }
    }

    // sanity checks
    // print('StorageIO::load() - sanity checks');
    result = Storage.badOLE;
    if (!header.valid()) {
      print('StorageIO::load() - badOLE !!! header.valid()');
      return;
    }
    if (header.threshold != 4096) {
      print('StorageIO::load() - badOLE !!! header.threshold');
      return;
    }

    // important block size
    // print(
    //     'StorageIO::load() - important block size !!! header.bShift: ${header.bShift}, header.sShift: ${header.sShift}, bbat.blockSize: ${bbat.blockSize}, sbat.blockSize: ${sbat.blockSize}');

    bbat.blockSize = 1 << header.bShift;
    sbat.blockSize = 1 << header.sShift;

    // print(
    //     'StorageIO::load() - important block size !!! bbat.blockSize: ${bbat.blockSize}, sbat.blockSize: ${sbat.blockSize}');

    List<int> blocks1 = await getbbatBlocks(true);

    // load big bat
    // print('StorageIO::load() - load big bat !!!');
    int buflen = blocks1.length * bbat.blockSize;
    Uint8List buffer2 = Uint8List(buflen); // or filesize
    if (buflen > 0) {
      // print(
      //     'StorageIO::load() - load big bat !!! 1, buffer2.length: ${buffer2.length}, buflen: $buflen');
      //buffer.clear();
      // for (int c = 0; c < 512; c++) {
      //   buffer[c] = 0;
      // }
      // print('StorageIO::load() - load big bat !!! 2');

      //buffer.length = buflen;
      //buffer = Uint8List(buflen);
      int bytes = await loadBigBlocks(blocks1, buffer2, buflen);
      // print(
      //     'StorageIO::load() - loadBigBlocks !!! bytes: $bytes, buffer2: ${buffer2[0]}, ${buffer2[1]}, ${buffer2[2]}, ${buffer2[3]}, ${buffer2[4]}, ${buffer2[5]}, ${buffer2[6]}, ${buffer2[7]}');

      bbat.load(buffer2, buflen);
      // print('StorageIO::load() - load big bat !!! 3 ${buffer2.length}');
    }

    // load small bat
    // print('StorageIO::load() - load small bat !!! ');

    //blocks.clear();
    List<int> blocks2 = bbat.follow(header.sbatStart);
    buflen = blocks2.length * bbat.blockSize;
    Uint8List buffer3 = Uint8List(buflen); // or filesize
    if (buflen > 0) {
      // print(
      //     'StorageIO::load() - load small bat !!! 1, buffer3.length: ${buffer3.length}, buflen: $buflen');
      //buffer.clear();
      // for (int c = 0; c < 512; c++) {
      //   buffer[c] = 0;
      // }

      //buffer.length = buflen;
      //buffer = Uint8List(buflen);
      int bytes = await loadBigBlocks(blocks2, buffer3, buflen);
      // print(
      //     'StorageIO::load() - loadBigBlocks !!! bytes: $bytes, buffer3: ${buffer3[0]}, ${buffer3[1]}, ${buffer3[2]}, ${buffer3[3]}, ${buffer3[4]}, ${buffer3[5]}, ${buffer3[6]}, ${buffer3[7]}');

      sbat.load(buffer3, buflen);
      // print('StorageIO::load() - load small bat !!! 3 ${buffer3.length}');
    }

    // load directory tree
    // print(
    //     'StorageIO::load() - load directory tree !!! header.direntStart: ${header.direntStart}, bbat.blockSize: ${bbat.blockSize}');

    //blocks.clear();
    // for (int c = 0; c < 512; c++) {
    //   buffer[c] = 0;
    // }

    List<int> blocks3 = bbat.follow(header.direntStart);
    buflen = blocks3.length * bbat.blockSize;
    Uint8List buffer4 = Uint8List(buflen); // or filesize

    // print(
    //     'StorageIO::load() - load loadBigBlocks !!! blocks: ${blocks3.length}, ${bbat.blockSize}');
    //buffer.clear();
    // for (int c = 0; c < 512; c++) {
    //   buffer[c] = 0;
    // }
    // print('StorageIO::load() - loadBigBlocks !!! buffer.clear() !!!');

    //buffer.length = buflen;
    //buffer = Uint8List(buflen);
    int bytes = await loadBigBlocks(blocks3, buffer4, buflen);
    // print('StorageIO::load() - loadBigBlocks !!! bytes: $bytes');

    dirtree.load(buffer4, buflen);
    // print('StorageIO::load() - loadBigBlocks !!! buffer: ${buffer4.length}');

    //int sbStart = _readU32(buffer, 0x74);

    // fetch block chain as data for small-files
    // print('StorageIO::load() - fetch block chain as data for small-files !!!');
    sbBlocks.clear();

    int sbStart = _readU32(buffer4, 0x74);
    // print('StorageIO::load() - sbStart: $sbStart');

    //sbBlocks.addAll(bbat.follow(sbStart)); // small files
    sbBlocks.addAll(bbat.follow(sbStart)); // small files
    // print('StorageIO::load() - sbBlocks: ${sbBlocks.length}');

    // for troubleshooting, just enable this block
    // header.debug();
    // sbat.debug();
    // bbat.debug();
    // dirtree.debug();

    // so far so good
    result = Storage.ok;
    opened = true;
  }

  Future<void> flush() async {
    if (header.dirty) {
      Uint8List buffer = Uint8List(512);
      header.save(buffer);
      await raf.setPosition(0);
      await raf.writeFrom(buffer);
    }

    if (bbat.isDirty()) await flushbbat();
    if (sbat.isDirty()) await flushsbat();

    if (dirtree.isDirty()) {
      List<int> blocks = bbat.follow(header.direntStart);
      int sbStart = 0xffffffff;
      if (sbBlocks.isNotEmpty) sbStart = sbBlocks[0];
      dirtree.flush(blocks, this, bbat.blockSize, sbStart, bbat.blockSize);
    }

    if (mbatDirty && mbatBlocks.isNotEmpty) {
      int nBytes = bbat.blockSize * mbatBlocks.length;
      Uint8List buffer = Uint8List(nBytes);
      int sIdx = 0;
      int dcount = 0;
      int blockCapacity = bbat.blockSize ~/ 8 - 1; // sizeof(int) = 8 Bytes
      int blockIdx = 0;
      for (int mdIdx = 0; mdIdx < mbatData.length; mdIdx++) {
        _writeU32(buffer, sIdx, mbatData[mdIdx]);
        sIdx += 4;
        dcount++;
        if (dcount == blockCapacity) {
          blockIdx++;
          if (blockIdx == mbatBlocks.length) {
            _writeU32(buffer, sIdx, poleEof);
          } else {
            _writeU32(buffer, sIdx, mbatBlocks[blockIdx]);
          }
          sIdx += 4;
          dcount = 0;
        }
      }
      await saveBigBlocks(mbatBlocks, 0, buffer, nBytes);
      mbatDirty = false;
    }
    await raf.flush();

    /* Note on Microsoft implementation:
       - directory entries are stored in the last block(s)
       - BATs are as second to the last
       - Meta BATs are third to the last  
    */
  }

  StreamIO? streamIO(String name, bool bCreate, int streamSize) {
    //print('streamIO::streamIO() 1 - name: $name');
    // sanity check
    if (name.isEmpty) return null;

    // search in the entries
    DirEntry? entry = dirtree.entryByName(name,
        create: bCreate,
        bigBlockSize: bbat.blockSize,
        io: this,
        streamSize: streamSize);
    if (entry == null) {
      //print('streamIO::streamIO() 2 - name: $name, entry null !!!');
      return null;
    }
    if (entry.dir) {
      // print(
      //     'streamIO::streamIO() 3 - name: $name, entry.dir: ${entry.dir} !!!');
      return null;
    }

    StreamIO? result2 = StreamIO(storage: this, dirEntry: entry);
    result2.fullName = name;

    // print('streamIO::streamIO() 4 - name: $name');
    return result2;
  }

  Future<void> flushbbat() async {
    List<int> blocks = await getbbatBlocks(false);
    bbat.flush(blocks, this, bbat.blockSize);
  }

  Future<void> flushsbat() async {
    List<int> blocks = bbat.follow(header.sbatStart);
    sbat.flush(blocks, this, bbat.blockSize);
  }

  Future<bool> deleteByName(String fullName) async {
    if (fullName.isEmpty) return false;
    if (!writeable) return false;

    DirEntry? entry = dirtree.entryByName(fullName);
    if (entry == null) return false;

    bool retVal;
    if (entry.dir) {
      retVal = await deleteNode(entry, fullName);
    } else {
      retVal = deleteLeaf(entry, fullName);
    }

    if (retVal) flush();
    return retVal;
  }

  Future<bool> deleteNode(DirEntry entry, String fullName) async {
    String lclName = fullName;
    if (!lclName.endsWith('/')) {
      lclName += '/';
    }
    bool retVal = true;

    while (entry.child != DirTree.end && entry.child < dirtree.entryCount()) {
      DirEntry? childEnt = dirtree.entry(entry.child);
      if (childEnt == null) break;

      String childFullName = lclName + childEnt.name;
      if (childEnt.dir) {
        retVal = await deleteNode(childEnt, childFullName);
      } else {
        retVal = deleteLeaf(childEnt, childFullName);
      }
      if (!retVal) {
        return false;
      }
    }

    dirtree.deleteEntry(entry, fullName, bbat.blockSize);
    return retVal;
  }

  bool deleteLeaf(DirEntry entry, String fullName) {
    List<int> blocks;
    if (entry.size >= header.threshold) {
      blocks = bbat.follow(entry.start);
      for (int idx = 0; idx < blocks.length; idx++) {
        bbat.set(blocks[idx], poleAvail);
        bbat.markAsDirty(idx, bbat.blockSize);
      }
    } else {
      blocks = sbat.follow(entry.start);
      for (int idx = 0; idx < blocks.length; idx++) {
        sbat.set(blocks[idx], poleAvail);
        sbat.markAsDirty(idx, bbat.blockSize);
      }
    }
    dirtree.deleteEntry(entry, fullName, bbat.blockSize);
    return true;
  }

  Future<List<int>> getbbatBlocks(bool bLoading) async {
    // print(
    //     'StorageIO::getbbatBlocks() - bLoading $bLoading, header.numBat ${header.numBat}');
    //List<int> blocks = [];
    //List<int> blocks = List.filled(header.numBat, 0);

    // find blocks allocated to store big bat
    // the first 109 blocks are in header, the rest in meta bat
    //blocks.clear();

    List<int> blocks = List.filled(header.numBat, 0);

    // print('StorageIO::getbbatBlocks() - blocks.length ${blocks.length}');

    //blocks.length = header.numBat;
    for (int i = 0; i < 109; i++) {
      if (i >= header.numBat) break;
      if (i >= blocks.length) {
        blocks.add(header.bbBlocks[i]);
      } else {
        blocks[i] = header.bbBlocks[i];
      }
      // print('StorageIO::getbbatBlocks() - blocks[$i]: ${blocks[i]}');
    }

    if (bLoading) {
      mbatBlocks.clear();
      mbatData.clear();

      if ((header.numBat > 109) && (header.numMbat > 0)) {
        Uint8List buffer = Uint8List(bbat.blockSize);
        int idx = 109;
        int sector = 0;
        int mdidx = 0;
        for (int i = 0; i < header.numMbat; i++) {
          if (i == 0) {
            // 1st meta bat location is in file header.
            sector = header.mbatStart;
          } else {
            // next meta bat location is the last current block value.
            sector = blocks[--idx];
            mdidx--;
          }

          mbatBlocks.add(sector);
          int mdataLen = mbatBlocks.length * (bbat.blockSize ~/ 4);
          if (mdataLen >= mbatData.length) {
            for (int i = mbatData.length; i < mdataLen; i++) {
              mbatData.add(0);
            }
          } else {
            mbatData.removeRange(mdataLen, mbatData.length);
          }

          await loadBigBlock(sector, buffer, bbat.blockSize);
          for (int s = 0; s < bbat.blockSize; s += 4) {
            if (idx >= header.numBat) {
              break;
            } else {
              blocks[idx] = _readU32(buffer, s);
              if (mdidx >= mbatData.length) {
                mbatData.add(blocks[idx]);
              } else {
                mbatData[mdidx] = blocks[idx];
              }
              mdidx++;
              idx++;
            }
          }
        }
        if (mbatData.length != mdidx) {
          //mbatData.length = mdidx;
          //mbatData.take(mdidx);
          // for (int md = mbatData.length; md < mdidx; md++) {
          //   mbatData.add(0);
          // }
          if (mdidx >= mbatData.length) {
            for (int i = mbatData.length; i < mdidx; i++) {
              mbatData.add(0);
            }
          } else {
            mbatData.removeRange(mdidx, mbatData.length);
          }
        }
      }
    } else {
      int i = 109;
      for (int idx = 0; idx < mbatData.length; idx++) {
        //blocks[i] = mbatData[idx];
        if (i >= blocks.length) {
          blocks.add(mbatData[idx]);
        } else {
          blocks[i] = mbatData[idx];
        }

        if (++i == header.numBat) {
          break;
        }
      }
    }

    // print('StorageIO::getbbatBlocks() End - blocks.length ${blocks.length}');
    return blocks;
  }

  Future<int> loadBigBlocks(
      List<int> blocks, Uint8List data, int maxlen) async {
    // print(
    //     'StorageIO::loadBigBlocks() - filesize: $filesize, blocks.length: ${blocks.length}, data.length: ${data.length}, maxlen: $maxlen');

    // sentinel
    if (blocks.isEmpty) {
      return 0;
    }
    if (maxlen == 0) return 0;

    // read block one by one, seems fast enough
    int bytes = 0;
    int res = 0;

    //Uint8List buffer = Uint8List(maxlen); // or filesize
    //await raf.setPosition(0);
    //int bytesRead = await raf.readInto(buffer1);

    for (int i = 0; (i < blocks.length) && (bytes < maxlen); i++) {
      int block = blocks[i];
      int pos = bbat.blockSize * (block + 1);
      int p =
          (bbat.blockSize < maxlen - bytes) ? bbat.blockSize : maxlen - bytes;
      if (pos + p > filesize) p = filesize - pos;

      // await raf.setPosition(pos);
      // //res = await raf.readInto(data.sublist(bytes, bytes + p));
      // //await raf.readInto(data.sublist(bytes, p));
      // res = await raf.readInto(buffer.sublist(bytes, bytes + p));

      // print(
      //     'StorageIO::loadBigBlocks() - [$i] [$res] block: $block, pos: $pos, bytes: $bytes, p: $p,  bbat.blockSize: ${bbat.blockSize}');

      Uint8List buffer = Uint8List(p);
      await raf.setPosition(pos);
      res = await raf.readInto(buffer); // or filesize

      data.setRange(bytes, bytes + p, buffer);

      // // print(
      // //     'StorageIO::loadBigBlocks() - [$i] [$res] block: $block, pos: $pos, bytes: $bytes, p: $p,  bbat.blockSize: ${bbat.blockSize}');

      // print(
      //     'StorageIO::loadBigBlocks() - [$i] block: $block, pos: $pos, p: $p, bytes: $bytes');

      // // print(
      // //     'StorageIO::loadBigBlocks() - [$i] block: $block, pos: $pos, p: $p, bytes: $bytes, buffer: ${buffer[0]}, ${buffer[1]}, ${buffer[2]}, ${buffer[3]}, ${buffer[4]}, ${buffer[5]}, ${buffer[6]}, ${buffer[7]}');

      bytes += p;
    }

    // print(
    //     'StorageIO::loadBigBlocks() - bytes: $bytes, data: ${data[0]}, ${data[1]}, ${data[2]}, ${data[3]}, ${data[4]}, ${data[5]}, ${data[6]}, ${data[7]}');
    return bytes;
  }

  Future<int> loadBigBlock(int block, Uint8List data, int maxlen) async {
    // wraps call for loadBigBlocks
    List<int> blocks = [];
    //blocks.length = 1;
    blocks.add(0);
    blocks[0] = block;
    return await loadBigBlocks(blocks, data, maxlen);
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
    //blockList.length = 1;
    blockList.add(0);
    blockList[0] = block;
    return loadSmallBlocks(blockList, data, maxlen);
  }

  Future<int> saveBigBlocks(
      List<int> blocks, int offset, Uint8List? data, int len) async {
    // sentinel
    if (data == null) return 0;
    if (blocks.isEmpty) return 0;
    if (len == 0) return 0;

    // write block one by one, seems fast enough
    int bytes = 0;
    for (int i = 0; (i < blocks.length) && (bytes < len); i++) {
      int block = blocks[i];
      int pos = (bbat.blockSize * (block + 1)) + offset;
      int maxWrite = bbat.blockSize - offset;
      int tobeWritten = len - bytes;
      if (tobeWritten > maxWrite) tobeWritten = maxWrite;
      await raf.setPosition(pos);
      await raf.writeFrom(data.sublist(bytes, bytes + tobeWritten));

      bytes += tobeWritten;
      offset = 0;
      if (filesize < pos + tobeWritten) filesize = pos + tobeWritten;
    }

    return bytes;
  }

  Future<int> saveBigBlock(
      int block, int offset, Uint8List? data, int len) async {
    if (data == null) return 0;

    //wrap call for saveBigBlocks
    List<int> blocks = [];
    //blocks.length = 1;
    blocks.add(0);
    blocks[0] = block;
    return await saveBigBlocks(blocks, offset, data, len);
  }

  Future<int> allocateBigBlock() async {
    // Find first poleAvailable block
    for (int i = 0; i < bbat.count(); i++) {
      if (bbat[i] == poleAvail) {
        bbat.set(i, poleEof);
        return i;
      }
    }

    // No poleAvailable blocks, extend file
    int block = bbat.count();
    bbat.resize(block + 1);
    bbat.set(block, poleEof);

    // Write empty block
    var emptyBlock = Uint8List(1 << header.bShift);
    await raf.setPosition((block + 1) << header.bShift);
    await raf.writeFrom(emptyBlock);

    return block;
  }

  Future<int> allocateSmallBlock() async {
    // Find first poleAvailable block
    for (int i = 0; i < sbat.count(); i++) {
      if (sbat[i] == poleAvail) {
        sbat.set(i, poleEof);
        return i;
      }
    }

    // No poleAvailable blocks, allocate new big block for small blocks
    int bigBlock = await allocateBigBlock();
    if (bigBlock == poleEof) return poleEof;

    // Initialize small blocks in the new big block
    int smallBlockSize = 1 << header.sShift;
    int blocksPerBigBlock = (1 << header.bShift) ~/ smallBlockSize;

    int startBlock = sbat.count();
    sbat.resize(startBlock + blocksPerBigBlock);

    for (int i = 0; i < blocksPerBigBlock; i++) {
      sbat.set(startBlock + i, poleAvail);
    }

    // Mark first block as used
    sbat.set(startBlock, poleEof);
    return startBlock;
  }

  Future<List<int>> allocateBlocks(int count, bool small) async {
    List<int> blocks = [];
    for (int i = 0; i < count; i++) {
      int block = small ? await allocateSmallBlock() : await allocateBigBlock();
      if (block == poleEof) break;
      blocks.add(block);
    }
    return blocks;
  }

  Future<void> freeBlocks(List<int> blocks, bool small) async {
    var table = small ? sbat : bbat;
    for (var block in blocks) {
      if (block >= 0 && block < table.count()) {
        table.set(block, poleAvail);
      }
    }
  }

  int ExtendFile(List<int>? chain) {
    int newblockIdx = bbat.unused();

    return newblockIdx;
  }

  void addbbatBlock() {
    int newblockIdx = bbat.unused();
    bbat.set(newblockIdx, poleMetaBat);

    if (header.numBat < 109) {
      header.bbBlocks[header.numBat] = newblockIdx;
    } else {
      mbatDirty = true;
      mbatData.add(newblockIdx);
      int metaIdx = header.numBat - 109;
      int idxPerBlock =
          bbat.blockSize ~/ 8 - 1; //reserve room for index to next block
      int idxBlock = metaIdx ~/ idxPerBlock;

      if (idxBlock == mbatBlocks.length) {
        int newmetaIdx = bbat.unused();
        bbat.set(newmetaIdx, poleMetaBat);
        mbatBlocks.add(newmetaIdx);
        if (header.numMbat == 0) header.mbatStart = newmetaIdx;
        header.numMbat++;
      }
    }
    header.numBat++;
    header.dirty = true;
  }

  void debug() {
    print('Storage:');
    print('  FileName: $filename');
    print('  Writeable: $writeable');
    print('  Block Size: ${1 << header.bShift}');
    print('  Small Block Size: ${1 << header.sShift}');
    print('  Threshold: ${header.threshold}');
    print('  Is Open: $opened');
    header.debug();
    bbat.debug();
    sbat.debug();
    dirtree.debug();
    print('  sbBlocks: ${sbBlocks.take(10).toList()} ...');
    print('  mbatBlocks: ${mbatBlocks.take(10).toList()} ...');
    print('  mbatData: ${mbatData.take(10).toList()} ...');
    print('  mbatDirty: $mbatDirty');
  }
}

// Stream I/O class for OLE2 file format
class StreamIO {
  final StorageIO io;
  final int
      entryIdx; //needed because a pointer to DirEntry will change whenever entries vector changes.
  final DirEntry entry;
  String fullName;
  final List<int> blocks = [];
  int position = 0;
  bool eof = false;
  bool fail = false;

  // Cache for reading
  final Uint8List cacheData = Uint8List(poleCACHEBUFSIZE);
  int cacheSize = 0; // indicating an empty cache
  int cachePos = 0;

  StreamIO({required StorageIO storage, required DirEntry dirEntry})
      : io = storage,
        entry = dirEntry,
        entryIdx = storage.dirtree.indexOf(dirEntry),
        fullName = '' {
    if (dirEntry.size >= io.header.threshold) {
      blocks.clear();
      blocks.addAll(io.bbat.follow(dirEntry.start));
    } else {
      blocks.clear();
      blocks.addAll(io.sbat.follow(dirEntry.start));
    }
  }

  //int size() => entry.size;

  Future<void> setSize(int newSize) async {
    bool bThresholdCrossed = false;
    bool bOver = false;

    if (!io.writeable) return;
    DirEntry? entry = io.dirtree.entry(entryIdx);
    if (entry == null) return;

    if (newSize >= io.header.threshold && entry.size < io.header.threshold) {
      bThresholdCrossed = true;
      bOver = true;
    } else if (newSize < io.header.threshold &&
        entry.size >= io.header.threshold) {
      bThresholdCrossed = true;
      bOver = false;
    }

    if (bThresholdCrossed) {
      // first, read what is already in the stream, limited by the requested new size. Note
      // that the read can work precisely because we have not yet reset the size.
      int len = newSize;
      if (len > entry.size) {
        len = entry.size;
      }

      Uint8List? buffer;
      int savePos = tell();
      if (len > 0) {
        buffer = Uint8List(len);
        seek(0);
        read(buffer, len);
      }

      // Now get rid of the existing blocks
      if (bOver) {
        for (int idx = 0; idx < blocks.length; idx++) {
          io.sbat.set(blocks[idx], poleAvail);
          io.sbat.markAsDirty(idx, io.bbat.blockSize);
        }
      } else {
        for (int idx = 0; idx < blocks.length; idx++) {
          io.bbat.set(blocks[idx], poleAvail);
          io.bbat.markAsDirty(idx, io.bbat.blockSize);
        }
      }

      blocks.clear();
      entry.start = DirTree.end;

      // Now change the size, and write the old data back into the stream, if any
      entry.size = newSize;
      io.dirtree.markAsDirty(io.dirtree.indexOf(entry), io.bbat.blockSize);

      if (len > 0 && buffer != null) {
        write(buffer, len);
      }
      if (savePos <= entry.size) {
        seek(savePos);
      }
    } else if (entry.size != newSize) {
      //simple case - no threshold was crossed, so just change the size
      entry.size = newSize;
      io.dirtree.markAsDirty(io.dirtree.indexOf(entry), io.bbat.blockSize);
    }
  }

  Future<void> seek(int pos) async {
    if (pos < 0) pos = 0;
    //if (pos > entry.size) pos = entry.size;
    position = pos;
    //eof = (position >= entry.size);
  }

  int tell() => position;

  Future<int> getch() async {
    // past end-of-file ?
    DirEntry? entry = io.dirtree.entry(entryIdx);
    if (entry == null) return -1;

    if (position >= entry.size) return -1;

    // need to update cache ?
    if (cacheSize > 0 ||
        (position < cachePos) ||
        (position >= cachePos + cacheSize)) {
      updateCache();
    }

    // something bad if we don't get good cache
    if (cacheSize <= 0) return -1;

    int data = cacheData[position - cachePos];
    position++;

    return data;
  }

  int read(Uint8List data, int maxlen) {
    int bytes = read3(tell(), data, maxlen);
    position += bytes;
    return bytes;
  }

  int read3(int pos, Uint8List data, int maxlen) {
    // sanity checks
    if (maxlen == 0) return 0;

    DirEntry? entry = io.dirtree.entry(entryIdx);
    if (entry == null) return 0;

    int totalbytes = 0;
    if (pos + maxlen > entry.size) {
      maxlen = entry.size - pos;
    }

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

        if (count > maxlen - totalbytes) {
          count = maxlen - totalbytes;
        }

        data.setRange(totalbytes, totalbytes + count, buf, offset);
        totalbytes += count;
        offset = 0;
        index++;
      }
    }

    return totalbytes;
  }

  int write(Uint8List? data, int len) {
    return write3(tell(), data, len);
  }

  int write3(int pos, Uint8List? data, int len) {
    // sanity checks
    if (data == null) return 0;
    if (len == 0) return 0;
    if (!io.writeable) return 0;

    DirEntry? entry = io.dirtree.entry(entryIdx);
    if (entry == null) return 0;

    if (pos + len > entry.size) {
      setSize(
          pos + len); //reset size, possibly changing from small to large blocks
    }

    int totalbytes = 0;
    if (entry.size < io.header.threshold) {
      // small file
      int index = (pos + len - 1) ~/ io.sbat.blockSize;
      while (index >= blocks.length) {
        int nblock = io.sbat.unused();
        if (blocks.isNotEmpty) {
          io.sbat.set(blocks[blocks.length - 1], nblock);
          io.sbat.markAsDirty(blocks[blocks.length - 1], io.bbat.blockSize);
        }

        io.sbat.set(nblock, poleEof);
        io.sbat.markAsDirty(nblock, io.bbat.blockSize);

        blocks.length = blocks.length + 1;
        blocks[blocks.length - 1] = nblock;

        int bbidx = nblock ~/ (io.bbat.blockSize ~/ 4); // sizeof(int) = 4
        while (bbidx >= io.header.numSbat) {
          List<int> sbat_blocks = io.bbat.follow(io.header.sbatStart);
          io.ExtendFile(sbat_blocks);
          io.header.numSbat++;
          io.header.dirty = true; //Header will have to be rewritten
        }
        int sidx = nblock * io.sbat.blockSize ~/ io.bbat.blockSize;
        while (sidx >= io.sbBlocks.length) {
          io.ExtendFile(io.sbBlocks);
          io.dirtree.markAsDirty(0,
              io.bbat.blockSize); //make sure to rewrite first directory block
        }
      }
      int offset = pos % io.sbat.blockSize;
      index = pos ~/ io.sbat.blockSize;
      //if (index == 0)
      totalbytes = len; // TODO: Implement saveSmallBlocks
    } else {
      int index = (pos + len - 1) ~/ io.bbat.blockSize;
      while (index >= blocks.length) {
        io.ExtendFile(blocks);
      }
      int offset = pos % io.bbat.blockSize;
      int remainder = len;
      index = pos ~/ io.bbat.blockSize;
      while (remainder > 0) {
        if (index >= blocks.length) break;
        int count = io.bbat.blockSize - offset;
        if (remainder < count) count = remainder;

        totalbytes += count;
        remainder -= count;
        index++;
        offset = 0;
      }
    }

    if (blocks.isNotEmpty && entry.start != blocks[0]) {
      entry.start = blocks[0];
      io.dirtree.markAsDirty(io.dirtree.indexOf(entry), io.bbat.blockSize);
    }
    position += len;
    return totalbytes;
  }

  Future<void> flush() async => io.flush();

  void updateCache() {
    DirEntry? entry = io.dirtree.entry(entryIdx);
    if (entry == null) return;

    cachePos = position - (position % poleCACHEBUFSIZE);

    int bytes = poleCACHEBUFSIZE;
    if (cachePos + bytes > entry.size) {
      bytes = entry.size - cachePos;
    }
    cacheSize = read3(cachePos, cacheData, bytes);
  }

  void debug() {
    print('StreamIO:');
    print('  position: $position');
    print('  eof: $eof');
    print('  fail: $fail');
  }
}

class Stream {
  final Storage _storage;
  final String _name;
  late StreamIO _io;
  int _position = 0;
  int _size = 0;

  Stream(this._storage, this._name, {bool create = false, int streamSize = 0}) {
    // Find or create directory entry
    //print('Stream::Stream() - $_name, $create, $streamSize');

    // var entry = _storage._io.dirtree.entryByName(_name);
    // if (entry == null) {
    //   throw Exception('Failed to create stream: $_name');
    // }

    // _io = StreamIO(storage: _storage._io, dirEntry: entry);
    // _size = entry.size;

    _io = _storage._io.streamIO(_name, create, streamSize)!;
    _size = _io.entry.size;
  }

  // Stream(Storage storage, String name, { bool bCreate=false, int streamSize = 0 })
  //   : _name = name, _io = storage._io.streamIO(name, bCreate, streamSize) {

  // }

  /// Returns the full stream name.
  String fullName() => _io.fullName.isNotEmpty ? _io.fullName : _name;

  /// Returns the stream size.
  int size() {
    DirEntry? entry = _io.io.dirtree.entry(_io.entryIdx);
    if (entry == null) return 0;
    return entry.size;
  }

  /// Sets the stream size.
  Future<void> setSize(int newSize) async {
    await _io.setSize(newSize);
    _size = newSize;
  }

  /// Returns the current read/write position.
  int tell() => _io.tell();

  /// Sets the read/write position.
  Future<void> seek(int pos) async {
    await _io.seek(pos);
    _position = pos;
  }

  /// Reads a byte.
  Future<int> getch() async {
    int result = await _io.getch();
    if (result >= 0) {
      _position++;
    }
    return result;
  }

  /// Reads a block of data.
  Future<int> read(Uint8List data, int maxlen) async {
    int result = _io.read(data, maxlen);
    _position += result;
    return result;
  }

  /// Writes a block of data.
  Future<int> write(Uint8List? data, int len) async {
    int result = _io.write(data, len);
    _position += result;
    if (_position > _size) {
      _size = _position;
    }
    return result;
  }

  /// Makes sure that any changes for the stream have been written to disk.
  Future<void> flush() async {
    await _io.flush();
  }

  /// Returns true if the read/write position is past the file.
  bool poleEof() => _io.eof;

  /// Returns true if the last operation failed.
  bool fail() => _io.fail;
}

// Storage class for OLE2 file format
class Storage {
  static const int ok = 0;
  static const int openFailed = 1;
  static const int notOLE = 2;
  static const int badOLE = 3;
  static const int unknownError = 4;

  final String filename;
  late File _file;
  late StorageIO _io;

  Storage({required String fileName}) : filename = fileName {
    _io = StorageIO(pole: this, fname: filename);
  }

  /// Opens the storage. Returns true if no error occurs.
  Future<bool> open({bool writeAccess = false, bool create = false}) async {
    //print('Storage::open');
    return _io.open(writeAccess: writeAccess, create: create);
  }

  /// Closes the storage.
  Future<void> close() async {
    await _io.close();
  }

  /// Returns the error code of last operation.
  int result() => _io.result;

  /// Returns true if storage can be modified.
  bool isWriteable() => _io.writeable;

  /// Finds all stream and directories in given path.
  Future<List<String>> entries([String path = "/"]) async {
    // var result = <String>[];
    // var entry = _io.dirtree.entryByName(path);
    // if (entry == null) return result;

    // if (entry.dir) {
    //   int childIndex = entry.child;
    //   while (childIndex != DirTree.end) {
    //     var childEntry = _io.dirtree.entry(childIndex);
    //     if (childEntry != null && childEntry.valid) {
    //       result.add(childEntry.name);
    //     }
    //     childIndex = childEntry?.next ?? DirTree.end;
    //   }
    // }
    // return result;
    List<String> result = [];
    DirTree dt = _io.dirtree;
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

  /// Returns true if specified entry name is a directory.
  Future<bool> isDirectory(String name) async {
    var entry = _io.dirtree.entryByName(name);
    if (entry == null) {
      //print('Storage::isDirectory() -  name: $name NULL !!!!!');
      return false;
    }
    //print('Storage::isDirectory() -  name: $name, entry.dir: ${entry.dir}');
    return entry.dir;
  }

  /// Returns true if specified entry name exists.
  Future<bool> exists(String name) async {
    var entry = _io.dirtree.entryByName(name);
    return entry?.valid ?? false;
  }

  /// Deletes a specified stream or directory.
  Future<bool> deleteByName(String name) async {
    return await _io.deleteByName(name);
  }

  List<String> getAllStreams(String storageName) {
    List<String> vresult = [];
    DirEntry? e = _io.dirtree.entryByName(storageName);
    if (e != null && e.dir) {
      collectStreams(vresult, _io.dirtree, e, storageName);
    }
    return vresult;
  }

  // recursively collect stream names
  void collectStreams(
      List<String> result, DirTree tree, DirEntry parent, String path) {
    DirEntry? c = tree.entry(parent.child);
    if (c == null) return;

    // TODO: Implement queue-based traversal
    // For now, just add the child if it exists
    if (c.dir) {
      collectStreams(result, tree, c, path + c.name + "/");
    } else {
      result.add(path + c.name);
    }
  }

  void debug() {
    print('Storage debug:');
    print('  File: $filename');
    print('  Writeable: ${_io.writeable}');
    print('  Block Size: ${1 << _io.header.bShift}');
    print('  Small Block Size: ${1 << _io.header.sShift}');
    print('  Threshold: ${_io.header.threshold}');
    print('  Is Open: ${_io.opened}');
    _io.header.debug();
    _io.bbat.debug();
    _io.sbat.debug();
    _io.dirtree.debug();
    _io.debug();
  }
}
