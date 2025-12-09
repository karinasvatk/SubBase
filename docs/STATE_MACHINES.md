# SubBase State Machines Specification

This document provides a formal specification of the state machines governing Plans and Subscriptions in the SubBase protocol.

## Table of Contents
- [Plan Lifecycle](#plan-lifecycle)
- [Subscription Lifecycle](#subscription-lifecycle)
- [State Transitions](#state-transitions)
- [Invariants and Guarantees](#invariants-and-guarantees)
- [Events](#events)

## Plan Lifecycle

### Plan States

Plans in SubBase have a simple lifecycle with only two implicit states:

1. **Active** (`active = true`)
2. **Inactive** (`active = false`)

### Plan State Machine

```
┌─────────────┐
│   Created   │
│ (active=true)│
└──────────────┘
       │
       │ (No state transitions in current version)
       │
       ▼
  (Terminal State)
```

### Plan Creation

**Function**: `createPlan(uint256 price, uint256 billingPeriod, string metadata)`

**Preconditions**:
- `price > 0` (must be non-zero)
- `billingPeriod > 0` (must be non-zero)

**Postconditions**:
- New plan created with unique `planId`
- `plan.active = true`
- `plan.creator = msg.sender`
- `plan.createdAt = block.timestamp`
- `PlanCreated` event emitted

**Guarantees**:
- Plan ID is monotonically increasing
- Plan parameters are immutable after creation
- No mechanism exists to update or deactivate plans (future feature)

## Subscription Lifecycle

### Subscription States

Subscriptions can be in one of four states:

1. **Active** - Subscription is current, no payment issues
2. **PastDue** - Payment failed, within grace period
3. **Suspended** - Max retry attempts reached, requires manual reactivation
4. **Cancelled** - User cancelled, terminal state

### Subscription State Machine

```
                    ┌─────────────┐
                    │   Active    │◄────┐
                    └─────────────┘     │
                           │            │
                           │ charge()   │ successful
                           │ fails      │ charge/retry
                           ▼            │
                    ┌─────────────┐     │
                    │  PastDue    │─────┘
                    └─────────────┘
                      │          │
          3 failures  │          │ reactivate()
          or max      │          │ (not allowed)
          retries     │          │
                      │          │ cancel()
                      ▼          ▼
            ┌─────────────┐  ┌────────────┐
            │  Suspended  │  │ Cancelled  │
            └─────────────┘  └────────────┘
                  │                │
                  │ reactivate()   │
                  │                │
                  ▼                ▼
            ┌─────────────┐  (Terminal State)
            │   Active    │
            └─────────────┘
```

## State Transitions

### 1. Subscribe (Plan → Subscription)

**Function**: `subscribe(uint256 planId)`

**Preconditions**:
- Plan must exist (`planId < _planCount`)
- Plan must be active (`plan.active == true`)
- Subscriber must have approved USDC transfer
- Subscriber must have sufficient USDC balance

**State Changes**:
- Creates new subscription with unique ID
- Status set to `Active`
- `nextBillingTime = block.timestamp + plan.billingPeriod`
- First payment processed immediately

**Events**:
- `Subscribed(subscriptionId, planId, subscriber, nextBillingTime)`

**Invariants**:
- Subscription ID is monotonically increasing
- User can subscribe to same plan multiple times (creates separate subscriptions)
- Initial payment always succeeds or transaction reverts

### 2. Active → PastDue

**Function**: `charge(uint256 subscriptionId)` (on first failure)

**Preconditions**:
- `subscription.status == Active`
- `block.timestamp >= subscription.nextBillingTime`
- Payment fails (insufficient balance or transfer rejection)

**State Changes**:
- `subscription.status = PastDue`
- `_failedAttempts[subscriptionId] = 1`
- `_lastChargeAttempt[subscriptionId] = block.timestamp`
- `_gracePeriodEnd[subscriptionId] = block.timestamp + _defaultGracePeriod`

**Events**:
- `ChargeFailed(subscriptionId, 1, reason)`
- `SubscriptionPastDue(subscriptionId, gracePeriodEnd)`

**Invariants**:
- Grace period starts immediately on first failure
- `nextBillingTime` remains unchanged (not advanced)

### 3. PastDue → Active

**Function**: `charge(uint256 subscriptionId)` or `retryCharge(uint256 subscriptionId)` (on success)

**Preconditions**:
- `subscription.status == PastDue`
- Payment succeeds

**State Changes**:
- `subscription.status = Active`
- `_failedAttempts[subscriptionId] = 0`
- `_gracePeriodEnd[subscriptionId] = 0`
- `subscription.nextBillingTime = block.timestamp + plan.billingPeriod`

**Events**:
- `ChargeSuccessful(subscriptionId, amount, nextBillingTime)`

**Invariants**:
- Failed attempts reset to 0
- Grace period cleared
- Next billing time advanced from current time (not from original due time)

### 4. PastDue → Suspended

**Function**: `charge(uint256 subscriptionId)` or `retryCharge(uint256 subscriptionId)` (on 3rd failure)

**Preconditions**:
- `subscription.status == PastDue`
- `_failedAttempts[subscriptionId] >= _maxRetryAttempts - 1`
- Payment fails

**State Changes**:
- `subscription.status = Suspended`
- `_failedAttempts[subscriptionId] = _maxRetryAttempts` (typically 3)

**Events**:
- `ChargeFailed(subscriptionId, attempts, reason)`
- `SubscriptionSuspended(subscriptionId)`

**Invariants**:
- Auto-suspension happens on reaching max retry attempts
- Grace period and failed attempts counters persist
- Cannot be charged again until reactivated

### 5. Suspended → Active

**Function**: `reactivate(uint256 subscriptionId)`

**Preconditions**:
- `subscription.status == Suspended`
- Caller must pay outstanding amount (one billing cycle payment)
- Caller must have approved USDC transfer

**State Changes**:
- `subscription.status = Active`
- `_failedAttempts[subscriptionId] = 0`
- `_lastChargeAttempt[subscriptionId] = 0`
- `_gracePeriodEnd[subscriptionId] = 0`
- `subscription.nextBillingTime = block.timestamp + plan.billingPeriod`

**Events**:
- `SubscriptionReactivated(subscriptionId)`

**Invariants**:
- Payment required before reactivation
- All failure tracking state cleared
- Next billing time set from reactivation time

### 6. Any → Cancelled

**Function**: `cancel(uint256 subscriptionId)`

**Preconditions**:
- `msg.sender == subscription.subscriber` (only subscriber can cancel)
- `subscription.status != Cancelled` (cannot cancel twice)

**State Changes**:
- `subscription.status = Cancelled`

**Events**:
- `SubscriptionCancelled(subscriptionId, subscriber)`

**Invariants**:
- Terminal state (no exit from Cancelled)
- Cannot be charged, retried, or reactivated
- Can be cancelled from any non-Cancelled state

## Charging Mechanics

### When Can a Subscription Be Charged?

A subscription is chargeable (`isChargeable()` returns true) when:

1. **Status Check**: `status == Active` OR `status == PastDue`
2. **Time Check**: `block.timestamp >= nextBillingTime`
3. **Retry Limit Check** (for PastDue): `_failedAttempts < _maxRetryAttempts`

### Idempotency Guarantees

**Single Billing Period Protection**:
- Once a charge succeeds, `nextBillingTime` advances
- Cannot charge again until `block.timestamp >= nextBillingTime`
- This prevents double-billing within the same period

**Failure**: There is NO protection against subscribing to the same plan multiple times (intentional - allows multiple subscriptions)

### Grace Period Mechanics

**Grace Period Start**:
- Set on first charge failure (Active → PastDue)
- Duration: `_defaultGracePeriod` (default: 7 days, configurable)
- Stored as: `_gracePeriodEnd[subscriptionId] = block.timestamp + _defaultGracePeriod`

**During Grace Period**:
- Subscription remains in PastDue status
- Can be retried up to `_maxRetryAttempts` times (default: 3)
- Grace period end time does not change with subsequent failures

**Grace Period End**:
- Cleared when:
  - Charge succeeds (PastDue → Active)
  - Subscription reactivated (Suspended → Active)
- Grace period expiration does NOT automatically suspend
  - Suspension happens only after max retry attempts reached

## Invariants and Guarantees

### Global Invariants

1. **ID Uniqueness**: Plan IDs and Subscription IDs are unique and monotonically increasing
2. **Plan Immutability**: Once created, plan parameters cannot be changed
3. **Payment Token**: All payments use USDC (6 decimals)
4. **First Payment**: Subscribe always requires immediate first payment

### Subscription Invariants

1. **Terminal State**: Cancelled is terminal (no transitions out)
2. **Failed Attempts**: Always in range [0, _maxRetryAttempts]
3. **Grace Period**: Only set when status == PastDue
4. **Next Billing Time**: Always set to future time after successful charge
5. **Ownership**: Only subscriber can cancel their subscription

### Charging Invariants

1. **Due Time**: Can only charge if `block.timestamp >= nextBillingTime`
2. **Status**: Can only charge Active or PastDue subscriptions
3. **Idempotency**: Cannot charge same subscription twice in same billing period
4. **Advancement**: Successful charge advances nextBillingTime by exactly one billingPeriod from current time

## Events

All state transitions emit events for off-chain tracking:

### Plan Events
- `PlanCreated(uint256 indexed planId, address indexed creator, uint256 price, uint256 billingPeriod, string metadata)`

### Subscription Events
- `Subscribed(uint256 indexed subscriptionId, uint256 indexed planId, address indexed subscriber, uint256 nextBillingTime)`
- `SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber)`
- `SubscriptionPastDue(uint256 indexed subscriptionId, uint256 gracePeriodEnd)`
- `SubscriptionSuspended(uint256 indexed subscriptionId)`
- `SubscriptionReactivated(uint256 indexed subscriptionId)`

### Charging Events
- `ChargeSuccessful(uint256 indexed subscriptionId, uint256 amount, uint256 nextBillingTime)`
- `ChargeFailed(uint256 indexed subscriptionId, uint256 attempt, string reason)`

### Configuration Events
- `GracePeriodUpdated(uint256 oldPeriod, uint256 newPeriod)`
- `MaxRetryAttemptsUpdated(uint256 oldAttempts, uint256 newAttempts)`

## Edge Cases and Boundary Conditions

### Time Boundaries
- Charging exactly at `nextBillingTime` is allowed
- Charging 1 second before `nextBillingTime` reverts with `NotDueForCharge`
- No upper time limit for charging (can charge weeks/months late)

### Payment Boundaries
- Minimum price: 1 wei (0 reverts)
- Maximum price: no limit (uint256 max)
- Minimum billing period: 1 second
- Maximum billing period: no limit (can be years)

### Retry Boundaries
- Grace period: minimum 1 second, no maximum
- Max retry attempts: minimum 1, no maximum
- Failed attempts tracked per subscription, never shared

### Multiple Billing Cycles
- After successful charge, immediately eligible for next charge if time has passed
- Can skip multiple billing periods (charge advances from current time, not accumulated)

## Integration Guidelines

### For dApp Developers

1. **Subscribe**: Always ensure user has approved USDC before calling `subscribe()`
2. **Monitor**: Listen to events to track subscription status changes
3. **Grace Period**: Show users their grace period end time when PastDue
4. **Reactivation**: Guide suspended users through reactivation flow
5. **Cancellation**: Implement clear cancellation UX

### For Automation Systems

1. **Query Chargeable**: Use `getChargeableSubscriptions(limit)` to find due subscriptions
2. **Batch Processing**: Use `batchCharge()` for efficient multi-subscription charging
3. **Error Handling**: Failed charges are expected, handle gracefully
4. **Gas Optimization**: Limit batch size to avoid gas limits (recommended: 50 per tx)

### For Plan Creators

1. **Price Selection**: Consider USDC decimals (6) when setting prices
2. **Billing Period**: Choose appropriate period (daily/weekly/monthly/yearly)
3. **Metadata**: Use JSON for structured metadata (not enforced on-chain)
4. **Immutability**: Plans cannot be updated, create new plan for changes

## Security Considerations

### Attack Vectors

1. **Reentrancy**: All external calls protected (USDC transfers last)
2. **Integer Overflow**: Solidity 0.8+ has built-in overflow protection
3. **Authorization**: Only subscriber can cancel their subscription
4. **Front-running**: Subscribe/charge operations are order-independent

### Known Limitations

1. **No Pause**: No emergency pause mechanism (by design)
2. **No Refunds**: No built-in refund mechanism
3. **No Proration**: No partial billing period support
4. **Single Token**: Only USDC supported
5. **No Plan Updates**: Cannot modify plan after creation

## Changelog

### V1 (Initial)
- Basic plan creation
- Subscribe/cancel functionality
- Simple active/cancelled states

### V2 (Current)
- Added PastDue and Suspended states
- Grace period mechanism (7 days default)
- Retry logic (3 attempts default)
- Reactivation functionality
- Batch charging support
- Automation-ready queries
