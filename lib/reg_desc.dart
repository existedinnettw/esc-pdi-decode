/// Register descriptions for ESC (EtherCAT Slave Controller)
/// Based on Section II-Register Descriptions for ESC, ch2
library;

import 'package:ansicolor/ansicolor.dart';

/// Create a red pen for error messages
final AnsiPen _redPen = AnsiPen()..red();

/// Decode functions for various ESC registers
class ESCDecoders {
  /// Decodes the SyncManagers supported register (0x0005) value
  static String decodeSmSupported(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    return "numbers of SMs Supported: $value";
  }

  /// Decodes the RAM Size register (0x0006) value
  static String decodeRamSize(int value) {
    return "RAM Size: ${value & 0xFF} kB";
  }

  /// Decodes the Port Descriptor register (0x0007) value
  static String decodePortDescriptor(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    String outStr = "Port Descriptor: ";

    for (int i = 0; i < 4; i++) {
      outStr += "Port $i: ";
      switch ((value >> (i * 2)) & 0x3) {
        case 0x0:
          outStr += "Not implemented, ";
          break;
        case 0x1:
          outStr += "Not configured, ";
          break;
        case 0x2:
          outStr += "EBUS, ";
          break;
        case 0x3:
          outStr += "xMII, ";
          break;
      }
    }
    return outStr;
  }

  /// Decodes the RUN LED Override register (0x0138) value
  static String decodeRunLedOverride(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    int ledCode = value & 0x0F;
    int enableOverride = (value >> 4) & 0x01;

    Map<int, String> ledCodeDesc = {
      0x0: "Off (Init)",
      0x1: "Flash 1x (SafeOp)",
      0xD: "Blinking (PreOp)",
      0xE: "Flickering (Bootstrap)",
      0xF: "On (Operational)",
    };

    String ledDesc;
    if (ledCode >= 0x2 && ledCode <= 0xC) {
      ledDesc = "Flash ${ledCode}x";
    } else {
      ledDesc = ledCodeDesc[ledCode] ?? "Unknown";
    }

    return "RUN LED Override: LED code=0x${ledCode.toRadixString(16).toUpperCase()} ($ledDesc), "
        "Override=${enableOverride == 1 ? 'Enabled' : 'Disabled'} ";
  }

  /// Decodes the ERR LED Override register (0x0139) value
  static String decodeErrLedOverride(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    int ledCode = value & 0x0F;
    int enableOverride = (value >> 4) & 0x01;

    Map<int, String> ledCodeDesc = {
      0x0: "Off",
      0x1: "Flash 1x",
      0xD: "Blinking (PreOp)",
      0xE: "Flickering (Bootstrap)",
      0xF: "On (Operational)",
    };

    String ledDesc;
    if (ledCode >= 0x2 && ledCode <= 0xC) {
      ledDesc = "Flash ${ledCode}x";
    } else {
      ledDesc = ledCodeDesc[ledCode] ?? "Unknown";
    }

    return "ERR LED Override: LED code=0x${ledCode.toRadixString(16).toUpperCase()} ($ledDesc), "
        "Override=${enableOverride == 1 ? 'Enabled' : 'Disabled'} ";
  }

  /// Decodes the AL Status Code Register (0x0134) value
  static String decodeAlStatusCode(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    return "AL status code:$value";
  }

  /// Decodes the PDI Control register (0x0140) value
  static String decodePdiControl(int value) {
    assert(
      value >= 0 && value <= 0xFFFF,
      "Value must be a 16-bit value (0-65535)",
    );
    int pdiMode = value & 0x03;
    Map<int, String> pdiModes = {
      0x0: "SPI",
      0x1: "I2C",
      0x2: "Reserved",
      0x3: "Digital I/O",
    };
    String pdiModeDesc = pdiModes[pdiMode] ?? "Unknown";
    return "PDI Control: Mode=$pdiModeDesc (0x${pdiMode.toRadixString(16).toUpperCase()})";
  }

  /// Decodes the AL Event Request register (0x0220) value
  static String decodeAlEventReq(int value) {
    assert(
      value >= 0 && value <= 0xFFFFFFFF,
      "Value must be a 32-bit value (0-4294967295)",
    );
    String outStr = "";

    if ((value & 0x1) != 0) {
      outStr += "AL Control Register has been written, ";
    }
    if ((value & (0x1 << 1)) != 0) {
      outStr += "At least one change on DC Latch Inputs, ";
    }
    if ((value & (0x1 << 2)) != 0) {
      outStr += "DC SYNC0, ";
    }
    if ((value & (0x1 << 3)) != 0) {
      outStr += "DC SYNC1, ";
    }
    if ((value & (0x1 << 4)) != 0) {
      outStr += "At least one SyncManager changed, ";
    }
    if ((value & (0x1 << 5)) != 0) {
      outStr += "EEPROM command pending, ";
    }
    if ((value & (0x1 << 6)) != 0) {
      outStr += "watchdog process data has expired, ";
    }
    if ((value & (0x1 << 7)) != 0) {
      outStr += _redPen("reserved bit set, ");
    }

    for (int i = 8; i < 24; i++) {
      if ((value & (0x1 << i)) != 0) {
        outStr += "SyncManager ${i - 8} interrupt pending, ";
      }
    }
    return outStr;
  }

  /// Decodes the Sync Manager Status register (0x0800) value
  static String decodeSyncManagerStatus(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    List<String> statusFlags = [];

    for (int i = 0; i < 8; i++) {
      if ((value & (0x1 << i)) != 0) {
        statusFlags.add("SM$i Active");
      }
    }

    return "Sync Manager Status: ${statusFlags.isNotEmpty ? statusFlags.join(', ') : 'No Active SMs'}";
  }

  /// Decodes the Watchdog Status register (0x0440) value
  static String decodeWatchdogStatus(int value) {
    assert(value >= 0 && value <= 0xFF, "Value must be a single byte (0-255)");
    switch (value) {
      case 0x00:
        return "Watchdog Status: No Error";
      case 0x01:
        return "Watchdog Status: PDI Watchdog Triggered";
      case 0x02:
        return "Watchdog Status: Sync Manager Watchdog Triggered";
      default:
        return "Watchdog Status: Unknown (0x${value.toRadixString(16).toUpperCase()})";
    }
  }

  /// ch2.1: Identification Register (0x0000)
  static String decodeCh21(int value) {
    return "Identification Register: 0x${value.toRadixString(16).toUpperCase().padLeft(8, '0')}";
  }

  /// ch2.2: Revision Register (0x0004)
  static String decodeCh22(int value) {
    return "Revision Register: 0x${value.toRadixString(16).toUpperCase().padLeft(8, '0')}";
  }

  /// ch2.20: AL Control (0x0120)
  static String decodeCh220(int value) {
    int state = value & 0x000F;
    return "AL Control: req state=${alStateMap[state] ?? 'Unknown'} (0x${state.toRadixString(16).toUpperCase()}), "
        "Error Ind Ack=${(value & (0x1 << 4)) != 0 ? 1 : 0}, "
        "Device ID req=${(value & (0x1 << 5)) != 0 ? 1 : 0}";
  }

  /// ch2.21: AL Status (0x0130)
  static String decodeCh221(int value) {
    int state = value & 0x000F;
    return "State=${alStateMap[state] ?? 'Unknown'} (0x${state.toRadixString(16).toUpperCase()}), "
        "Error Ind =${(value & (0x1 << 4)) != 0 ? 1 : 0}, "
        "Device ID loaded=${(value & (0x1 << 5)) != 0 ? 1 : 0}, ";
  }

  /// ch2.30 PDI AL Event Mask (0x0204:0x0207)
  static String decodeX204(int value) {
    assert(value >= 0 && value <= 0xFFFFFFFF, "Value must be a 4 byte");
    String outStr = "";

    if ((value & 0x1) != 0) {
      outStr += "AL Control Register, ";
    }
    if ((value & (0x1 << 1)) != 0) {
      outStr += "DC Latch Inputs, ";
    }
    if ((value & (0x1 << 2)) != 0) {
      outStr += "DC SYNC0, ";
    }
    if ((value & (0x1 << 3)) != 0) {
      outStr += "DC SYNC1, ";
    }
    if ((value & (0x1 << 4)) != 0) {
      outStr += "SyncManager changed, ";
    }
    if ((value & (0x1 << 5)) != 0) {
      outStr += "EEPROM command pending, ";
    }
    if ((value & (0x1 << 6)) != 0) {
      outStr += "watchdog process data has expired, ";
    }
    if ((value & (0x1 << 7)) != 0) {
      outStr += _redPen("reserved bit, ");
    }

    for (int i = 8; i < 24; i++) {
      if ((value & (0x1 << i)) != 0) {
        outStr += "SyncManager ${i - 8} interrupt pending, ";
      }
    }

    if (outStr.isNotEmpty) {
      outStr += "AL Event request ";
    } else {
      outStr = "nothing ";
    }
    outStr += "map to PDI IRQ signal";
    return outStr;
  }

  /// ch2.45.1
  static String decodeX502(int value) {
    assert(value >= 0 && value <= 0xFFFFFFFF, "Value must be a 4 byte");
    int configuredStationAlias = value & 0xFF;
    return "configured station alias=$configuredStationAlias";
  }

  /// Decodes the System Time register (0x0910) value
  static String decodeX910SystemTime(int value) {
    assert(value >= 0 && value <= 0xFFFFFFFFFFFFFFFF, "Value must be a 8 byte");
    return "system time=$value";
  }
}

/// AL State mapping
final Map<int, String> alStateMap = {
  0x01: "Init",
  0x02: "Pre-Operational",
  0x03: "Bootstrap",
  0x04: "Safe-Operational",
  0x08: "Operational",
};

/// Integer address to register name mapping
final Map<int, String> regAddrToName = {
  0x0000: "Type",
  0x0001: "Revision",
  0x0002: "Build (low)",
  0x0003: "Build (high)",
  0x0004: "FMMUs supported",
  0x0005: "SyncManagers supported",
  0x0006: "RAM Size",
  0x0007: "Port Descriptor",
  0x0008: "ESC Features supported (low)",
  0x0009: "ESC Features supported (high)",
  0x0010: "Configured Station Address (low)",
  0x0011: "Configured Station Address (high)",
  0x0012: "Configured Station Alias (low)",
  0x0013: "Configured Station Alias (high)",
  0x0020: "Register Write Enable",
  0x0021: "Register Write Protection",
  0x0030: "ESC Write Enable",
  0x0031: "ESC Write Protection",
  0x0040: "ESC Reset ECAT",
  0x0041: "ESC Reset PDI",
  0x0100: "ESC DL Control (low)",
  0x0101: "ESC DL Control",
  0x0102: "ESC DL Control",
  0x0103: "ESC DL Control (high)",
  0x0108: "Physical Read/Write Offset (low)",
  0x0109: "Physical Read/Write Offset (high)",
  0x0110: "ESC DL Status (low)",
  0x0111: "ESC DL Status (high)",
  0x0120: "AL Control (low)",
  0x0121: "AL Control (high)",
  0x0130: "AL Status (low)",
  0x0131: "AL Status (high)",
  0x0134: "AL Status Code (low)",
  0x0135: "AL Status Code (high)",
  0x0138: "RUN LED Override",
  0x0139: "ERR LED Override",
  0x0140: "PDI Control",
  0x0141: "ESC Configuration",
  0x014E: "PDI Information (low)",
  0x014F: "PDI Information (high)",
  0x0150: "PDI Configuration (low)",
  0x0151: "PDI Configuration",
  0x0152: "PDI Configuration",
  0x0153: "PDI Configuration (high)",
  0x0200: "ECAT Event Mask (low)",
  0x0201: "ECAT Event Mask (high)",
  0x0204: "PDI AL Event Mask (low)",
  0x0205: "PDI AL Event Mask",
  0x0206: "PDI AL Event Mask",
  0x0207: "PDI AL Event Mask (high)",
  0x0210: "ECAT Event Request (low)",
  0x0211: "ECAT Event Request (high)",
  0x0220: "AL Event Request (low)",
  0x0221: "AL Event Request",
  0x0222: "AL Event Request",
  0x0223: "AL Event Request (high)",
  0x0300: "RX Error Counter (0)",
  0x0301: "RX Error Counter (1)",
  0x0302: "RX Error Counter (2)",
  0x0303: "RX Error Counter (3)",
  0x0304: "RX Error Counter (4)",
  0x0305: "RX Error Counter (5)",
  0x0306: "RX Error Counter (6)",
  0x0307: "RX Error Counter (7)",
  0x0308: "Forwarded RX Error Counter (0)",
  0x0309: "Forwarded RX Error Counter (1)",
  0x030A: "Forwarded RX Error Counter (2)",
  0x030B: "Forwarded RX Error Counter (3)",
  0x030C: "ECAT Processing Unit Error Counter",
  0x030D: "PDI Error Counter",
  0x030E: "PDI Error Code (low)",
  0x030F: "PDI Error Code (high)",
  0x0310: "Lost Link Counter (0)",
  0x0311: "Lost Link Counter (1)",
  0x0312: "Lost Link Counter (2)",
  0x0313: "Lost Link Counter (3)",
  0x0400: "Watchdog Divider (low)",
  0x0401: "Watchdog Divider (high)",
  0x0410: "Watchdog Time PDI (low)",
  0x0411: "Watchdog Time PDI (high)",
  0x0420: "Watchdog Time Process Data (low)",
  0x0421: "Watchdog Time Process Data (high)",
  0x0440: "Watchdog Status Process Data (low)",
  0x0441: "Watchdog Status Process Data (high)",
  0x0442: "Watchdog Counter Process Data",
  0x0443: "Watchdog Counter PDI",
  0x0500: "SII EEPROM Interface (0)",
  0x0501: "SII EEPROM Interface (1)",
  0x0502: "SII EEPROM Interface (2)",
  0x0503: "SII EEPROM Interface (3)",
  0x0504: "SII EEPROM Interface (4)",
  0x0505: "SII EEPROM Interface (5)",
  0x0506: "SII EEPROM Interface (6)",
  0x0507: "SII EEPROM Interface (7)",
  0x0508: "SII EEPROM Interface (8)",
  0x0509: "SII EEPROM Interface (9)",
  0x050A: "SII EEPROM Interface (10)",
  0x050B: "SII EEPROM Interface (11)",
  0x050C: "SII EEPROM Interface (12)",
  0x050D: "SII EEPROM Interface (13)",
  0x050E: "SII EEPROM Interface (14)",
  0x050F: "SII EEPROM Interface (15)",
  0x0510: "MII Management Interface (0)",
  0x0511: "MII Management Interface (1)",
  0x0512: "MII Management Interface (2)",
  0x0513: "MII Management Interface (3)",
  0x0514: "MII Management Interface (4)",
  0x0515: "MII Management Interface (5)",
  0x0516: "MII Management Interface (6)",
  0x0517: "MII Management Interface (7)",
  0x0518: "MII Management Interface (8)",
  0x0519: "MII Management Interface (9)",
  0x051A: "MII Management Interface (10)",
  0x051B: "MII Management Interface (11)",
  0x0600: "FMMU",
  0x0900: "Distributed Clocks",
  0x0910: "System Time",
  0x0E00: "ESC-specific registers",
  0x0F00: "Digital I/O Output Data (0)",
  0x0F01: "Digital I/O Output Data (1)",
  0x0F02: "Digital I/O Output Data (2)",
  0x0F03: "Digital I/O Output Data (3)",
  0x0F10: "General Purpose Outputs (0)",
  0x0F11: "General Purpose Outputs (1)",
  0x0F12: "General Purpose Outputs (2)",
  0x0F13: "General Purpose Outputs (3)",
  0x0F14: "General Purpose Outputs (4)",
  0x0F15: "General Purpose Outputs (5)",
  0x0F16: "General Purpose Outputs (6)",
  0x0F17: "General Purpose Outputs (7)",
  0x0F18: "General Purpose Inputs (0)",
  0x0F19: "General Purpose Inputs (1)",
  0x0F1A: "General Purpose Inputs (2)",
  0x0F1B: "General Purpose Inputs (3)",
  0x0F1C: "General Purpose Inputs (4)",
  0x0F1D: "General Purpose Inputs (5)",
  0x0F1E: "General Purpose Inputs (6)",
  0x0F1F: "General Purpose Inputs (7)",
  0x0F80: "User RAM (start)",
  0x0FFF: "User RAM (end)",
};

/// ESC Description map - functions to decode register values
final Map<int, String Function(int)> escDescMap = {
  0x0000: ESCDecoders.decodeCh21,
  0x0004: ESCDecoders.decodeCh22,
  0x0005: ESCDecoders.decodeSmSupported,
  0x0006: ESCDecoders.decodeRamSize,
  0x0007: ESCDecoders.decodePortDescriptor,
  0x0120: ESCDecoders.decodeCh220,
  0x0130: ESCDecoders.decodeCh221,
  0x0134: ESCDecoders.decodeAlStatusCode,
  0x0138: ESCDecoders.decodeRunLedOverride,
  0x0139: ESCDecoders.decodeErrLedOverride,
  0x0140: ESCDecoders.decodePdiControl,
  0x0204: ESCDecoders.decodeX204,
  0x0220: ESCDecoders.decodeAlEventReq,
  0x0440: ESCDecoders.decodeWatchdogStatus,
  0x0502: ESCDecoders.decodeX502,
  0x0800: ESCDecoders.decodeSyncManagerStatus,
  0x0910: ESCDecoders.decodeX910SystemTime,
};

/// Initialize SyncManager register mappings
void initializeSyncManagerRegisters() {
  for (int sm = 0; sm < 16; sm++) {
    int baseAddr = 0x0800 + sm * 0x08;
    regAddrToName.addAll({
      baseAddr + 0: "SM$sm physical address (low)",
      baseAddr + 1: "SM$sm physical address (high)",
      baseAddr + 2: "SM$sm length (low)",
      baseAddr + 3: "SM$sm length (high)",
      baseAddr + 4: "SM$sm control",
      baseAddr + 5: "SM$sm status",
      baseAddr + 6: "SM$sm activate",
      baseAddr + 7: "SM$sm PDI control",
    });
  }
}
