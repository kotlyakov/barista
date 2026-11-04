#!/usr/bin/env python3
"""Exercise the exported game through real Android input and durable app saves."""
import hashlib
import json
import os
import re
import xml.etree.ElementTree as ET
from pathlib import Path
import struct
import subprocess
import time

PACKAGE = 'org.kotlyakov.barista.emulator'
OUTPUT = Path(os.environ.get('BARISTA_ANDROID_EVIDENCE', 'artifacts/android-runtime'))
OUTPUT.mkdir(parents=True, exist_ok=True)

def adb(*args, binary=False):
    return subprocess.check_output(['adb', *args], text=not binary, stderr=subprocess.STDOUT, timeout=30)

def wait_for(read, predicate, seconds=8):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        last = read()
        if predicate(last):
            return last
        time.sleep(.25)
    raise AssertionError(f'Android state did not reach expected condition: {last}')

def state():
    try:
        paths = adb('shell', 'run-as', PACKAGE, 'find', 'files', '-name', 'slot*.json').splitlines()
    except subprocess.CalledProcessError as error:
        if 'No such file or directory' in str(error.output):
            return None
        raise
    candidates = []
    for path in paths:
        envelope = json.loads(adb('shell', 'run-as', PACKAGE, 'cat', path.strip()))
        assert hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256']
        candidates.append(envelope)
    if not candidates:
        return None
    return json.loads(max(candidates, key=lambda e: e['sequence'])['payload'])

def capture(name):
    data = adb('exec-out', 'screencap', '-p', binary=True)
    assert data.startswith(b'\x89PNG\r\n\x1a\n')
    (OUTPUT / (name + '.png')).write_bytes(data)
    return struct.unpack('>II', data[16:24])

def point(x, y):
    # The emulator is configured for a 16:9 landscape screen, matching the game.
    return str(round(x * width / 1600)), str(round(y * height / 900))

def tap(x, y):
    adb('shell', 'input', 'tap', *point(x, y))

def launch():
    global width, height
    resolved = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', '-c', 'android.intent.category.LAUNCHER', PACKAGE)
    component = next(line.strip() for line in resolved.splitlines() if '/' in line)
    adb('shell', 'am', 'start', '-W', '-n', component)
    wait_for(state, lambda s: s is not None, seconds=15)
    adb('shell', 'uiautomator', 'dump', '/sdcard/barista-window.xml')
    xml = adb('shell', 'cat', '/sdcard/barista-window.xml')
    (OUTPUT / 'startup-window.xml').write_text(xml)
    hierarchy = ET.fromstring(xml)
    for element in hierarchy.iter('node'):
        if element.get('text') == 'Got it':
            bounds = [int(v) for v in re.findall(r'\d+', element.get('bounds', ''))]
            assert len(bounds) == 4
            adb('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2), str((bounds[1]+bounds[3])//2))
            break
    time.sleep(1)
    width, height = capture('startup')
    tap(20, 200)  # Safe blank area: skip intro, or do nothing after its natural end.
    time.sleep(.25)

try:
    source = json.loads(Path('artifacts/android-input/source.json').read_text())
    assert source['source_commit'] == os.environ['BARISTA_EXPECTED_SOURCE_SHA'], 'Wrong pinned preview artifact'
    adb('logcat', '-c')
    launch()
    width, height = capture('01-cafe')
    assert width > height and abs(width / height - 16 / 9) < .02
    initial = wait_for(state, lambda s: s is not None)
    assert initial['shift']['mode'] == 'SHOP'
    tap(1490, 60)
    tap(800, 625)
    tap(530, 650)
    refused = state()
    assert refused['money'] == 0 and refused['upgrades']['grind'] == 0
    capture('00-progress-purchase-refused')
    tap(200, 60)
    tap(800, 425)
    tap(540, 700)
    tap(800, 800)
    started = wait_for(state, lambda s: s['shift']['mode'] == 'RUNNING')
    tap(1490, 60)
    time.sleep(.25)
    paused = state()
    time.sleep(1.25)
    assert state()['clock'] == paused['clock'], 'Menu must freeze active Android time'
    tap(800, 525)  # Explicitly opt into sound after safe silent startup.
    wait_for(state, lambda s: s['preferences']['muted'] is False)
    tap(800, 525)
    wait_for(state, lambda s: s['preferences']['muted'] is True)
    tap(800, 525)  # Re-enable audio: previous smoke accidentally skipped every station effect.
    wait_for(state, lambda s: s['preferences']['muted'] is False)
    tap(800, 625)
    capture('02-progress')
    time.sleep(.6)
    assert state()['clock'] == paused['clock'], 'Progress must remain paused'
    tap(200, 60)
    tap(800, 425)
    expected_taps = list(started['brew']['targets'])
    for i, (x, y) in enumerate([(170, 600), (540, 520), (850, 410)]):
        if i < len(started['brew']['targets']):
            for _ in range(int(started['brew']['targets'][i])):
                tap(x, y)
            if i == 0:
                for _ in range(20):
                    tap(x, y)
                expected_taps[0] += 20
    ready = wait_for(state, lambda s: s['brew']['taps'] == expected_taps)
    assert ready['brew']['taps'] == expected_taps, 'Native Android taps must not duplicate or disappear'
    adb('shell', 'input', 'swipe', *point(650, 760), *point(40, 800), '400')
    missed = wait_for(state, lambda s: s['brew']['locked'])
    assert missed['order']['state'] == 'BREWING'
    tap(1110, 450)
    assert state()['order']['state'] == 'BREWING', 'Guest tap after a miss must not serve the counter cup'
    time.sleep(.8)  # Allow the visible cup to return before the next real drag.
    adb('shell', 'input', 'swipe', *point(650, 760), *point(1110, 450), '500')
    payment = wait_for(state, lambda s: s['order']['state'] == 'PAYMENT')
    capture('03-payment')
    amount = payment['order']['payment']['amount']
    balance = payment['money']
    order_id = payment['order']['id']
    adb('shell', 'am', 'force-stop', PACKAGE)
    launch()
    restored = state()
    assert restored['order']['state'] == 'PAYMENT' and restored['order']['id'] == order_id
    assert restored['preferences']['muted'] is False
    tap(1490, 60)
    tap(800, 525)  # Re-enable after restart to exercise coin effect as well.
    wait_for(state, lambda s: s['preferences']['muted'] is False)
    tap(800, 425)
    tap(955, 610)
    collected = wait_for(state, lambda s: s['money'] == balance + amount)
    assert collected['order']['payment']['collected'] is True
    adb('shell', 'am', 'force-stop', PACKAGE)
    launch()
    final = state()
    assert final['money'] == balance + amount, 'Relaunch must not duplicate collected money'
    assert final['profiles'] == collected['profiles'], 'Customer mood/history must survive Android relaunch'
    tap(1490, 60)
    tap(800, 725)  # Android crash-buffer collection and clipboard report must not close app.
    time.sleep(.5)
    diagnostic_paths = adb('shell', 'run-as', PACKAGE, 'find', 'files', '-name', 'audio-diagnostic.txt').splitlines()
    assert len(diagnostic_paths) == 1
    diagnostic = adb('shell', 'run-as', PACKAGE, 'cat', diagnostic_paths[0].strip())
    assert 'muted=true' in diagnostic
    (OUTPUT / 'audio-diagnostic.txt').write_text(diagnostic)
    capture('04-restored')
    logs = adb('logcat', '-d', '-s', 'godot', 'AndroidRuntime')
    (OUTPUT / 'logcat.txt').write_text(logs)
    assert 'FATAL EXCEPTION' not in logs and 'SCRIPT ERROR:' not in logs
    assert adb('shell', 'pidof', PACKAGE).strip(), 'Android process must remain alive'
    report = {'source_commit': source['source_commit'], 'build_run': int(os.environ['BARISTA_BUILD_RUN']), 'package': PACKAGE, 'device': adb('shell', 'getprop', 'ro.build.version.release').strip(),
              'abi': adb('shell', 'getprop', 'ro.product.cpu.abi').strip(), 'resolution': [width, height],
              'order_id': order_id, 'payment_amount': amount, 'balance_after': final['money'],
              'checks': ['launch', 'real touch', '20 extra grinder taps with audio enabled', 'diagnostic report button', 'menu/progress pause', 'mute', 'purchase refusal', 'missed drop', 'guest tap rejected', 'drag/drop',
                         'restart before payment', 'collect once', 'restart after payment', 'customer history']}
    (OUTPUT / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print('PASS: actual Android install/launch/touch/coffee/payment/pause/save/relaunch', flush=True)
finally:
    with (OUTPUT / 'logcat-all.txt').open('w') as output:
        subprocess.run(['adb','logcat','-d'],stdout=output,stderr=subprocess.STDOUT,timeout=30,check=False)
    with (OUTPUT / 'activities.txt').open('w') as output:
        subprocess.run(['adb','shell','dumpsys','activity','activities'],stdout=output,stderr=subprocess.STDOUT,timeout=30,check=False)
