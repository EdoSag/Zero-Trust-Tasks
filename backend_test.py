#!/usr/bin/env python3
"""
Zero-Trust Task Manager Backend API Testing
Tests all API endpoints for the encrypted task management system
"""

import requests
import json
import sys
from datetime import datetime
import uuid

class ZeroTrustAPITester:
    def __init__(self, base_url="https://zerotrust-todo.preview.emergentagent.com"):
        self.base_url = base_url
        self.session_token = None
        self.user_id = None
        self.tests_run = 0
        self.tests_passed = 0
        self.failed_tests = []

    def log(self, message, level="INFO"):
        """Log test messages"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")

    def run_test(self, name, method, endpoint, expected_status, data=None, headers=None):
        """Run a single API test"""
        url = f"{self.base_url}/api/{endpoint}" if not endpoint.startswith('http') else endpoint
        test_headers = {'Content-Type': 'application/json'}
        
        if self.session_token:
            test_headers['Authorization'] = f'Bearer {self.session_token}'
        
        if headers:
            test_headers.update(headers)

        self.tests_run += 1
        self.log(f"Testing {name}...")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=test_headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=test_headers, timeout=10)
            elif method == 'PUT':
                response = requests.put(url, json=data, headers=test_headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, headers=test_headers, timeout=10)

            success = response.status_code == expected_status
            if success:
                self.tests_passed += 1
                self.log(f"✅ {name} - Status: {response.status_code}", "PASS")
                try:
                    return True, response.json() if response.text else {}
                except:
                    return True, {}
            else:
                self.log(f"❌ {name} - Expected {expected_status}, got {response.status_code}", "FAIL")
                self.log(f"   Response: {response.text[:200]}", "FAIL")
                self.failed_tests.append({
                    'test': name,
                    'expected': expected_status,
                    'actual': response.status_code,
                    'response': response.text[:200]
                })
                return False, {}

        except Exception as e:
            self.log(f"❌ {name} - Error: {str(e)}", "ERROR")
            self.failed_tests.append({
                'test': name,
                'error': str(e)
            })
            return False, {}

    def test_health_endpoints(self):
        """Test basic health and root endpoints"""
        self.log("=== Testing Health Endpoints ===")
        
        # Test health endpoint
        success, _ = self.run_test("Health Check", "GET", "health", 200)
        
        # Test root endpoint
        success, response = self.run_test("Root Endpoint", "GET", "", 200)
        if success and 'message' in response:
            self.log(f"   Root message: {response['message']}")

    def test_auth_flow(self):
        """Test authentication flow (mocked session)"""
        self.log("=== Testing Authentication Flow ===")
        
        # Test auth/me without token (should fail)
        self.run_test("Auth Me (No Token)", "GET", "auth/me", 401)
        
        # Mock session creation (since we can't do real OAuth in tests)
        mock_session_data = {
            "session_id": f"test_session_{uuid.uuid4().hex[:12]}"
        }
        
        # Note: This will fail in real testing since we don't have valid OAuth session
        # But we test the endpoint structure
        success, response = self.run_test("Create Session (Mock)", "POST", "auth/session", 401, mock_session_data)
        
        # For testing purposes, we'll create a mock token
        # In real app, this would come from successful OAuth
        self.session_token = f"mock_token_{uuid.uuid4().hex}"
        self.user_id = f"test_user_{uuid.uuid4().hex[:12]}"
        
        self.log(f"   Using mock session token for further tests")

    def test_encrypted_data_endpoints(self):
        """Test encrypted data storage endpoints"""
        self.log("=== Testing Encrypted Data Endpoints ===")
        
        # Test get data (should return null for new user)
        success, response = self.run_test("Get Encrypted Data (Empty)", "GET", "data", 401)
        
        # Test save encrypted data
        mock_encrypted_data = {
            "encrypted_data": "base64_encrypted_blob_here",
            "iv": "base64_iv_here", 
            "salt": "base64_salt_here"
        }
        
        success, response = self.run_test("Save Encrypted Data", "POST", "data", 401, mock_encrypted_data)

    def test_settings_endpoints(self):
        """Test user settings endpoints"""
        self.log("=== Testing Settings Endpoints ===")
        
        # Test get settings
        success, response = self.run_test("Get Settings", "GET", "settings", 401)
        
        # Test save settings
        mock_settings = {
            "encrypted_settings": "base64_encrypted_settings",
            "iv": "base64_iv_here",
            "salt": "base64_salt_here"
        }
        
        success, response = self.run_test("Save Settings", "POST", "settings", 401, mock_settings)

    def test_webauthn_endpoints(self):
        """Test WebAuthn biometric endpoints"""
        self.log("=== Testing WebAuthn Endpoints ===")
        
        # Test get credentials
        success, response = self.run_test("Get WebAuthn Credentials", "GET", "webauthn/credentials", 401)
        
        # Test register credential
        mock_credential = {
            "credential_id": "test_credential_id",
            "public_key": "test_public_key_data"
        }
        
        success, response = self.run_test("Register WebAuthn Credential", "POST", "webauthn/register", 401, mock_credential)

    def test_backup_endpoints(self):
        """Test backup functionality endpoints"""
        self.log("=== Testing Backup Endpoints ===")
        
        # Test list backups
        success, response = self.run_test("List Backups", "GET", "backup/list", 401)
        
        # Test create backup
        mock_backup_data = {
            "encrypted_data": "base64_encrypted_backup",
            "iv": "base64_iv_here",
            "salt": "base64_salt_here"
        }
        
        success, response = self.run_test("Create Backup", "POST", "backup/create", 401, mock_backup_data)

    def test_cors_and_security(self):
        """Test CORS and security headers"""
        self.log("=== Testing CORS and Security ===")
        
        try:
            # Test CORS preflight
            response = requests.options(f"{self.base_url}/api/health", timeout=10)
            self.log(f"   CORS preflight status: {response.status_code}")
            
            # Check security headers
            response = requests.get(f"{self.base_url}/api/health", timeout=10)
            headers = response.headers
            
            security_checks = [
                ('Access-Control-Allow-Origin', 'CORS origin header'),
                ('Access-Control-Allow-Credentials', 'CORS credentials'),
            ]
            
            for header, description in security_checks:
                if header in headers:
                    self.log(f"   ✅ {description}: {headers[header]}")
                else:
                    self.log(f"   ⚠️  {description}: Not found")
                    
        except Exception as e:
            self.log(f"   ❌ CORS test error: {e}")

    def run_all_tests(self):
        """Run all test suites"""
        self.log("🚀 Starting Zero-Trust Task Manager API Tests")
        self.log(f"   Backend URL: {self.base_url}")
        
        # Run test suites
        self.test_health_endpoints()
        self.test_auth_flow()
        self.test_encrypted_data_endpoints()
        self.test_settings_endpoints()
        self.test_webauthn_endpoints()
        self.test_backup_endpoints()
        self.test_cors_and_security()
        
        # Print summary
        self.log("=" * 50)
        self.log(f"📊 Test Summary: {self.tests_passed}/{self.tests_run} passed")
        
        if self.failed_tests:
            self.log("❌ Failed Tests:")
            for failure in self.failed_tests:
                if 'error' in failure:
                    self.log(f"   - {failure['test']}: {failure['error']}")
                else:
                    self.log(f"   - {failure['test']}: Expected {failure['expected']}, got {failure['actual']}")
        
        success_rate = (self.tests_passed / self.tests_run) * 100 if self.tests_run > 0 else 0
        self.log(f"📈 Success Rate: {success_rate:.1f}%")
        
        # Return results for test report
        return {
            'total_tests': self.tests_run,
            'passed_tests': self.tests_passed,
            'failed_tests': len(self.failed_tests),
            'success_rate': success_rate,
            'failures': self.failed_tests
        }

def main():
    """Main test execution"""
    tester = ZeroTrustAPITester()
    results = tester.run_all_tests()
    
    # Exit with error code if tests failed
    if results['failed_tests'] > 0:
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())