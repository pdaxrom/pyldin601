"""Generate the PS/2 Set 2 ROM from the named keyboard mapping."""
import argparse
import csv
from pathlib import Path


def table(source):
    result = [0xff] * 256
    seen = set()
    with source.open(encoding="utf-8", newline="") as stream:
        rows = csv.DictReader(line for line in stream if line.strip() and not line.lstrip().startswith("#"))
        if rows.fieldnames != ["set2", "set1", "key"]:
            raise ValueError(f"{source}: expected columns set2,set1,key")
        for row in rows:
            if None in row or any(value is None for value in row.values()) or not row["key"].strip():
                raise ValueError(f"{source}: malformed keyboard row {row}")
            set2, set1 = int(row["set2"], 16), int(row["set1"], 16)
            if not 0 <= set2 <= 0xff or not (0 <= set1 <= 0x7f or set1 == 0xff):
                raise ValueError(f"{source}: invalid scan code in {row}")
            if set2 in seen:
                raise ValueError(f"{source}: duplicate Set 2 byte {set2:02X}")
            seen.add(set2)
            result[set2] = set1
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("firmware/ps2_set2.csv"))
    parser.add_argument("--output", type=Path, default=Path("rtl/ps2_set2.mem"))
    args = parser.parse_args()
    values = table(args.source)
    args.output.write_text("".join(f"{value:02x}\n" for value in values))
    print(f"{args.output}: 256 bytes, {sum(value != 0xff for value in values)} mappings from {args.source}")


if __name__ == "__main__":
    main()
