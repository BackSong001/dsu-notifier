"""앱 정책 원본을 공개 Edge Function에 동기화한다."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'frontend/assets/legal/policies.json'
target = ROOT / 'supabase/functions/legal/documents.json'
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
content = source.read_text()
data = json.loads(content)
assert {doc['id'] for doc in data['documents']} == {'privacy', 'terms', 'deletion'}
assert data['contactEmail'] == 'jhgu2014@gmail.com'
if args.check:
    if not target.exists() or target.read_text() != content:
        raise SystemExit('Policy copies differ: run python3 scripts/sync-legal-documents.py')
    print('App and public policies match')
else:
    target.write_text(content)
    print('Public policies synchronized')
