# SubBase

**Modular subscription protocol on Base**

SubBase is a fully upgradeable, Base-native subscription infrastructure that enables automated recurring USDC payment flows using UUPS proxy architecture and modular design.

## Overview

SubBase provides the foundational infrastructure for subscription-based services on Base:

- ✅ **Flexible subscription plans** - Creators define pricing and billing periods
- ✅ **Automated billing** - USDC-based recurring payments
- ✅ **Full upgradeability** - UUPS proxy pattern for protocol evolution
- ✅ **Modular architecture** - Clean separation of concerns
- ✅ **Base-native** - Built specifically for Base L2

## Key Features

### For Creators
- Create subscription plans with custom pricing and billing cycles
- Receive USDC payments directly
- Manage plan metadata and availability

### For Subscribers
- Subscribe to plans with immediate payment
- Cancel subscriptions at any time
- Track all active subscriptions

### For Developers
- Upgradeable smart contracts (UUPS)
- Clean modular architecture
- Gas-optimized operations
- Comprehensive event emission for indexing

## Architecture

SubBase uses a modular architecture with UUPS upgradeability:

```
UUPS Proxy (Immutable Address)
    ↓
SubBaseV1 Implementation
    ├── PlanModule
    └── SubscriptionModule
```

**Modules:**
- `PlanModule` - Plan creation and management
- `SubscriptionModule` - Subscription lifecycle (subscribe, cancel)

**Storage:** Centralized with upgrade-safe gap pattern

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed system design.

## Contracts

### Base Sepolia (Testnet)
- **Proxy:** [`0x8B182755Ae296e8f222Ac4E677B7Cc63dFDe7BA0`](https://sepolia.basescan.org/address/0x8B182755Ae296e8f222Ac4E677B7Cc63dFDe7BA0)
- **Implementation:** [`0x3c23B4A023D2A8c142d587D476BB77E4c91E15ab`](https://sepolia.basescan.org/address/0x3c23B4A023D2A8c142d587D476BB77E4c91E15ab)

### Base Mainnet
- **Proxy:** [`0xfa34E4c68c77D54dD8B694c8395953465129E3c9`](https://basescan.org/address/0xfa34E4c68c77D54dD8B694c8395953465129E3c9)
- **Implementation:** [`0x005DF73314a58773588a7ADbBcE18c6d87ca724E`](https://basescan.org/address/0x005DF73314a58773588a7ADbBcE18c6d87ca724E)

## Usage Examples

### Create a Plan

```solidity
// Create monthly subscription plan for 10 USDC
uint256 planId = subbase.createPlan(
    10e6,      // price (10 USDC, 6 decimals)
    30 days,   // billing period
    "Premium Membership"  // metadata
);
```

### Subscribe to Plan

```solidity
// Approve USDC spending first
IERC20(usdc).approve(proxyAddress, planPrice);

// Subscribe (immediate payment)
uint256 subscriptionId = subbase.subscribe(planId);
```

### Cancel Subscription

```solidity
subbase.cancel(subscriptionId);
```

### Query Subscriptions

```solidity
// Get specific subscription
Subscription memory sub = subbase.getSubscription(subscriptionId);

// Get all user subscriptions
uint256[] memory userSubs = subbase.getUserSubscriptions(userAddress);
```
## Roadmap

**v1 (Current)** - Minimal viable subscription protocol
- Plan creation
- Subscribe/cancel
- USDC payments

**v2 (Planned)** - Enhanced billing engine
- Automated charge attempts
- Retry logic with configurable strategies
- Grace periods
- Past-due status handling

**v3 (Planned)** - Advanced features
- Trial periods
- Proration for mid-cycle changes
- Multi-token support
- Subscription transfers

**Future** - Full ecosystem
- Analytics module
- Subgraph integration
- Mini App integration
- DAO governance

## Security

- UUPS upgradeable pattern with owner-only upgrades
- ReentrancyGuard on payment operations
- Custom errors for gas efficiency
- Storage gaps for safe upgrades

**Audits:** Not yet audited - use at your own risk

## License

MIT License - see [LICENSE](./LICENSE)

## Links

- **Contracts:** [contracts.json](./contracts.json)
- **Architecture:** [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Base:** [base.org](https://base.org)
