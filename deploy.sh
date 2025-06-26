#!/bin/bash

# WalkScape Contract Deployment Script for Starknet Sepolia
# This script deploys the WalkScape contract to Starknet Sepolia testnet

set -e

echo "🌱 WalkScape Contract Deployment to Starknet Sepolia"
echo "=================================================="

# Check if required tools are installed
if ! command -v sncast &> /dev/null; then
    echo "❌ Error: sncast not found. Please install Starknet Foundry."
    echo "Visit: https://foundry-rs.github.io/starknet-foundry/"
    exit 1
fi

if ! command -v scarb &> /dev/null; then
    echo "❌ Error: scarb not found. Please install Scarb."
    echo "Visit: https://docs.swmansion.com/scarb/"
    exit 1
fi

# Build the contract
echo "🔨 Building WalkScape contract..."
scarb build
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please fix compilation errors."
    exit 1
fi

echo "✅ Contract built successfully!"

# Get the admin address (using the walkscape_deployer account)
ADMIN_ADDRESS="0x154987c2e5da4057732b005c5a9c747f15a15602fba13152d68744d23e29da6"
echo "📋 Admin address: $ADMIN_ADDRESS"

# Declare the contract
echo "📤 Declaring WalkScapeCore contract..."
DECLARE_OUTPUT=$(sncast --profile sepolia declare --contract-name WalkScapeCore 2>&1)
echo "$DECLARE_OUTPUT"

# Extract class hash from declare output - try multiple patterns
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -E "(class_hash|Class hash):" | sed -E 's/.*class_hash:?\s*([0-9a-fx]+).*/\1/' | head -1)
if [ -z "$CLASS_HASH" ]; then
    echo "❌ Failed to extract class hash. Trying alternative extraction..."
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE "0x[0-9a-f]{64}" | head -1)
fi
if [ -z "$CLASS_HASH" ]; then
    echo "❌ Failed to extract class hash. Check declare output above."
    echo "💡 Try running manually: sncast --profile sepolia declare --contract-name WalkScapeCore"
    exit 1
fi

echo "✅ Contract declared successfully!"
echo "📋 Class Hash: $CLASS_HASH"

# Deploy the contract with admin address as constructor parameter
echo "🚀 Deploying WalkScapeCore contract..."
DEPLOY_OUTPUT=$(sncast --profile sepolia deploy --class-hash "$CLASS_HASH" --constructor-calldata "$ADMIN_ADDRESS" 2>&1)
echo "$DEPLOY_OUTPUT"

# Extract contract address from deploy output - try multiple patterns
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -E "(contract_address|Contract address):" | sed -E 's/.*contract_address:?\s*([0-9a-fx]+).*/\1/' | head -1)
if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "❌ Failed to extract contract address. Trying alternative extraction..."
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[0-9a-f]{64}" | tail -1)
fi
if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "❌ Failed to extract contract address. Check deploy output above."
    echo "💡 Try running manually: sncast --profile sepolia deploy --class-hash $CLASS_HASH --constructor-calldata $ADMIN_ADDRESS"
    exit 1
fi

echo ""
echo "🎉 WalkScape Contract Deployed Successfully!"
echo "============================================"
echo "📋 Contract Address: $CONTRACT_ADDRESS"
echo "📋 Class Hash: $CLASS_HASH"
echo "📋 Admin Address: $ADMIN_ADDRESS"
echo "🌐 Network: Starknet Sepolia"
echo ""
echo "🔗 Verify on StarkScan:"
echo "   https://sepolia.starkscan.co/contract/$CONTRACT_ADDRESS"
echo ""
echo "💡 Next Steps:"
echo "   1. Update your frontend .env.local with the contract address:"
echo "      NEXT_PUBLIC_CONTRACT_ADDRESS=$CONTRACT_ADDRESS"
echo "   2. Update your frontend .env.local with the RPC URL:"
echo "      NEXT_PUBLIC_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/kwgGr9GGk4YyLXuGfEvpITv1jpvn3PgP"
echo "   3. Test the contract with sncast calls"
echo ""

# Save deployment info to file
cat > deployment_info.json << EOF
{
  "network": "starknet-sepolia",
  "contract_name": "WalkScapeCore",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "admin_address": "$ADMIN_ADDRESS",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "rpc_url": "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/kwgGr9GGk4YyLXuGfEvpITv1jpvn3PgP",
  "explorer_url": "https://sepolia.starkscan.co/contract/$CONTRACT_ADDRESS"
}
EOF

echo "📄 Deployment info saved to deployment_info.json"
