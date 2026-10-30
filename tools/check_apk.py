#!/usr/bin/env python3
"""Verify an exported preview APK with official SDK tools and inspect its ZIP."""
import argparse
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('apk', type=Path)
parser.add_argument('--sdk-root', type=Path, required=True)
parser.add_argument('--abi', default='arm64-v8a')
parser.add_argument('--package', default='org.kotlyakov.barista')
parser.add_argument('--version-code', default='2')
parser.add_argument('--version-name', default='0.2.0')
args = parser.parse_args()
tools = args.sdk_root / 'build-tools/35.0.0'
subprocess.run([str(tools / 'apksigner'), 'verify', '--verbose', str(args.apk)], check=True)
subprocess.run([str(tools / 'zipalign'), '-c', '-P', '16', '4', str(args.apk)], check=True)
badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(args.apk)], text=True)
assert f"package: name='{args.package}'" in badging, 'wrong package'
assert f"versionCode='{args.version_code}'" in badging and f"versionName='{args.version_name}'" in badging, 'wrong version'
assert "targetSdkVersion:'35'" in badging, 'wrong target SDK'
assert "sdkVersion:'24'" in badging, 'unexpected minimum SDK'
with zipfile.ZipFile(args.apk) as archive:
    assert archive.testzip() is None, 'ZIP corruption'
    names = archive.namelist()
    abis = {name.split('/')[1] for name in names if name.startswith('lib/') and name.endswith('.so')}
    assert abis == {args.abi}, f'wrong ABIs: {abis}'
    assert not any(name.endswith(('.keystore', '.jks', 'export_credentials.cfg')) for name in names), 'signing credentials included'
result = {'package': args.package, 'version': args.version_name, 'min_sdk': 24, 'target_sdk': 35, 'abi': args.abi, 'size_bytes': args.apk.stat().st_size, 'sha256': hashlib.file_digest(args.apk.open('rb'), 'sha256').hexdigest()}
print(json.dumps(result, ensure_ascii=False, indent=2))
print('PASS: APK signature, 16 KB alignment, manifest, ABI and ZIP integrity')
