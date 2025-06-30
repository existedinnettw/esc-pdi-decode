import 'dart:io';
import 'package:args/args.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:esc_pdi_decode/esc_pdi_decode.dart';

void main(List<String> arguments) async {
  // Initialize sync manager registers
  initializeSyncManagerRegisters();

  // Configure colors for ansicolor
  final errorPen = AnsiPen()..red();

  final parser =
      ArgParser()
        ..addOption(
          'threshold',
          abbr: 't',
          help: 'Time threshold in microseconds for aggregating packets',
          defaultsTo: '7',
        )
        ..addMultiOption(
          'ignore',
          abbr: 'i',
          help:
              'MOSI register addresses to ignore during decoding (e.g., 0x0000, 0x0220...)',
        )
        ..addFlag(
          'help',
          abbr: 'h',
          help: 'Show this help message',
          negatable: false,
        );

  late ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    print('');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  if (results.rest.isEmpty) {
    print('Error: Input file is required');
    print('');
    _printUsage(parser);
    exit(1);
  }

  final inputFile = results.rest.first;
  final threshold = int.tryParse(results['threshold'] as String) ?? 7;
  final ignoreAddrsStr = results['ignore'] as List<String>;

  final Set<int> ignoreAddrs = <int>{};
  for (final addrStr in ignoreAddrsStr) {
    try {
      int addr;
      if (addrStr.startsWith('0x') || addrStr.startsWith('0X')) {
        addr = int.parse(addrStr.substring(2), radix: 16);
      } else {
        addr = int.parse(addrStr, radix: 16);
      }
      ignoreAddrs.add(addr);
    } catch (e) {
      print('Warning: Could not parse ignore address "$addrStr": $e');
    }
  }

  // Check if input file exists
  final file = File(inputFile);
  if (!await file.exists()) {
    print('Error: Input file "$inputFile" does not exist');
    exit(1);
  }

  try {
    // Process the pipeline
    final rowStreamData = rowStream(inputFile);
    final aggregatedStream = aggregateStream(rowStreamData, threshold);
    final rawPacketStream = packetTransform(aggregatedStream);

    final packetStream = makeGen(
      rawPacketStream,
      (result) => escRawPacketToEscPacket(result, ignoreAddrs),
    );

    final descStream = makeGen(packetStream, getPacketDesc);

    await for (final result in descStream) {
      if (!result.isSuccess()) {
        final error = result.exceptionOrNull();
        if (error != null && error.toString().isNotEmpty) {
          print(errorPen('Failed to decode packet. Reason: $error'));
        }
        continue;
      }
      print(result.getOrNull());
    }
  } catch (e) {
    print('Error processing file: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('ESC PDI Decode - EtherCAT Slave Controller SPI packet decoder');
  print('');
  print('Usage: esc_pdi_decode [options] <input_file>');
  print('');
  print('Decode ESC commands from a CSV file containing SPI data.');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  esc_pdi_decode data.csv');
  print('  esc_pdi_decode -t 10 -i 0x0 -i 0x910 data.csv');
}
