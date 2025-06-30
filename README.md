# ESC PDI Decode

A Dart CLI application for decoding EtherCAT Slave Controller (ESC) SPI packets from CSV data files.

This is a Dart port of the original Python [esc_decode](https://github.com/existedinnettw/esc_decode) tool.

## Features

- Decodes ESC SPI packet data from CSV files
- Supports READ, READ_WAIT, and WRITE operations
- Provides human-readable descriptions for ESC registers
- Configurable time threshold for packet aggregation
- Option to ignore specific register addresses
- Colored terminal output for errors and warnings

## Installation

1. Ensure you have Dart SDK installed (version 3.7.0 or later)
2. Clone this repository
3. Run `dart pub get` to install dependencies

## Usage

```bash
dart run bin/esc_pdi_decode.dart [options] <input_file>
```

### Options

- `-t, --threshold <value>`: Time threshold in microseconds for aggregating packets (default: 10)
- `-i, --ignore <addr>`: MOSI register addresses to ignore during decoding (e.g., 0x0000, 0x0220...)
- `-h, --help`: Show help message

### Examples

```bash
# Basic usage
dart run bin/esc_pdi_decode.dart data.csv

# With custom threshold and ignored addresses
dart run bin/esc_pdi_decode.dart -t 10 -i 0x0 -i 0x910 data.csv
```

## CSV Format

The input CSV file should contain the following columns:
1. `Time[ns]` - Timestamp in nanoseconds
2. `0:SPI: MISO data` - MISO (Master In, Slave Out) data in hexadecimal
3. `0:SPI: MOSI data` - MOSI (Master Out, Slave In) data in hexadecimal

Example:
```csv
Time[ns],0:SPI: MISO data,0:SPI: MOSI data
1000000,00,00
1001000,c8,1b
1002000,00,00
```

## Sample Output

```
mcu READ_WAIT reg:0x0(Type), data:0xc8(Identification Register: 0x000000C8), when AL event(AL Control Register has been written, At least one SyncManager changed, )
mcu READ_WAIT reg:0x120(AL Control (low)), data:0x01(AL Control: req state=Init (0x1), Error Ind Ack=0, Device ID req=0), when AL event(AL Control Register has been written, At least one SyncManager changed, )
mcu WRITE reg:0x134(AL Status Code (low)), data:0x0000(AL status code:0), when AL event(AL Control Register has been written, At least one SyncManager changed, )
```

## Development

### Running Tests

```bash
dart test
```

### Building

To create a standalone executable:

```bash
dart compile exe bin/esc_pdi_decode.dart -o esc_pdi_decode
```

## License

This project follows the same license as the original Python implementation (Mozilla Public License 2.0).

## Acknowledgments

This is a port of the original Python [esc_decode](https://github.com/existedinnettw/esc_decode) tool by existedinnettw.
