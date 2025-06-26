# Manual WalkScape Contract Deployment Guide

## Summary
Your WalkScape contract has been successfully built and is ready for deployment. Due to some network connectivity issues with the automated script, here's a manual deployment guide.

## What We Know
- **Class Hash**: `0x0216461ae25bc056d7ba28062dde6c756d48ea497e07af40b420f94ee0843078`
- **Admin Address**: `0x2a52da1138a756389181993e8d71c3a107c140e3a59f8e1d7e533e8e700f05f`
- **Account**: `myaccount` configured in snfoundry.toml

## Manual Deployment Steps

### Step 1: Deploy Contract (if not already done)
Run this command manually in your terminal:

```bash
cd /Users/mac/Desktop/CODE/cairo_projects/walkscape
sncast --profile sepolia deploy --class-hash 0x0216461ae25bc056d7ba28062dde6c756d48ea497e07af40b420f94ee0843078 --constructor-calldata 0x2a52da1138a756389181993e8d71c3a107c140e3a59f8e1d7e533e8e700f05f
```

### Step 2: Update Frontend Configuration
Once you get the contract address from the deploy output, update your frontend:

1. Edit `/Users/mac/Desktop/CODE/cairo_projects/walkscape_frontend/.env.local`
2. Replace the contract address:
```bash
NEXT_PUBLIC_CONTRACT_ADDRESS=<YOUR_DEPLOYED_CONTRACT_ADDRESS>
NEXT_PUBLIC_RPC_URL=https://starknet-sepolia.public.blastapi.io
```

### Step 3: Test Contract Functions
After deployment, test with these commands:

```bash
# Register a player
sncast --profile sepolia invoke --contract-address <CONTRACT_ADDRESS> --function register_player

# Get player stats
sncast --profile sepolia call --contract-address <CONTRACT_ADDRESS> --function get_player_stats --calldata 0x2a52da1138a756389181993e8d71c3a107c140e3a59f8e1d7e533e8e700f05f
```

### Step 4: Verify on StarkScan
Visit: https://sepolia.starkscan.co/contract/<CONTRACT_ADDRESS>

## Alternative RPC Endpoints (if current one fails)
If you encounter issues, try updating snfoundry.toml with:

```toml
[sncast.sepolia]
account = "myaccount"
accounts-file = "/Users/mac/.starknet_accounts/starknet_open_zeppelin_accounts.json"
url = "https://free-rpc.nethermind.io/sepolia-juno/v0_7"
wait-params = { timeout = 300, retry-interval = 10 }
```

## Contract Features Available
Once deployed, your contract supports:
- ✅ Player registration
- ✅ XP tracking and health scores
- ✅ Artifact claiming system
- ✅ Pet minting and evolution
- ✅ Colony creation and joining
- ✅ Staking for growth rewards
- ✅ Daily "touch grass" check-ins

## Frontend Integration
Your frontend is already configured with:
- Wallet connection (ArgentX/Braavos support)
- Contract interaction utilities
- Beautiful UI components for all game features
- Mobile-first responsive design

## Need Help?
If you encounter any issues:
1. Check your internet connection
2. Verify your account has enough ETH for gas fees
3. Try different RPC endpoints
4. Check StarkScan for transaction status
