#!/usr/bin/env python3
"""Checks that every copy of WidgetSnapshot.swift is identical.

The app and the widget extension each compile their own copy (the file uses Foundation only).
If they drift apart, the app can write data the widgets can't read.

    python3 Tools/check_widget_files.py          # report
    python3 Tools/check_widget_files.py --fix    # copy the app's version over the others
"""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
source = root / "FrancNumero" / "Widgets" / "WidgetSnapshot.swift"
twins = [
    root / "WidgetFiles" / "Shared" / "WidgetSnapshot.swift",          # the staging copy in the zip
    root / "FrancNumeroWidgets" / "Shared" / "WidgetSnapshot.swift",   # the live copy, once the target exists
]

fix = "--fix" in sys.argv
reference = source.read_bytes()
status = 0
print(f"app copy: {source.relative_to(root)}")
for twin in twins:
    if not twin.exists():
        continue
    if twin.read_bytes() == reference:
        print(f"  same     {twin.relative_to(root)}")
    elif fix:
        twin.write_bytes(reference)
        print(f"  FIXED    {twin.relative_to(root)}")
    else:
        print(f"  DIFFERS  {twin.relative_to(root)}  (run with --fix)")
        status = 1
sys.exit(status)
