#!/bin/bash

# WalkScape Contract Deployment Script for Starknet Sepolia
# This script deploys the WalkScape contract to Starknet Sepolia testnet

set -e

echo "🌱 WalkScape Contract Deployment to Starknet Sepolia"
echo "=================================================="

# Admin address
ADMIN_ADDRESS="0x154987c2e5da4057732b005c5a9c747f15a15602fba13152d68744d23e29da6"

# Build the contract
echo "🔨 Building WalkScape contract..."
scarb build

echo "✅ Contract built successfully!"
echo "📋 Admin address: $ADMIN_ADDRESS"

# Step 1: Declare the contract
echo ""
echo "📤 Step 1: Declaring WalkScapeCore contract..."
echo "⏳ This may take a few minutes, please wait..."

# Use a simple declare command without capturing output first
sncast --profile sepolia declare --contract-name WalkScapeCore

echo ""
echo "✅ Declaration completed!"

# Step 2: Get the class hash from the build artifacts
echo ""
echo "📋 Step 2: Getting class hash from build artifacts..."

# Read class hash from the build artifacts
if [ -f "target/sepolia/walkscape_WalkScapeCore.contract_class.json" ]; then
    echo "✅ Found contract class file in sepolia target"
elif [ -f "target/dev/walkscape_WalkScapeCore.contract_class.json" ]; then
    echo "✅ Found contract class file in dev target"
else
    echo "❌ Could not find contract class file. Please check build output."
    echo "Available files in target/:"
    ls -la target/
    if [ -d "target/dev" ]; then
        echo "Files in target/dev/:"
        ls -la target/dev/
    fi
    if [ -d "target/sepolia" ]; then
        echo "Files in target/sepolia/:"
        ls -la target/sepolia/
    fi
    exit 1
fi

# Manual class hash entry (you'll need to enter this from the declare output)
echo ""
echo "🔍 Please enter the class hash from the declare output above:"
read -p "Class Hash (0x...): " CLASS_HASH

if [[ ! "$CLASS_HASH" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    echo "❌ Invalid class hash format. Should be 0x followed by 64 hex characters."
    exit 1
fi

echo "📋 Using Class Hash: $CLASS_HASH"

# Step 3: Deploy the contract
echo ""
echo "🚀 Step 3: Deploying WalkScapeCore contract..."
echo "⏳ This may take a few minutes, please wait..."

sncast --profile sepolia deploy --class-hash "$CLASS_HASH" --constructor-calldata "$ADMIN_ADDRESS"

echo ""
echo "✅ Deployment completed!"

echo ""
echo "📋 Manual verification commands:"
echo "================================="
echo ""
echo "1. Check contract on StarkScan:"
echo "   https://sepolia.starkscan.co/search?q=$CLASS_HASH"
echo ""
echo "2. Test contract call (replace CONTRACT_ADDRESS with deployed address):"
echo "   sncast --profile sepolia call --contract-address CONTRACT_ADDRESS --function get_player_stats --calldata $ADMIN_ADDRESS"
echo ""
echo "3. Register player (replace CONTRACT_ADDRESS with deployed address):"
echo "   sncast --profile sepolia invoke --contract-address CONTRACT_ADDRESS --function register_player"
echo ""

echo "💡 Next Steps:"
echo "1. Copy the deployed contract address from the output above"
echo "2. Update your frontend .env.local with:"
echo "   NEXT_PUBLIC_CONTRACT_ADDRESS=<DEPLOYED_CONTRACT_ADDRESS>"
echo "3. Test your frontend application"
