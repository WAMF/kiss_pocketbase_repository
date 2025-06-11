#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PB_DIR="test_pb_data"
PB_HOST="127.0.0.1"
PB_PORT="8090"
PB_URL="http://$PB_HOST:$PB_PORT"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to cleanup PocketBase process
cleanup() {
    if [ ! -z "$PB_PID" ] && kill -0 $PB_PID 2>/dev/null; then
        print_status "Stopping PocketBase (PID: $PB_PID)..."
        kill $PB_PID 2>/dev/null || true
        wait $PB_PID 2>/dev/null || true
        print_success "PocketBase stopped"
    fi
    
    if [ "$CLEANUP_DATA" = "true" ]; then
        print_status "Cleaning up test data..."
        rm -rf "$PB_DIR" 2>/dev/null || true
        rm -rf pb_migrations 2>/dev/null || true
        print_success "Test data cleaned up"
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Parse command line arguments
CLEANUP_DATA="true"
VERBOSE="false"
SPECIFIC_TEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup)
            CLEANUP_DATA="false"
            shift
            ;;
        --verbose|-v)
            VERBOSE="true"
            shift
            ;;
        --test|-t)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-cleanup     Don't clean up test data after running"
            echo "  --verbose, -v    Enable verbose output"
            echo "  --test, -t TEST  Run specific test file (e.g., centralized_crud_test.dart)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Available tests:"
            echo "  all_integration_tests.dart (default - runs all tests)"
            echo "  centralized_crud_test.dart"
            echo "  centralized_batch_test.dart"
            echo "  centralized_query_test.dart"
            echo "  centralized_streaming_test.dart"
            echo "  centralized_error_test.dart"
            echo "  id_validation_test.dart"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default test file
if [ -z "$SPECIFIC_TEST" ]; then
    SPECIFIC_TEST="all_integration_tests.dart"
fi

print_status "Starting PocketBase Integration Tests"
print_status "Test file: $SPECIFIC_TEST"
print_status "Cleanup data: $CLEANUP_DATA"

# Check if PocketBase is installed
if ! command -v pocketbase &>/dev/null; then
    print_error "PocketBase not found. Please install from: https://pocketbase.io/docs/"
    exit 1
fi

# Check if dart is available
if ! command -v dart &>/dev/null; then
    print_error "Dart not found. Please install Dart SDK"
    exit 1
fi

# Clean previous data if it exists
if [ -d "$PB_DIR" ]; then
    print_status "Cleaning previous test data..."
    rm -rf "$PB_DIR"
    rm -rf pb_migrations 2>/dev/null || true
fi

# Create PocketBase data directory
mkdir -p "$PB_DIR"

# Start PocketBase in background
print_status "Starting PocketBase server..."
if [ "$VERBOSE" = "true" ]; then
    pocketbase serve --dir="$PB_DIR" --http="$PB_HOST:$PB_PORT" &
else
    pocketbase serve --dir="$PB_DIR" --http="$PB_HOST:$PB_PORT" > /dev/null 2>&1 &
fi
PB_PID=$!

# Wait for PocketBase to start
print_status "Waiting for PocketBase to initialize..."
sleep 3

# Check if PocketBase is running
if ! kill -0 $PB_PID 2>/dev/null; then
    print_error "Failed to start PocketBase"
    exit 1
fi

# Verify PocketBase is responding
for i in {1..10}; do
    if curl -s "$PB_URL/api/health" > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 10 ]; then
        print_error "PocketBase is not responding after 10 attempts"
        exit 1
    fi
    sleep 1
done

print_success "PocketBase is running at $PB_URL"

# Create superuser
print_status "Creating superuser..."
pocketbase superuser upsert test@test.com testpassword123 --dir="$PB_DIR" > /dev/null 2>&1

# Wait a bit more for the superuser to be ready
sleep 2

# Get admin token
print_status "Obtaining admin authentication token..."
ADMIN_TOKEN=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
  -H "Content-Type: application/json" \
  -d '{
    "identity": "test@test.com",
    "password": "testpassword123"
  }' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
    print_error "Failed to obtain admin token"
    exit 1
fi

print_success "Admin token obtained"

# Create products collection
print_status "Creating products collection..."
cat > /tmp/products_collection.json <<EOF
{
  "name": "products",
  "type": "base",
  "fields": [
    {
      "name": "name",
      "type": "text",
      "required": true
    },
    {
      "name": "created",
      "type": "autodate",
      "onCreate": true,
      "onUpdate": false
    },
    {
      "name": "updated",
      "type": "autodate",
      "onCreate": true,
      "onUpdate": true
    }
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "@request.auth.id != \"\"",
  "updateRule": "@request.auth.id != \"\"",
  "deleteRule": "@request.auth.id != \"\""
}
EOF

COLLECTION_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d @/tmp/products_collection.json)

if echo "$COLLECTION_RESPONSE" | grep -q '"id"'; then
    print_success "products collection created"
else
    print_error "Failed to create products collection"
    if [ "$VERBOSE" = "true" ]; then
        echo "Response: $COLLECTION_RESPONSE"
    fi
    exit 1
fi

# Clean up temp file
rm -f /tmp/products_collection.json

# Create test user
print_status "Creating test user..."
USER_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "email": "testuser@example.com",
    "password": "testuser123",
    "passwordConfirm": "testuser123",
    "name": "Test User"
  }')

if echo "$USER_RESPONSE" | grep -q '"id"'; then
    print_success "Test user created"
else
    print_warning "Test user might already exist or there was an error"
    if [ "$VERBOSE" = "true" ]; then
        echo "Response: $USER_RESPONSE"
    fi
fi

print_success "PocketBase setup complete!"
echo ""
print_status "🟢 PocketBase running at: $PB_URL"
print_status "🔗 Admin UI: $PB_URL/_/"
print_status "👥 Test user: testuser@example.com / testuser123"
print_status "👤 Admin: test@test.com / testpassword123"
echo ""

# Run the integration tests
print_status "Running integration tests: $SPECIFIC_TEST"
echo "=================================================================================="

if [ "$VERBOSE" = "true" ]; then
    dart test test/integration/"$SPECIFIC_TEST" --chain-stack-traces --reporter=expanded
else
    dart test test/integration/"$SPECIFIC_TEST"
fi

TEST_EXIT_CODE=$?

echo "=================================================================================="

if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_success "All tests passed! ✅"
else
    print_error "Some tests failed! ❌ (Exit code: $TEST_EXIT_CODE)"
fi

print_status "Integration test run completed"

# Exit with the same code as the tests
exit $TEST_EXIT_CODE 