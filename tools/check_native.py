#!/usr/bin/env python3
"""Run real Godot scripts; runtime ERROR or timeout fails even if Godot exits 0."""
import os
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
godot = os.environ.get('GODOT', 'godot')
tests = sorted((root / 'game/tests').glob('*_test.gd')) + [root / 'game/tests/smoke.gd']
for test in tests:
    proc = subprocess.run([godot, '--headless', '--path', str(root / 'game'), '--script', 'res://tests/' + test.name], capture_output=True, text=True, timeout=30)
    output = proc.stdout + proc.stderr
    print(test.name + ': ' + output.strip().splitlines()[-1])
    if proc.returncode or 'ERROR:' in output or 'PASS:' not in output:
        print(output)
        raise SystemExit(1)
print(f'PASS: {len(tests)} Godot test scripts')
