#!/bin/zsh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_colored $BLUE "🔍 Medito Paywall Environment Checker"
print_colored $BLUE "====================================="
echo ""

# Check if environment files exist
if [ -f "../.prod.json" ]; then
    print_colored $GREEN "✅ Production environment file found: ../.prod.json"
    
    # Extract Superwall API key (same key used for both platforms)
    PROD_SUPERWALL_KEY=$(grep -o '"SUPERWALL_API_KEY": "[^"]*"' ../.prod.json | cut -d'"' -f4)
    
    if [ -n "$PROD_SUPERWALL_KEY" ]; then
        print_colored $GREEN "  🔑 Superwall API Key: ${PROD_SUPERWALL_KEY:0:10}..."
        print_colored $BLUE "    (Used for both iOS and Android)"
    else
        print_colored $RED "  ❌ Superwall API Key not found"
    fi
else
    print_colored $RED "❌ Production environment file not found: ../.prod.json"
fi

echo ""

if [ -f "../.staging.json" ]; then
    print_colored $GREEN "✅ Staging environment file found: ../.staging.json"
    
    # Extract Superwall API key (same key used for both platforms)
    STAGING_SUPERWALL_KEY=$(grep -o '"SUPERWALL_API_KEY": "[^"]*"' ../.staging.json | cut -d'"' -f4)

    if [ -n "$STAGING_SUPERWALL_KEY" ]; then
        print_colored $GREEN "  🔑 Superwall API Key: ${STAGING_SUPERWALL_KEY:0:10}..."
        print_colored $BLUE "    (Used for both iOS and Android)"
    else
        print_colored $RED "  ❌ Superwall API Key not found"
    fi
else
    print_colored $RED "❌ Staging environment file not found: ../.staging.json"
fi

echo ""

# Check if API keys are the same (which would be a problem)
if [ -n "$PROD_SUPERWALL_KEY" ] && [ -n "$STAGING_SUPERWALL_KEY" ]; then
    if [ "$PROD_SUPERWALL_KEY" = "$STAGING_SUPERWALL_KEY" ]; then
        print_colored $YELLOW "⚠️  WARNING: Production and Staging Superwall API keys are the same!"
        print_colored $YELLOW "   This means both environments use the same paywall configuration."
    else
        print_colored $GREEN "✅ Production and Staging Superwall API keys are different (good)"
    fi
fi

echo ""
print_colored $BLUE "📋 Quick Reference:"
print_colored $BLUE "==================="
echo "• Use build_and_deploy_all.sh for all builds"
echo "• Script will ask you to choose: Live or Dev paywalls"
echo "• Dev paywalls are safe for TestFlight and Play Store Internal Testing"
echo "• Live paywalls are safe for production deployment"
echo ""
print_colored $YELLOW "💡 Tip: If API keys are the same, you may need to configure different"
print_colored $YELLOW "   Superwall projects for production vs staging environments."
