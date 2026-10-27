#!/usr/bin/env python3
"""End-to-end check: re-reading a stopped reading must play the whole text.

Runs the real bin/outloud daemon + CLI inside a throwaway OUTLOUD_HOME, with a
stub `kokoro`/`soundfile` (one tiny WAV per sentence, slow enough to stop
mid-reading) and a fake `mpv` that records every file it is told to play.
Nothing touches ~/Library/Application Support/Outloud or the live daemon.

  python3 tests/test_reread_cache.py        # exit 0 = pass, 1 = fail
"""
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTLOUD = os.path.join(ROOT, "bin", "outloud")

TEXT = " ".join(f"This is sentence number {i} of a long reading that is stopped early." for i in range(1, 9))

KOKORO = '''
import time
class KPipeline:
    def __init__(self, **kw): pass
    def __call__(self, text, voice=None, speed=1.0):
        time.sleep(0.4)  # one chunk per call; slow enough to stop mid-reading
        yield (text, None, [0.0] * 8)
'''
SOUNDFILE = '''
def write(path, audio, rate):
    with open(path, "w") as f:
        f.write("wav:%d" % len(audio))
'''
FAKE_MPV = r'''#!/usr/bin/env python3
import json, os, socket, sys, time
sock_path = next(a.split("=", 1)[1] for a in sys.argv if a.startswith("--input-ipc-server="))
log = os.environ["FAKE_MPV_LOG"]
srv = socket.socket(socket.AF_UNIX)
srv.bind(sock_path)
srv.listen(4)
last_load = 0.0
playlist = 0
while True:
    conn, _ = srv.accept()
    cmd = json.loads(conn.makefile("r").readline())["command"]
    data = None
    if cmd[0] == "loadfile":
        with open(log, "a") as f:
            f.write(cmd[1] + "\n")
        last_load = time.time(); playlist += 1
    elif cmd[0] == "get_property" and cmd[1] == "idle-active":
        data = not (playlist and time.time() - last_load < 0.6)
    conn.sendall((json.dumps({"error": "success", "data": data}) + "\n").encode())
    conn.close()
    if cmd[0] == "quit":
        break
'''


def wait_for(cond, what, timeout=30):
    end = time.time() + timeout
    while time.time() < end:
        v = cond()
        if v:
            return v
        time.sleep(0.05)
    raise SystemExit(f"timeout waiting for {what}")


def main():
    tmp = tempfile.mkdtemp(prefix="ol.", dir="/tmp")  # short path: unix sockets cap at ~104 chars
    home, stubs = os.path.join(tmp, "home"), os.path.join(tmp, "stubs")
    os.makedirs(home)
    os.makedirs(stubs)
    for name, body in (("kokoro.py", KOKORO), ("soundfile.py", SOUNDFILE), ("mpv", FAKE_MPV)):
        with open(os.path.join(stubs, name), "w") as f:
            f.write(body)
    os.chmod(os.path.join(stubs, "mpv"), 0o755)
    mpvlog = os.path.join(tmp, "mpv-plays.log")
    env = dict(os.environ, OUTLOUD_HOME=home, PYTHONPATH=stubs, FAKE_MPV_LOG=mpvlog,
               PATH=stubs + os.pathsep + os.environ["PATH"], OUTLOUD_WARM_LANG="none")
    cli = lambda *a, **kw: subprocess.Popen([sys.executable, OUTLOUD, *a], env=env, **kw)
    daemon = cli("--daemon", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)  # our own PID; killed below
    try:
        wait_for(lambda: os.path.exists(os.path.join(home, "outloud-daemon.sock")), "daemon socket")

        loader = importlib.machinery.SourceFileLoader("outloud_mod", OUTLOUD)
        mod = importlib.util.module_from_spec(importlib.util.spec_from_loader("outloud_mod", loader))
        loader.exec_module(mod)
        expected = len(list(mod.sentences(TEXT)))
        plays = lambda: open(mpvlog).read().split() if os.path.exists(mpvlog) else []

        # 1. start a long reading, stop it after two chunks
        first = cli("-s", "1.0", TEXT)
        wait_for(lambda: len(plays()) >= 2, "two chunks played")
        cli("--stop").wait()
        first.wait(timeout=20)
        hist = json.loads(subprocess.run([sys.executable, OUTLOUD, "--history", "1", "--json"], env=env,
                                         capture_output=True, text=True).stdout)
        rid = hist[0]["id"]
        stopped_at = len(plays())
        print(f"entry {rid}: text has {expected} chunks, reading stopped after {stopped_at}")
        open(mpvlog, "w").close()

        # 2. re-read the stopped entry
        second = cli("--reread", rid)
        second.wait(timeout=60)
        played = plays()
        print(f"re-read played {len(played)} of {expected} chunks")
        ok = len(played) == expected and len(set(played)) == expected
        print("PASS: re-read plays the full text" if ok else "FAIL: re-read is truncated")
        return 0 if ok else 1
    finally:
        daemon.terminate()  # SIGTERM to the daemon we spawned (tracked Popen), never by name
        try:
            daemon.wait(timeout=5)
        except subprocess.TimeoutExpired:
            daemon.kill()
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
