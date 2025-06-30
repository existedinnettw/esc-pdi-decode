import 'dart:typed_data';
import 'package:esc_pdi_decode/esc_pdi_decode.dart';
import 'package:test/test.dart';
import 'package:result_dart/result_dart.dart';

void main() {
  setUpAll(() {
    // Initialize sync manager registers for tests
    initializeSyncManagerRegisters();
  });

  group('ESC Decoders', () {
    test('decode SM supported', () {
      expect(ESCDecoders.decodeSmSupported(8), 'numbers of SMs Supported: 8');
    });

    test('decode RAM size', () {
      expect(ESCDecoders.decodeRamSize(64), 'RAM Size: 64 kB');
    });

    test('decode RUN LED override', () {
      final result = ESCDecoders.decodeRunLedOverride(0x1D);
      expect(result, contains('RUN LED Override'));
      expect(result, contains('LED code=0xD'));
      expect(result, contains('Blinking (PreOp)'));
    });

    test('decode AL Control', () {
      final result = ESCDecoders.decodeCh220(0x01);
      expect(result, contains('AL Control'));
      expect(result, contains('req state=Init (0x1)'));
    });
  });

  group('ESC Action', () {
    test('fromValue works correctly', () {
      expect(ESCAction.fromValue(0x0), ESCAction.nop);
      expect(ESCAction.fromValue(0x2), ESCAction.read);
      expect(ESCAction.fromValue(0x3), ESCAction.readWait);
      expect(ESCAction.fromValue(0x4), ESCAction.write);
      expect(ESCAction.fromValue(0x6), ESCAction.addrExt);
      expect(ESCAction.fromValue(0x99), null);
    });
  });

  group('Result', () {
    test('Success works', () {
      final result = Success<int, Exception>(42);
      expect(result.isSuccess(), isTrue);
      expect(result.isError(), isFalse);
      expect(result.getOrNull(), 42);
    });

    test('Failure works', () {
      final error = Exception('test error');
      final result = Failure<int, Exception>(error);
      expect(result.isSuccess(), isFalse);
      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull(), error);
    });
  });

  group('ESC packet processing', () {
    test('NOP action packet', () {
      // Test data: MOSI=[0x00, 0x00] (NOP action, address 0x0000)
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x0C, 0xC8]),
        mosis: Uint8List.fromList([0x00, 0x00]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isSuccess(), isTrue);
      final packet = result.getOrNull()!;
      expect(packet.mAct, ESCAction.nop);
      expect(packet.mAddr, 0x0000);
    });

    test('READ action packet', () {
      // Test data: MOSI=[0x10, 0x02] (READ action=2 in lower 3 bits of second byte)
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x0C, 0xC8]),
        mosis: Uint8List.fromList([0x10, 0x02]), // Action 2 is in second byte
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isSuccess(), isTrue);
      final packet = result.getOrNull()!;
      expect(packet.mAct, ESCAction.read);
      // Address calculation: (0x10 << 8 | 0x02) >> 3 = 0x1002 >> 3 = 0x200
      expect(packet.mAddr, 0x200);
    });

    test('READ_WAIT action packet', () {
      // Test data: MOSI=[0x18, 0x03] (READ_WAIT action=3 in second byte)
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x01, 0x00]),
        mosis: Uint8List.fromList([0x18, 0x03]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isSuccess(), isTrue);
      final packet = result.getOrNull()!;
      expect(packet.mAct, ESCAction.readWait);
      // Address calculation: (0x18 << 8 | 0x03) >> 3 = 0x1803 >> 3 = 0x300
      expect(packet.mAddr, 0x300);
    });

    test('WRITE action packet', () {
      // Test data: MOSI=[0x20, 0x04, 0x00] (WRITE action=4 in second byte)
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x11, 0x00, 0x10]),
        mosis: Uint8List.fromList([0x20, 0x04, 0x00]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isSuccess(), isTrue);
      final packet = result.getOrNull()!;
      expect(packet.mAct, ESCAction.write);
      // Address calculation: (0x20 << 8 | 0x04) >> 3 = 0x2004 >> 3 = 0x400
      expect(packet.mAddr, 0x400);
      expect(packet.mData.length, 1);
      expect(packet.mData[0], 0x00);
    });

    test('ADDR_EXT action packet', () {
      // Test data: MOSI=[0x30, 0x06] (ADDR_EXT action=6 in second byte)
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0xFF, 0xFF]),
        mosis: Uint8List.fromList([0x30, 0x06]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isSuccess(), isTrue);
      final packet = result.getOrNull()!;
      expect(packet.mAct, ESCAction.addrExt);
      // Address calculation: (0x30 << 8 | 0x06) >> 3 = 0x3006 >> 3 = 0x600
      expect(packet.mAddr, 0x600);
    });

    test('packet with ignored address', () {
      // Test data: WRITE to computed address that will be ignored
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x11, 0x00, 0x10]),
        mosis: Uint8List.fromList([0x84, 0x00, 0xFF]),
      );
      // Computed address: (0x84 << 8 | 0x00) >> 3 = 0x8400 >> 3 = 0x1080
      final ignoreAddrs = <int>{0x1080}; // Ignore this computed address
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        ignoreAddrs,
      );

      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull(), isA<EmptyException>());
    });

    test('invalid action code', () {
      // Test data: Invalid action code 0x05 (action=5) in second byte
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x11, 0x00]),
        mosis: Uint8List.fromList([0x28, 0x05]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      // With the current implementation, undefined actions default to NOP, so this should succeed
      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!.mAct, ESCAction.nop);
    });

    test('packet too short', () {
      // Test data: Only one byte
      final rawPacket = ESCRawPacket(
        misos: Uint8List.fromList([0x11]),
        mosis: Uint8List.fromList([0x84]),
      );
      final result = escRawPacketToEscPacket(
        Success<ESCRawPacket, Exception>(rawPacket),
        <int>{},
      );

      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull().toString(), contains('Packet too short'));
    });

    test('error input propagation', () {
      // Test that input errors are propagated
      final inputError = Exception('Input error');
      final result = escRawPacketToEscPacket(
        Failure<ESCRawPacket, Exception>(inputError),
        <int>{},
      );

      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull(), inputError);
    });
  });

  group('Packet description', () {
    test('successful packet description for known register', () {
      // Create a valid ESC packet for Type register (0x0000) - using readWait to get description
      final packet = ESCPacket(
        mAct: ESCAction.readWait,
        mAddr: 0x0000,
        mData: Uint8List.fromList([]),
        sRespVal: Uint8List.fromList([0xC8]),
        alIntpReqVal: Uint8List.fromList([0x00, 0x00]),
      );
      final result = getPacketDesc(Success<ESCPacket, Exception>(packet));

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!, contains('READWAIT'));
      expect(result.getOrNull()!, contains('reg:0x0'));
      expect(result.getOrNull()!, contains('Type'));
    });

    test('packet description for write operation', () {
      // Create a WRITE packet to AL Control register
      final packet = ESCPacket(
        mAct: ESCAction.write,
        mAddr: 0x0120,
        mData: Uint8List.fromList([0x01]),
        sRespVal: Uint8List.fromList([0x00]),
        alIntpReqVal: Uint8List.fromList([0x00]),
      );
      final result = getPacketDesc(Success<ESCPacket, Exception>(packet));

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!, contains('WRITE'));
      expect(result.getOrNull()!, contains('reg:0x120'));
      expect(result.getOrNull()!, contains('AL Control'));
    });

    test('packet description error propagation', () {
      // Test that input errors are propagated
      final inputError = Exception('Packet error');
      final result = getPacketDesc(Failure<ESCPacket, Exception>(inputError));

      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull(), inputError);
    });

    test('packet description for unknown register', () {
      // Create a packet for an unknown register - using readWait to get description
      final packet = ESCPacket(
        mAct: ESCAction.readWait,
        mAddr: 0x9999,
        mData: Uint8List.fromList([]),
        sRespVal: Uint8List.fromList([0xFF]),
        alIntpReqVal: Uint8List.fromList([0x00, 0x00]),
      );
      final result = getPacketDesc(Success<ESCPacket, Exception>(packet));

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!, contains('READWAIT'));
      expect(result.getOrNull()!, contains('reg:0x9999'));
      expect(result.getOrNull()!, contains('unknown register'));
    });

    test('NOP action description', () {
      // Create a NOP packet
      final packet = ESCPacket(
        mAct: ESCAction.nop,
        mAddr: 0x0000,
        mData: Uint8List.fromList([]),
        sRespVal: Uint8List.fromList([0x00]),
        alIntpReqVal: Uint8List.fromList([0x00, 0x00]),
      );
      final result = getPacketDesc(Success<ESCPacket, Exception>(packet));

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!, contains('NOP'));
      expect(result.getOrNull()!, contains('(no description)'));
    });

    test('ADDR_EXT action description', () {
      // Create an ADDR_EXT packet
      final packet = ESCPacket(
        mAct: ESCAction.addrExt,
        mAddr: 0x1200,
        mData: Uint8List.fromList([]),
        sRespVal: Uint8List.fromList([0xFF]),
        alIntpReqVal: Uint8List.fromList([0x00, 0x00]),
      );
      final result = getPacketDesc(Success<ESCPacket, Exception>(packet));

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!, contains('ADDREXT'));
      expect(result.getOrNull()!, contains('(no description)'));
    });
  });
}
