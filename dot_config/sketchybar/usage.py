import datetime
import email.utils
import fcntl
import json
import math
import os
import pwd
import selectors
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

INTERVAL = 900


class Unavailable(Exception):
    def __init__(self, message, delay=3600):
        super().__init__(message)
        self.delay = delay


def window(label, used, reset):
    if isinstance(used, bool) or not isinstance(used, (int, float)):
        return None
    if not math.isfinite(used) or not 0 <= used <= 100:
        return None
    if isinstance(reset, str):
        try:
            reset = datetime.datetime.fromisoformat(reset.replace('Z', '+00:00')).timestamp()
        except ValueError:
            reset = None
    if isinstance(reset, bool) or not isinstance(reset, (int, float)) or not math.isfinite(reset):
        reset = None
    return {'label': label, 'remaining': math.floor(100 - used), 'resets_at': math.floor(reset) if reset is not None else None}


def decode_codex(data):
    buckets = data.get('rateLimitsByLimitId')
    if not isinstance(buckets, dict) or not buckets:
        buckets = {'codex': data.get('rateLimits') or {}}
    rows, weekly, plan = [], None, None
    for key, bucket in buckets.items():
        if not isinstance(bucket, dict):
            continue
        if key == 'codex':
            plan = bucket.get('planType')
        for slot in ('primary', 'secondary'):
            value = bucket.get(slot)
            if not isinstance(value, dict):
                continue
            minutes = value.get('windowDurationMins')
            label = 'Weekly' if minutes == 10080 else '5-hour' if minutes == 300 else f'{minutes} min' if isinstance(minutes, int) else 'Limit'
            if key != 'codex':
                label += ' · ' + str(bucket.get('limitName') or key)
            row = window(label, value.get('usedPercent'), value.get('resetsAt'))
            if row:
                rows.append(row)
                if key == 'codex' and minutes == 10080:
                    weekly = row
    return {'plan': str(plan or 'Subscription').capitalize(), 'weekly': weekly, 'windows': rows}


def decode_claude(data, tier):
    rows, weekly = [], None
    for key, label in [('five_hour', '5-hour'), ('seven_day', 'Weekly · All models')]:
        value = data.get(key)
        if isinstance(value, dict):
            row = window(label, value.get('utilization'), value.get('resets_at'))
            if row:
                rows.append(row)
                if key == 'seven_day':
                    weekly = row
    scoped = []
    for value in data.get('limits') or []:
        if not isinstance(value, dict) or value.get('kind') != 'weekly_scoped':
            continue
        label = ((value.get('scope') or {}).get('model') or {}).get('display_name')
        if isinstance(label, str):
            row = window('Weekly · ' + label, value.get('percent'), value.get('resets_at'))
            if row:
                scoped.append(row)
    if not scoped:
        for key, value in data.items():
            if key.startswith('seven_day_') and isinstance(value, dict):
                row = window('Weekly · ' + key[10:].replace('_', ' ').title(), value.get('utilization'), value.get('resets_at'))
                if row:
                    scoped.append(row)
    return {'plan': tier, 'weekly': weekly, 'windows': rows + scoped}


def codex():
    process = subprocess.Popen(['codex', 'app-server'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    def send(message):
        process.stdin.write((json.dumps(message) + '\n').encode())
        process.stdin.flush()
    try:
        send({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'sketchybar_usage', 'version': '1.0'}}})
        deadline, buffer = time.monotonic() + 25, b''
        while time.monotonic() < deadline:
            if not selector.select(1):
                continue
            chunk = os.read(process.stdout.fileno(), 65536)
            if not chunk:
                break
            buffer += chunk
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                message = json.loads(line)
                if message.get('id') == 1:
                    if 'error' in message:
                        raise Unavailable('Codex unavailable')
                    send({'method': 'initialized'})
                    send({'id': 2, 'method': 'account/rateLimits/read'})
                elif message.get('id') == 2:
                    if 'error' in message:
                        raise Unavailable('Check Codex login or service')
                    result = decode_codex(message['result'])
                    if not result['windows']:
                        raise Unavailable('No subscription limits')
                    return result
        raise Unavailable('Codex timed out')
    finally:
        selector.close()
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()


def retry_after(value, now):
    try:
        delay = float(value)
        return max(0, delay) if math.isfinite(delay) else 3600
    except (TypeError, ValueError):
        try:
            return max(0, email.utils.parsedate_to_datetime(value).timestamp() - now)
        except (TypeError, ValueError, OverflowError):
            return 3600


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def claude() -> dict:
    config = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
    credential_file = config / '.credentials.json'
    if credential_file.is_file():
        raw = credential_file.read_text()
    else:
        service = 'Claude Code-credentials'
        if os.environ.get('CLAUDE_CONFIG_DIR'):
            raise Unavailable('Use Claude CLI credential file')
        command = ['/usr/bin/security', 'find-generic-password', '-s', service]
        result = subprocess.run([*command, '-a', pwd.getpwuid(os.getuid()).pw_name, '-w'], capture_output=True, text=True, timeout=10, check=False)
        if result.returncode == 44:
            result = subprocess.run([*command, '-w'], capture_output=True, text=True, timeout=10, check=False)
        if result.returncode:
            raise Unavailable('Unlock Keychain or sign in to Claude')
        raw = result.stdout.strip()
        if not raw.startswith('{'):
            raw = bytes.fromhex(raw).decode()
    credential = json.loads(raw).get('claudeAiOauth') or {}
    token = credential.get('accessToken')
    if not token:
        raise Unavailable('Sign in to Claude CLI')
    expiry = credential.get('expiresAt')
    if isinstance(expiry, (int, float)) and expiry <= time.time() * 1000:
        raise Unavailable('Open Claude CLI to renew login')
    tier = credential.get('rateLimitTier') or credential.get('subscriptionType') or 'Subscription'
    tier = tier.removeprefix('default_claude_').replace('_', ' ').title()
    request = urllib.request.Request('https://api.anthropic.com/api/oauth/usage', headers={
        'Authorization': 'Bearer ' + token,
        'Accept': 'application/json',
        'anthropic-beta': 'oauth-2025-04-20',
        'User-Agent': 'sketchybar-subscription-usage/1.0',
    })
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=15) as response:
            data = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            delay = retry_after(error.headers.get('Retry-After'), time.time())
            try:
                delay = max(delay, retry_after(json.load(error).get('retry_after'), time.time()))
            except (ValueError, AttributeError):
                pass
            raise Unavailable('Rate limited', delay) from None
        if error.code in (401, 403):
            raise Unavailable('Open Claude CLI to check login') from None
        raise Unavailable('Claude service unavailable') from None
    result = decode_claude(data, tier)
    if not result['windows']:
        raise Unavailable('No subscription limits')
    return result


PROVIDERS = {'codex': codex, 'claude': claude}


def refresh(state, fetch):
    now = time.time()
    if now < state.get('next_attempt', 0):
        return state
    try:
        result = fetch()
        result.update(updated_at=time.time(), next_attempt=now + INTERVAL, failures=0)
        return result
    except Exception as error:
        failures = min(state.get('failures', 0) + 1, 6)
        delay = max(getattr(error, 'delay', 3600), min(3600 * 2 ** (failures - 1), 21600))
        return dict(state, error=str(error) if isinstance(error, Unavailable) else 'Usage unavailable', failures=failures, next_attempt=time.time() + delay)


def read_state(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def save_state(path, state):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.usage-')
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(state, stream)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    os.umask(0o077)
    cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'sketchybar-usage'
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / 'quota.json'
    if '--cached' in sys.argv:
        print(json.dumps(read_state(path)))
        return
    with (cache / 'quota.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps(read_state(path)))
            return
        state = read_state(path)
        for name, fetch in PROVIDERS.items():
            previous = state.get(name) or {}
            if time.time() < previous.get('next_attempt', 0):
                continue
            state[name] = dict(previous, next_attempt=time.time() + 3600)
            save_state(path, state)
            state[name] = refresh(previous, fetch)
            save_state(path, state)
        print(json.dumps(state))


if __name__ == '__main__':
    main()
