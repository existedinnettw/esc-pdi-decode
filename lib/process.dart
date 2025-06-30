import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:result_dart/result_dart.dart';
import 'package:ansicolor/ansicolor.dart';
import 'reg_desc.dart';

/// Create a red pen for error messages
final AnsiPen _redPen = AnsiPen()..red();

/// Row data structure for CSV input
class RowDict {
  final String miso;
  final String mosi;
  final Duration time;

  RowDict({required this.miso, required this.mosi, required this.time});
}

/// ESC Action types
enum ESCAction {
  nop(0x0),
  read(0x2),
  readWait(0x3),
  write(0x4),
  addrExt(0x6);

  const ESCAction(this.value);
  final int value;

  static ESCAction? fromValue(int value) {
    for (ESCAction action in ESCAction.values) {
      if (action.value == value) {
        return action;
      }
    }
    return null;
  }
}

/// Raw ESC packet structure
class ESCRawPacket {
  final Uint8List misos;
  final Uint8List mosis;

  ESCRawPacket({required this.misos, required this.mosis});
}

/// Processed ESC packet structure
class ESCPacket {
  final ESCAction mAct;
  final int mAddr;
  final Uint8List mData;
  final Uint8List sRespVal;
  final Uint8List alIntpReqVal;

  ESCPacket({
    required this.mAct,
    required this.mAddr,
    required this.mData,
    required this.sRespVal,
    required this.alIntpReqVal,
  });
}

/// Stream rows from CSV file
Stream<RowDict> rowStream(String file) async* {
  final input = File(file);
  final contents = await input.readAsString();

  // Split into lines manually to handle any line ending issues
  final lines = contents.split(RegExp(r'\r?\n'));

  // Skip header if present
  bool isFirstRow = true;
  for (final line in lines) {
    // Skip empty lines
    if (line.trim().isEmpty) continue;

    if (isFirstRow) {
      // Check if first row is header by looking for expected column names
      if (line.contains('Time[ns]') || line.contains('0:SPI: MISO data')) {
        isFirstRow = false;
        continue;
      }
      isFirstRow = false;
    }

    // Parse each line using CSV library for proper escaping
    try {
      final row = const CsvToListConverter().convert(line)[0];

      // Handle both CSV formats
      if (row.length >= 4) {
        // New CSV format: Id, Time[ns], 0:SPI: MISO data, 0:SPI: MOSI data
        String timeStr = row[1].toString().trim();
        String misoStr = row[2].toString().trim();
        String mosiStr = row[3].toString().trim();

        // Parse time from nanoseconds to microseconds
        double timeNs = double.parse(timeStr);
        Duration time = Duration(microseconds: (timeNs / 1000).round());

        yield RowDict(miso: misoStr, mosi: mosiStr, time: time);
      } else if (row.length >= 3) {
        // Old CSV format: Time[ns], 0:SPI: MISO data, 0:SPI: MOSI data
        String timeStr = row[0].toString().trim();
        String misoStr = row[1].toString().trim();
        String mosiStr = row[2].toString().trim();

        // Parse time from nanoseconds to microseconds
        double timeNs = double.parse(timeStr);
        Duration time = Duration(microseconds: (timeNs / 1000).round());

        yield RowDict(miso: misoStr, mosi: mosiStr, time: time);
      }
    } catch (e) {
      // Skip malformed rows
      continue;
    }
  }
}

/// Aggregate stream by time threshold
Stream<List<RowDict>> aggregateStream(
  Stream<RowDict> rows,
  int thresholdUs,
) async* {
  List<RowDict> group = [];
  Duration? lastTime;

  // Duration have no nanosecond

  await for (final row in rows) {
    if (group.isEmpty) {
      group.add(row);
      lastTime = row.time;
    } else if (row.time.inMicroseconds - lastTime!.inMicroseconds <=
        thresholdUs) {
      group.add(row);
      lastTime = row.time;
    } else {
      yield group;
      group = [row];
      lastTime = row.time;
    }
  }

  if (group.isNotEmpty) {
    yield group;
  }
}

/// Custom exception for empty results
class EmptyException implements Exception {
  @override
  String toString() => "";
}

/// Transform packet raw data to ESC raw packets
Stream<Result<ESCRawPacket, Exception>> packetTransform(
  Stream<List<RowDict>> packetRaws,
) async* {
  await for (final packetRaw in packetRaws) {
    List<int> misoList = [];
    List<int> mosiList = [];

    try {
      for (final row in packetRaw) {
        if (row.miso.isEmpty || row.mosi.isEmpty) {
          throw Exception("Empty MISO or MOSI value at group $packetRaw");
        }
        misoList.add(int.parse(row.miso, radix: 16));
        mosiList.add(int.parse(row.mosi, radix: 16));
      }

      Uint8List misoBytes = Uint8List.fromList(misoList);
      Uint8List mosiBytes = Uint8List.fromList(mosiList);

      yield Success(ESCRawPacket(misos: misoBytes, mosis: mosiBytes));
    } catch (e) {
      yield Failure(Exception(e.toString()));
    }
  }
}

/// Invert byte order (little/big endian conversion)
Uint8List endianInvert(Uint8List bytesIn) {
  return Uint8List.fromList(bytesIn.reversed.toList());
}

/// Convert ESC raw packet to ESC packet
Result<ESCPacket, Exception> escRawPacketToEscPacket(
  Result<ESCRawPacket, Exception> rstRawPacket,
  Set<int> ignoreAddrs,
) {
  if (rstRawPacket.isError()) {
    return Failure(rstRawPacket.exceptionOrNull()!);
  }

  final rawPacket = rstRawPacket.getOrNull()!;

  ESCAction mAct = ESCAction.nop;
  int mAddr = 0;

  try {
    if (rawPacket.mosis.length < 2) {
      throw Exception("Packet too short, may lose data during sampling");
    }

    // Extract action from lower 3 bits of second byte (MOSI[1])
    int actionValue = rawPacket.mosis[1] & 0x7;
    mAct = ESCAction.fromValue(actionValue) ?? ESCAction.nop;

    mAddr = (rawPacket.mosis[0] << 8 | (rawPacket.mosis[1])) >> 3;
  } catch (e) {
    return Failure(Exception(e.toString()));
  }

  if (ignoreAddrs.contains(mAddr)) {
    return Failure(EmptyException());
  }

  Uint8List mData = Uint8List(0);
  Uint8List sRespVal = Uint8List(0);

  // Extract AL interrupt request value from first 2 bytes of MISO
  Uint8List alIntpReqVal = endianInvert(
    Uint8List.fromList(rawPacket.misos.take(2).toList()),
  );

  switch (mAct) {
    case ESCAction.nop:
      // NOP operations have no additional data
      break;
    case ESCAction.read:
      if (rawPacket.misos.length > 2) {
        sRespVal = endianInvert(
          Uint8List.fromList(rawPacket.misos.skip(2).toList()),
        );
      }
      break;
    case ESCAction.readWait:
      if (rawPacket.misos.length > 3) {
        sRespVal = endianInvert(
          Uint8List.fromList(rawPacket.misos.skip(3).toList()),
        );
      }
      break;
    case ESCAction.write:
      if (rawPacket.mosis.length > 2) {
        mData = endianInvert(
          Uint8List.fromList(rawPacket.mosis.skip(2).toList()),
        );
      }
      break;
    case ESCAction.addrExt:
      // Address extension operations might have special handling
      break;
  }

  return Success(
    ESCPacket(
      mAct: mAct,
      mAddr: mAddr,
      mData: mData,
      sRespVal: sRespVal,
      alIntpReqVal: alIntpReqVal,
    ),
  );
}

/// Get pretty description for register
String getRegPrettyDesc(int addr, Uint8List data) {
  String outStr = "reg:0x${addr.toRadixString(16)}";

  if (!regAddrToName.containsKey(addr)) {
    outStr += _redPen("(unknown register)");
    return outStr;
  }
  outStr += "(${regAddrToName[addr]})";

  if (data.isEmpty) {
    return outStr;
  }

  String hexData = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  outStr += ", data:0x$hexData";

  if (escDescMap.containsKey(addr)) {
    final descFunc = escDescMap[addr]!;
    int value = 0;
    // Convert bytes to integer (little endian)
    for (int i = 0; i < data.length && i < 8; i++) {
      value |= (data[i] << (i * 8));
    }
    outStr += "(${descFunc(value)})";
  } else {
    outStr += _redPen("(no description)");
  }

  return outStr;
}

/// Get packet description
Result<String, Exception> getPacketDesc(
  Result<ESCPacket, Exception> rstPacket,
) {
  if (rstPacket.isError()) {
    return Failure(rstPacket.exceptionOrNull()!);
  }

  final packet = rstPacket.getOrNull()!;
  String outStr = "mcu ";
  outStr += "${packet.mAct.name.toUpperCase()} ";

  switch (packet.mAct) {
    case ESCAction.readWait:
      outStr += getRegPrettyDesc(packet.mAddr, packet.sRespVal);
      break;
    case ESCAction.write:
      outStr += getRegPrettyDesc(packet.mAddr, packet.mData);
      break;
    default:
      outStr += "(no description)";
  }

  outStr += ", when AL event";

  // Use AL event decoder for interrupt request value
  int alEventValue = 0;
  for (int i = 0; i < packet.alIntpReqVal.length && i < 4; i++) {
    alEventValue |= (packet.alIntpReqVal[i] << (i * 8));
  }

  if (escDescMap.containsKey(0x0220)) {
    outStr += "(${escDescMap[0x0220]!(alEventValue)})";
  }

  return Success(outStr);
}

/// Process a stream of results applying a function
Stream<Result<U, Exception>> makeGen<T extends Object, U extends Object>(
  Stream<Result<T, Exception>> stream,
  Result<U, Exception> Function(Result<T, Exception>) fn,
) async* {
  await for (final item in stream) {
    yield fn(item);
  }
}
