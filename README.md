# SubBase — Decentralized Subscription Protocol

> **The first fully decentralized subscription infrastructure on Base L2**
> Automate recurring payments with on-chain guarantees, zero intermediaries, and Chainlink Automation integration.

[![Base](https://img.shields.io/badge/Built%20on-Base-0052FF?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgdmlld0JveD0iMCAwIDEwMCAxMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiBmaWxsPSIjMDA1MkZGIi8+Cjwvc3ZnPgo=)](https://base.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?style=for-the-badge)](https://getfoundry.sh/)

---

## 🌟 Overview

SubBase is a **permissionless subscription protocol** that enables creators, businesses, and DAOs to monetize their services with **automated recurring payments** on Base L2.

### Why SubBase?

- ✅ **Zero Platform Fees** — No intermediaries, 100% revenue goes to creators
- ✅ **Automated Billing** — Chainlink Automation handles recurring charges
- ✅ **Grace Periods** — 7-day grace period for failed payments
- ✅ **UUPS Upgradeable** — Protocol can evolve without migration
- ✅ **Gas Efficient** — Batch processing up to 50 subscriptions per transaction
- ✅ **Open Source** — MIT licensed, fully auditable

---

## 📊 Protocol Stats

| Metric | Value |
|--------|-------|
| **Network** | Base Mainnet (Chain ID: 8453) |
| **Contract Address** | `0xfa34E4c68c77D54dD8B694c8395953465129E3c9` |
| **Payment Token** | USDC |
| **Grace Period** | 7 days |
| **Max Retries** | 3 attempts |
| **Version** | 2.0.0 |

📍 [View on BaseScan](https://basescan.org/address/0xfa34E4c68c77D54dD8B694c8395953465129E3c9)

---

## 🚀 Quick Start

### For Creators

Create a subscription plan in 3 steps:

```javascript
import { SubBase } from '@subbase/sdk';

// 1. Initialize SubBase
const subbase = new SubBase({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY
});

// 2. Create a plan
const plan = await subbase.createPlan({
  price: '10000000', // 10 USDC (6 decimals)
  billingPeriod: 30 * 24 * 60 * 60, // 30 days in seconds
  metadata: 'Premium Membership'
});

console.log(`Plan created: ${plan.id}`);
```

### For Subscribers

Subscribe to any plan:

```javascript
// 1. Approve USDC
await subbase.approveUSDC();

// 2. Subscribe to a plan
const subscription = await subbase.subscribe(planId);

console.log(`Subscribed! Next billing: ${subscription.nextBillingTime}`);
```

---

## 🏗️ Architecture

SubBase is built with a **modular, upgradeable architecture**:

```
┌─────────────────────────────────────────┐
│         SubBaseV2 (Proxy)               │
│  0xfa34E4c68c77D54dD8B694c8395953465129E3c9  │
└─────────────────────────────────────────┘
              │
              ├─── PlanModule
              │    └── Create & manage subscription plans
              │
              ├─── SubscriptionModule
              │    └── Subscribe & cancel subscriptions
              │
              ├─── ChargeModule
              │    └── Process recurring payments
              │    └── Handle failed payments
              │    └── Grace period management
              │
              └─── AutomationModule
                   └── Chainlink Automation integration
                   └── Batch processing (50 subs/tx)
```

---

## 💡 Core Features

### 1️⃣ Flexible Plans

Creators define their own terms:
- **Custom pricing** (any USDC amount)
- **Flexible billing cycles** (daily, weekly, monthly, yearly)
- **Metadata support** (plan descriptions, benefits, etc.)

### 2️⃣ Automated Billing

Powered by **Chainlink Automation**:
- Subscriptions automatically renew
- No manual intervention required
- Up to 50 subscriptions charged per transaction

### 3️⃣ Grace Period & Retries

Failed payments don't mean immediate cancellation:
- **7-day grace period** after first failure
- **3 retry attempts** before suspension
- Subscribers can reactivate suspended subscriptions

### 4️⃣ Status Flow

```
Active ──(payment fails)──> PastDue ──(3 failures)──> Suspended
  ↑                            │
  └────(payment success)───────┘
  └────(manual reactivate)─────────────────────┘
```

---

## 🔌 Integration Guide

### Smart Contract Integration

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubBase {
    function createPlan(
        uint256 price,
        uint256 billingPeriod,
        string memory metadata
    ) external returns (uint256 planId);

    function subscribe(uint256 planId) external returns (uint256 subscriptionId);

    function charge(uint256 subscriptionId) external returns (bool success);
}

contract YourContract {
    ISubBase public subbase = ISubBase(0xfa34E4c68c77D54dD8B694c8395953465129E3c9);

    function createSubscription() external {
        // Create plan: 10 USDC/month
        uint256 planId = subbase.createPlan(
            10_000000, // 10 USDC
            30 days,
            "Monthly Plan"
        );
    }
}
```

### JavaScript/TypeScript Integration

```typescript
import { ethers } from 'ethers';
import SubBaseABI from './deployments.json';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(privateKey, provider);

const subbase = new ethers.Contract(
  '0xfa34E4c68c77D54dD8B694c8395953465129E3c9',
  SubBaseABI,
  signer
);

// Get subscription details
const subscription = await subbase.getSubscription(subscriptionId);
console.log('Next billing:', new Date(subscription.nextBillingTime * 1000));

// Check if chargeable
const isChargeable = await subbase.isChargeable(subscriptionId);
```

---

## 📡 Chainlink Automation Setup

SubBase is **Chainlink Automation compatible** out of the box.

### Register Upkeep

1. Go to [Chainlink Automation](https://automation.chain.link/)
2. Click "Register New Upkeep"
3. Use these parameters:
   - **Contract address:** `0xfa34E4c68c77D54dD8B694c8395953465129E3c9`
   - **Upkeep name:** SubBase Auto-Billing
   - **Gas limit:** 2,000,000
   - **Check data:** `0x` (empty)

SubBase will automatically:
- Detect subscriptions due for billing
- Process up to 50 subscriptions per execution
- Handle partial failures gracefully

---

## 🛠️ Developer Resources

### Deployments

See [`deployments.json`](./deployments.json) for all contract addresses across networks.

### Testing

```bash
# Install dependencies
forge install

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Run specific test
forge test --match-test testCharge_Success -vvv
```

### Local Development

```bash
# Start local node
anvil

# Deploy to local
forge script script/DeployV1.s.sol --rpc-url http://localhost:8545 --broadcast
```

---

## 🔐 Security

SubBase prioritizes security:

- ✅ **OpenZeppelin contracts** for upgrade safety
- ✅ **Reentrancy guards** on all state-changing functions
- ✅ **Access control** with owner-only admin functions
- ✅ **UUPS proxy pattern** for secure upgrades
- ✅ **Comprehensive test coverage**

**Audit Status:** Self-audited. Professional audit coming soon.

---

## 📈 Use Cases

### 💼 SaaS & Services
- Developer tools subscriptions
- API access tiers
- Cloud services billing

### 🎓 Education & Content
- Online course access
- Premium content memberships
- Newsletter subscriptions

### 🎮 Gaming & Metaverse
- Battle pass systems
- VIP memberships
- In-game item subscriptions

### 🏢 DAOs & Communities
- Membership dues
- Governance participation fees
- Community access tiers

---

## 🗺️ Roadmap

- [x] **V1:** Core subscription functionality
- [x] **V2:** Auto-charge billing engine
- [x] **V2:** Chainlink Automation integration
- [x] **V2:** Grace periods & retry logic
- [ ] **V3:** Multi-token support (ETH, other ERC20s)
- [ ] **V3:** Discount codes & trials
- [ ] **V3:** Refund mechanisms
- [ ] **V3:** Analytics dashboard

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

### Development

```bash
# Clone repo
git clone https://github.com/karinasvatk/SubBase.git
cd SubBase

# Install dependencies
forge install

# Run tests
forge test
```

---

## 📜 License

SubBase is [MIT licensed](./LICENSE).

---

## 🔗 Links

- **Website:** Coming soon
- **Documentation:** [docs.subbase.xyz](https://docs.subbase.xyz) (Coming soon)
- **Twitter:** [@SubBaseProtocol](https://twitter.com/SubBaseProtocol) (Coming soon)
- **Discord:** [Join our community](https://discord.gg/subbase) (Coming soon)
- **BaseScan:** [View Contract](https://basescan.org/address/0xfa34E4c68c77D54dD8B694c8395953465129E3c9)

---

## 💬 Support

Need help? Reach out:

- **GitHub Issues:** [Report bugs or request features](https://github.com/karinasvatk/SubBase/issues)
- **Email:** savitskayakarrina@outlook.com

---

<div align="center">

**Built with ❤️ on Base**

*Making subscriptions truly decentralized*

[Get Started](https://basescan.org/address/0xfa34E4c68c77D54dD8B694c8395953465129E3c9) • [Documentation](#) • [Community](#)

</div>
