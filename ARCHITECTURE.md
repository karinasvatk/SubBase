# SubBase Architecture

## System Overview

SubBase is a modular, upgradeable subscription protocol built on Base using the UUPS proxy pattern.

```
┌─────────────────────────────────────────────────────┐
│                  User/dApp                          │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              UUPS Proxy (Upgradeable)               │
│    Sepolia: 0x8B182755Ae296e8f222Ac4E677B7Cc63d...  │
│    Mainnet: 0xfa34E4c68c77D54dD8B694c8395953465...  │ 
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│                  SubBaseV1                          │
│              (Implementation)                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐        ┌──────────────┐           │
│  │ PlanModule   │        │ Subscription │           │
│  │              │        │   Module     │           │
│  ├──────────────┤        ├──────────────┤           │
│  │ createPlan() │        │ subscribe()  │           │
│  │ getPlan()    │        │ cancel()     │           │
│  └──────────────┘        │ getSubscr... │           │
│                          │ getUserSub...│           │
│                          └──────────────┘           │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │         SubBaseStorage                      │    │
│  ├─────────────────────────────────────────────┤    │
│  │ mapping(uint256 => Plan)                    │    │
│  │ mapping(uint256 => Subscription)            │    │
│  │ mapping(address => uint256[])               │    │
│  │ uint256[44] __gap  (upgrade reserve)        │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              USDC Token (Base)                      │
└─────────────────────────────────────────────────────┘
```

## Core Components

### 1. SubBaseV1 (Main Contract)
Upgradeable contract that inherits from:
- `Initializable` - OpenZeppelin initialization pattern
- `UUPSUpgradeable` - Upgrade mechanism
- `ReentrancyGuardUpgradeable` - Protection against reentrancy
- `PlanModule` - Plan management
- `SubscriptionModule` - Subscription lifecycle

### 2. PlanModule
Manages subscription plans:
- `createPlan(price, billingPeriod, metadata)` - Create new plan
- `getPlan(planId)` - Get plan details

Plan structure:
```solidity
struct Plan {
    uint256 id;
    address creator;
    uint256 price;
    uint256 billingPeriod;
    string metadata;
    bool active;
    uint256 createdAt;
}
```

### 3. SubscriptionModule
Manages user subscriptions:
- `subscribe(planId)` - Subscribe to a plan (with immediate USDC payment)
- `cancel(subscriptionId)` - Cancel subscription
- `getSubscription(subscriptionId)` - Get subscription details
- `getUserSubscriptions(user)` - Get all user subscriptions

Subscription structure:
```solidity
struct Subscription {
    uint256 id;
    uint256 planId;
    address subscriber;
    uint256 nextBillingTime;
    SubscriptionStatus status;  // Active or Cancelled
    uint256 subscribedAt;
}
```

### 4. Storage Layout
Storage with upgrade safety:
```solidity
mapping(uint256 => Plan) internal _plans;
mapping(uint256 => Subscription) internal _subscriptions;
mapping(address => uint256[]) internal _userSubscriptions;
uint256 internal _planCount;
uint256 internal _subscriptionCount;
address internal _usdc;
address private _owner;
uint256[44] private __gap;  // Reserved for future upgrades
```

## Upgrade Pattern

SubBase uses UUPS (Universal Upgradeable Proxy Standard):

1. **Proxy** - Deployed once, never changes
   - Holds all state/storage
   - Delegates calls to implementation

2. **Implementation** - Can be upgraded
   - Contains all logic
   - Upgraded via `upgradeToAndCall()`

**Storage safety:** The `__gap` array reserves 44 storage slots for future versions, preventing storage collisions during upgrades.

## Deployment Addresses

### Base Sepolia (Testnet)
- **Proxy:** `0x8B182755Ae296e8f222Ac4E677B7Cc63dFDe7BA0`
- **Implementation:** `0x3c23B4A023D2A8c142d587D476BB77E4c91E15ab`

### Base Mainnet
- **Proxy:** `0xfa34E4c68c77D54dD8B694c8395953465129E3c9`
- **Implementation:** `0x005DF73314a58773588a7ADbBcE18c6d87ca724E`

## Workflow

1. **Creator creates a plan:**
   ```solidity
   createPlan(10e6, 30 days, "Premium Membership")
   ```

2. **User subscribes:**
   ```solidity
   // Approve USDC first
   usdc.approve(proxyAddress, amount)

   // Subscribe (immediate payment)
   subscribe(planId)
   ```

3. **User cancels:**
   ```solidity
   cancel(subscriptionId)
   ```

## Events

All state changes emit events for indexing:
- `PlanCreated(planId, creator, price, billingPeriod, metadata)`
- `Subscribed(subscriptionId, planId, subscriber, nextBillingTime)`
- `SubscriptionCancelled(subscriptionId, subscriber)`

## Security Features

- **ReentrancyGuard** - Prevents reentrancy attacks
- **Owner-only upgrades** - Only owner can upgrade implementation
- **Custom errors** - Gas-efficient error handling
- **USDC validation** - Address validation on initialization
