# Deployment Guide

## Prerequisites

Before deploying, you need to configure the following secrets in your GitHub repository:

1. Go to: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

2. Add the following secrets:

### Required Secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PRIVATE_KEY` | Deployer wallet private key (without 0x prefix) | `ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| `BASE_SEPOLIA_RPC` | Base Sepolia RPC URL | `https://sepolia.base.org` or Alchemy/Infura endpoint |
| `BASE_MAINNET_RPC` | Base Mainnet RPC URL | `https://mainnet.base.org` or Alchemy/Infura endpoint |
| `BASESCAN_API_KEY` | Basescan API key for contract verification (optional) | Get from [basescan.org/myapikey](https://basescan.org/myapikey) |

**Note:** USDC addresses are hardcoded in the workflow:
- Base Sepolia: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- Base Mainnet: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

### Example RPC URLs

**Base Sepolia (Testnet):**
```
https://sepolia.base.org
https://base-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
https://base-sepolia.infura.io/v3/YOUR_INFURA_KEY
```

**Base Mainnet:**
```
https://mainnet.base.org
https://base-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
https://base.infura.io/v3/YOUR_INFURA_KEY
```

## Deployment via GitHub Actions

### Initial Deployment

1. Go to: **Actions** → **Deploy to Base**
2. Click: **Run workflow**
3. Select:
   - Branch: `testing`
   - Network: `base-sepolia` (for testnet) or `base-mainnet` (for production)
4. Click: **Run workflow**

The deployment will:
- Deploy the implementation contract
- Deploy the UUPS proxy
- Initialize the contract with USDC address
- Verify contracts on Basescan

### Contract Upgrade

1. Go to: **Actions** → **Upgrade Contract**
2. Click: **Run workflow**
3. Select:
   - Branch: `testing`
   - Network: `base-sepolia` or `base-mainnet`
   - Proxy Address: Address of the deployed proxy contract
4. Click: **Run workflow**

## Local Deployment

### Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
```

### Deploy to Testnet

```bash
# Set environment variables
export PRIVATE_KEY="your_private_key"
export USDC_ADDRESS="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
export BASE_SEPOLIA_RPC="https://sepolia.base.org"

# Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC \
  --broadcast \
  --verify
```

### Deploy to Mainnet

```bash
# Set environment variables
export PRIVATE_KEY="your_private_key"
export USDC_ADDRESS="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
export BASE_MAINNET_RPC="https://mainnet.base.org"
export BASESCAN_API_KEY="your_api_key"

# Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_MAINNET_RPC \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

## Useful Addresses

### Base Sepolia (Testnet)
- **USDC:** `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **Network ID:** 84532
- **Block Explorer:** https://sepolia.basescan.org

### Base Mainnet
- **USDC:** `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Network ID:** 8453
- **Block Explorer:** https://basescan.org

## Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run with coverage
forge coverage
```

## Security Notes

- Never commit private keys to the repository
- Always test on testnet before mainnet deployment
- Verify contracts on Basescan after deployment
- Use hardware wallet or secure key management for mainnet deployments
- Review all transactions before broadcasting
