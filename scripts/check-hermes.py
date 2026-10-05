"""Offline functional checks against the installed Hermes runtime."""
import importlib.metadata
import json
from pathlib import Path
import sqlite3

import anydoc
import jiter
import nemo_relay
import openai
import watchfiles
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from PIL import Image
import pillow_heif
from pydantic import BaseModel, ValidationError

site = Path(importlib.metadata.distribution('hermes-agent').locate_file(''))
for name, version in json.loads((site / 'hermes-source-versions.json').read_text()).items():
    assert importlib.metadata.version(name) == version, (name, version)

class Record(BaseModel):
    number: int
assert Record.model_validate_json('{"number":42}').number == 42
try:
    Record.model_validate_json('{"number":"invalid"}')
except ValidationError:
    pass
else:
    raise AssertionError('Pydantic accepted invalid input')
assert jiter.from_json(b'{"native":true}') == {'native': True}
key = AESGCM.generate_key(bit_length=128)
cipher = AESGCM(key)
nonce = bytes(range(12))
assert cipher.decrypt(nonce, cipher.encrypt(nonce, b'Guix Hermes', None), None) == b'Guix Hermes'
image = Image.new('RGB', (8, 8), color='red')
image.save('smoke.png')
assert Image.open('smoke.png').size == (8, 8)
pillow_heif.register_heif_opener()

from hermes_state_fts import load_fts5_cjk_extension
conn = sqlite3.connect(':memory:')
assert load_fts5_cjk_extension(conn)
conn.execute("CREATE VIRTUAL TABLE texts USING fts5(body, tokenize='cjk_unicode61')")
conn.execute('INSERT INTO texts VALUES (?)', ('中文测试 Hermes',))
assert conn.execute("SELECT count(*) FROM texts WHERE texts MATCH 'Hermes'").fetchone()[0] == 1
conn.close()
from hermes_state import SessionDB
db = SessionDB()
assert db._fts_cjk_loaded
db.close()
from hermes_cli.config import detect_install_method, is_managed
from hermes_cli.update_contract import evaluate_update_admission
assert detect_install_method(site) == 'guix'
assert not is_managed(), 'Package management must not lock user configuration'
assert evaluate_update_admission(site).code == 'guix'
from tools.environments.local import LocalEnvironment
terminal = LocalEnvironment(cwd=str(Path.cwd()), timeout=10)
try:
    result = terminal.execute("printf '%s' hermes-guix")
    assert result['returncode'] == 0 and 'hermes-guix' in result['output'], result
finally:
    terminal.cleanup()
print('Locked versions, native extensions, FTS, database, terminal and Guix update guard OK')
