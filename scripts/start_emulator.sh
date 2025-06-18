#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
TEST_MODE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_MODE="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Start PocketBase emulator for development or testing"
            echo ""
            echo "Options:"
            echo "  --test       Start with test collections and users setup"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0              # Start clean PocketBase for development"
            echo "  $0 --test       # Start PocketBase with test data for testing"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Configure directories based on mode
PB_DIR="pb_data"
if [ "$TEST_MODE" = "true" ]; then
    print_info "Starting PocketBase in TEST mode"
else
    print_info "Starting PocketBase in DEVELOPMENT mode"
fi

# Clean previous data
if [ "$TEST_MODE" = "true" ]; then
    print_info "Cleaning previous test data..."
    rm -rf pb_data
    rm -rf pb_migrations
fi

mkdir -p "$PB_DIR"

print_info "Setting up PocketBase..."

# Check PocketBase installed
if ! command -v pocketbase &>/dev/null; then
    print_error "PocketBase not found. Install from: https://pocketbase.io/docs/"
    exit 1
fi

# Start PocketBase in background
print_info "Starting PocketBase with $PB_DIR..."
pocketbase serve --dir="$PB_DIR" --http="127.0.0.1:8090" &
PB_PID=$!

# Function to cleanup on exit
cleanup() {
    if [ ! -z "$PB_PID" ] && kill -0 $PB_PID 2>/dev/null; then
        print_info "Stopping PocketBase (PID: $PB_PID)..."
        kill $PB_PID 2>/dev/null || true
        wait $PB_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Wait for PocketBase to initialize
print_info "Waiting for PocketBase to initialize..."
sleep 3

# Verify PocketBase is responding
for i in {1..10}; do
    if curl -s "http://127.0.0.1:8090/api/health" > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 10 ]; then
        print_error "PocketBase is not responding after 10 attempts"
        exit 1
    fi
    sleep 1
done

print_success "PocketBase is running at http://127.0.0.1:8090"

# If test mode, set up test collections and users
if [ "$TEST_MODE" = "true" ]; then
    print_info "Setting up test collections and users..."
    
    # Create superuser (admin for API access)
    print_info "Creating superuser..."
    pocketbase superuser upsert test@test.com testpassword123 --dir="$PB_DIR" > /dev/null 2>&1
    
    # Wait for superuser to be ready
    sleep 2
    
    # Get admin token for API calls
    print_info "Getting admin token..."
    ADMIN_TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/_superusers/auth-with-password \
      -H "Content-Type: application/json" \
      -d '{
        "identity": "test@test.com",
        "password": "testpassword123"
      }' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$ADMIN_TOKEN" ]; then
        print_error "Failed to get admin token"
        exit 1
    fi
    
    print_success "Admin token obtained"
    
    # Create products collection via API
    print_info "Creating products collection..."
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
      "name": "price",
      "type": "number",
      "required": true
    },
    {
      "name": "description",
      "type": "text",
      "required": false
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
    
    COLLECTION_RESPONSE=$(curl -s -X POST http://127.0.0.1:8090/api/collections \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d @/tmp/products_collection.json)
    
    if echo "$COLLECTION_RESPONSE" | grep -q '"id"'; then
        print_success "Products collection created"
    else
        print_error "Failed to create collection"
        echo "Full response: $COLLECTION_RESPONSE"
        exit 1
    fi
    
    # Clean up temp file
    rm -f /tmp/products_collection.json
    
    # Create test user
    print_info "Creating test user..."
    USER_RESPONSE=$(curl -s -X POST http://127.0.0.1:8090/api/collections/users/records \
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
        print_warning "User might already exist or there was an error"
    fi
    
    echo ""
    print_success "Test setup complete!"
    echo "👥 Test user: testuser@example.com / testuser123"
    echo "👤 Admin:     test@test.com / testpassword123"
fi

echo ""
print_success "PocketBase emulator ready!"
echo "🟢 Server: http://127.0.0.1:8090"
echo "🔗 Admin UI: http://127.0.0.1:8090/_/"
if [ "$TEST_MODE" = "false" ]; then
    echo "💡 Use --test flag to start with test collections"
fi
echo ""
print_info "Press Ctrl+C to stop PocketBase"

# Wait to keep the server running
wait $PB_PID
