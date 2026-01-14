#!/usr/bin/env python3
"""
Test script for CI/CD pipeline
Tests all API endpoints
"""
import requests
import sys

BASE_URL = 'http://localhost:8000'
tests_passed = 0
tests_failed = 0

def test_endpoint(name, method, path, expected=200, data=None):
    global tests_passed, tests_failed
    try:
        if method == 'GET':
            resp = requests.get(f'{BASE_URL}{path}', timeout=5)
        elif method == 'POST':
            resp = requests.post(f'{BASE_URL}{path}', json=data, timeout=5)
        
        if resp.status_code == expected:
            print(f'  ✅ {name}')
            tests_passed += 1
            return True
        else:
            print(f'  ❌ {name} - Got {resp.status_code}, expected {expected}')
            tests_failed += 1
            return False
    except Exception as e:
        print(f'  ❌ {name} - Error: {e}')
        tests_failed += 1
        return False

print('\n🧪 Running test suite...\n')

# Test health endpoint
test_endpoint('Health check', 'GET', '/health')

# Test metrics endpoint  
try:
    resp = requests.get(f'{BASE_URL}/metrics')
    if resp.status_code == 200 and 'http_requests_total' in resp.text:
        print('  ✅ Metrics endpoint (with prometheus metrics)')
        tests_passed += 1
    else:
        print('  ❌ Metrics endpoint')
        tests_failed += 1
except Exception as e:
    print(f'  ❌ Metrics endpoint - Error: {e}')
    tests_failed += 1

# Test root endpoint
test_endpoint('Root endpoint', 'GET', '/')

# Test list items
test_endpoint('List items', 'GET', '/items')

# Test create item
test_endpoint('Create item', 'POST', '/items', 201, {
    'name': 'CI Test', 
    'description': 'Test item', 
    'price': 99.99
})

# Test docs
test_endpoint('API documentation', 'GET', '/docs')

print(f'\n📊 Test Results: {tests_passed} passed, {tests_failed} failed\n')

if tests_failed > 0:
    sys.exit(1)
else:
    print('🎉 All tests passed!\n')
    sys.exit(0)
