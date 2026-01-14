#!/bin/bash
# scripts/run-ci-tests.sh

echo "🧪 Running CI tests locally..."
echo "=============================="

# Exit on error
set -e

echo "1. Starting API..."
uvicorn app.main:app --host 0.0.0.0 --port 8000 &
API_PID=$!
sleep 5

echo "2. Testing endpoints..."
python -c "
import requests
import sys

BASE_URL = 'http://localhost:8000'

def test_endpoint(name, method, path, expected=200, data=None):
    try:
        if method == 'GET':
            resp = requests.get(f'{BASE_URL}{path}')
        elif method == 'POST':
            resp = requests.post(f'{BASE_URL}{path}', json=data)
        
        if resp.status_code == expected:
            print(f'✅ {name}')
            return True
        else:
            print(f'❌ {name} - Got {resp.status_code}, expected {expected}')
            return False
    except Exception as e:
        print(f'❌ {name} - Error: {e}')
        return False

print('\\nRunning test suite...')
tests = [
    ('Health check', 'GET', '/health'),
    ('Metrics endpoint', 'GET', '/metrics'),
    ('Root endpoint', 'GET', '/'),
    ('Create item', 'POST', '/items', 201, {'name': 'Test', 'price': 10.0}),
]

all_passed = True
for test in tests:
    if not test_endpoint(*test):
        all_passed = False

if all_passed:
    print('\\n🎉 All tests passed!')
else:
    print('\\n❌ Some tests failed')
    sys.exit(1)
"

echo "3. Stopping API..."
kill $API_PID

echo "✅ CI tests completed successfully!"