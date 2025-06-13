#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
            echo "Run PocketBase integration tests with automatic backend setup"
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
            echo ""
            echo "This script will automatically:"
            echo "  1. Start PocketBase with test collections"
            echo "  2. Run the specified tests"
            echo "  3. Clean up test data (unless --no-cleanup)"
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

# Check if dart is available
if ! command -v dart &>/dev/null; then
    print_error "Dart not found. Please install Dart SDK"
    exit 1
fi

# Check if PocketBase emulator is running
if ! curl -s "http://127.0.0.1:8090/api/health" > /dev/null 2>&1; then
    print_error "PocketBase emulator is not running!"
    print_status "Start it first with: ./scripts/start_emulator.sh --test"
    print_status "   (or run it in another terminal)"
    exit 1
fi

print_success "PocketBase emulator is running at http://127.0.0.1:8090"

# Function to cleanup (only if cleanup flag is set and we don't want to keep data)
cleanup() {
    if [ "$CLEANUP_DATA" = "true" ]; then
        print_status "Note: Test data cleanup should be done by stopping the emulator"
        print_status "Use Ctrl+C on the emulator terminal to clean up test data"
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Run the tests
print_status "Running integration tests..."
print_status "Test file: test/integration/$SPECIFIC_TEST"

if [ "$VERBOSE" = "true" ]; then
    dart test "test/integration/$SPECIFIC_TEST" --reporter=expanded
else
    dart test "test/integration/$SPECIFIC_TEST"
fi

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_success "All integration tests passed!"
else
    print_error "Some integration tests failed (exit code: $TEST_EXIT_CODE)"
fi

exit $TEST_EXIT_CODE 