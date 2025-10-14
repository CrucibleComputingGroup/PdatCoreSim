#!/usr/bin/env python3
"""
Split a VCD file into two parts based on time range.

Usage: split_vcd.py <input.vcd> <split_time_ps> <output1.vcd> <output2.vcd>

Creates:
- output1.vcd: Contains data from start to split_time (inclusive)
- output2.vcd: Contains data from split_time onward
"""

import sys
import argparse

def split_vcd(input_file, split_time_ps, output1, output2):
    """Split VCD file at specified time."""

    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Find where $dumpvars ends (header section)
    header_end = 0
    in_dumpvars = False
    for i, line in enumerate(lines):
        if '$dumpvars' in line:
            in_dumpvars = True
        if in_dumpvars and '$end' in line:
            header_end = i + 1
            break

    header = lines[:header_end]
    data = lines[header_end:]

    # Split data at the specified time
    data1 = []
    data2 = []
    current_time = 0
    split_occurred = False

    for line in data:
        # Check for timestamp
        if line.startswith('#'):
            try:
                current_time = int(line[1:].strip())
            except:
                pass

        if current_time <= split_time_ps:
            data1.append(line)
        else:
            if not split_occurred:
                # Add one more timestamp line to data1 for completeness
                split_occurred = True
            data2.append(line)

    # Write first VCD (header + data up to split time)
    with open(output1, 'w') as f:
        f.writelines(header)
        f.writelines(data1)

    # Write second VCD (header + data from split time onward)
    with open(output2, 'w') as f:
        f.writelines(header)
        f.writelines(data2)

    print(f"Split VCD at time {split_time_ps} ps")
    print(f"  Created: {output1} (up to {split_time_ps} ps)")
    print(f"  Created: {output2} (from {split_time_ps} ps onward)")

def main():
    parser = argparse.ArgumentParser(
        description='Split a VCD file into two parts based on time'
    )
    parser.add_argument('input_vcd', help='Input VCD file')
    parser.add_argument('split_time', type=int, help='Split time in picoseconds')
    parser.add_argument('output1', help='Output VCD file 1 (before split)')
    parser.add_argument('output2', help='Output VCD file 2 (after split)')

    args = parser.parse_args()

    split_vcd(args.input_vcd, args.split_time, args.output1, args.output2)

if __name__ == '__main__':
    main()
