# Automation Operations — SubBase

## Overview

SubBase uses Chainlink Automation to automatically charge subscriptions on schedule. This document covers configuration, monitoring, and troubleshooting for production operations.

## Chainlink Automation Configuration

### Upkeep Settings

```yaml
Gas Limit: 2,000,000
Check Interval: Every 1 hour (3600 seconds)
Min Balance: 10 LINK (alert threshold)
Max Batch Size: 50 subscriptions per execution
```

### Setup Steps

1. **Deploy Contracts:**
   ```bash
   forge script script/DeploySubBase.s.sol --broadcast --verify
   ```

2. **Register Chainlink Upkeep:**
   - Go to https://automation.chain.link
   - Click "Register New Upkeep"
   - Select "Custom logic"
   - Contract address: SubBase proxy address
   - Gas limit: 2,000,000
   - Fund with LINK

3. **Verify Configuration:**
   ```solidity
   // Check grace period (should be 7 days = 604800 seconds)
   uint256 gracePeriod = subbase.getGracePeriod();

   // Check max retry attempts (should be 3)
   uint256 maxRetries = subbase.getMaxRetryAttempts();
   ```

## How It Works

### Check Cycle

Every hour, Chainlink calls `checkUpkeep()`:

1. **Scan Subscriptions:** Loop through all subscriptions
2. **Filter Due:** Find subscriptions where `block.timestamp >= nextBillingTime`
3. **Filter Eligible:** Only Active or PastDue subscriptions
4. **Batch:** Up to 50 subscriptions per batch
5. **Return:** If any found, returns `upkeepNeeded = true` with subscription IDs

### Perform Cycle

If upkeep needed, Chainlink calls `performUpkeep()`:

1. **Decode Data:** Extract subscription IDs
2. **Batch Process:** Loop through IDs (max 50)
3. **Charge Each:** Call `charge()` for each subscription
4. **Graceful Failures:** Individual failures don't stop batch
5. **Emit Events:** `ChargeSuccessful` or `ChargeFailed` for each

### Charge Logic

For each subscription:

```
1. Check if due (block.timestamp >= nextBillingTime)
2. Check user token allowance
3. Attempt transferFrom(user → creator)
4. If success:
   - Update nextBillingTime by adding billingPeriod
   - Reset failedAttempts to 0
   - Clear gracePeriodEnd
   - Status → Active
   - Emit ChargeSuccessful
5. If failure:
   - Increment failedAttempts
   - Set gracePeriodEnd (7 days from now)
   - If attempts < 3: Status → PastDue
   - If attempts >= 3: Status → Suspended
   - Emit ChargeFailed or SubscriptionSuspended
```

## Failure Handling

### Individual Charge Failures

Handled gracefully:
- **Insufficient allowance** → PastDue, retry next hour
- **Insufficient balance** → PastDue, retry next hour
- **3 failures** → Suspended (requires manual reactivation)

### Batch Failures

Partial failures are normal:
- **Success rate > 80%:** Normal operation
- **Success rate 50-80%:** Monitor for patterns
- **Success rate < 50%:** Investigate (gas issues, contract bug)

### Grace Period

```
Attempt 1 (Hour 0): Charge fails → PastDue, grace period ends in 7 days
Attempt 2 (Hour 1): Charge fails → PastDue, still in grace period
Attempt 3 (Hour 2): Charge fails → Suspended (max retries reached)
```

Total grace period: 7 days
Max retry attempts: 3

## Monitoring

### Key Metrics

Track these metrics off-chain:

1. **Charge Success Rate:**
   - Listen to `ChargeSuccessful` events
   - Calculate success rate per batch
   - Alert if < 80% for consecutive batches

2. **Suspension Rate:**
   - Listen to `SubscriptionSuspended` events
   - Track suspensions per day
   - Alert if > 5% of active subscriptions suspended in 24h

3. **Gas Usage:**
   - Monitor Chainlink upkeep gas consumption
   - Alert if consistently > 1.8M gas (90% of limit)

4. **LINK Balance:**
   - Monitor upkeep LINK balance
   - Alert if < 10 LINK

### Event Monitoring

```typescript
// Watch ChargeSuccessful events
contract.on("ChargeSuccessful", (subId, amount, nextBillingTime) => {
    console.log(`✅ Subscription ${subId} charged: ${amount} USDC`);
    console.log(`Next billing: ${new Date(nextBillingTime * 1000)}`);
});

// Watch ChargeFailed events
contract.on("ChargeFailed", (subId, attempt, reason) => {
    console.log(`❌ Subscription ${subId} failed (attempt ${attempt}): ${reason}`);

    if (attempt >= 3) {
        console.log(`⚠️ Subscription ${subId} will be suspended`);
        // Notify user via email/webhook
    }
});

// Watch SubscriptionSuspended events
contract.on("SubscriptionSuspended", (subId) => {
    console.log(`🔒 Subscription ${subId} suspended`);
    // Notify user via email/webhook
});

// Watch SubscriptionPastDue events
contract.on("SubscriptionPastDue", (subId, gracePeriodEnd) => {
    console.log(`⏰ Subscription ${subId} is past due`);
    console.log(`Grace period ends: ${new Date(gracePeriodEnd * 1000)}`);
    // Send reminder to user
});
```

### Dashboard Queries

```typescript
// Get all subscriptions due for charging
const chargeable = await subbase.getChargeableSubscriptions(100);
console.log(`${chargeable.length} subscriptions due for charging`);

// Get failed attempts for a subscription
const attempts = await subbase.getFailedAttempts(subscriptionId);
console.log(`Failed attempts: ${attempts}/3`);

// Get grace period end time
const gracePeriodEnd = await subbase.getGracePeriodEnd(subscriptionId);
if (gracePeriodEnd > 0) {
    console.log(`Grace period ends: ${new Date(gracePeriodEnd * 1000)}`);
}

// Check if subscription is chargeable
const isChargeable = await subbase.isChargeable(subscriptionId);
console.log(`Chargeable: ${isChargeable}`);
```

## Emergency Procedures

### Pause Automation

If issues detected:

```bash
# Option 1: Pause Chainlink upkeep via dashboard
# Go to automation.chain.link, find your upkeep, click "Pause"

# Option 2: Cancel upkeep registration entirely
# Go to automation.chain.link, find your upkeep, click "Cancel"
```

**Note:** SubBase contract itself has no pause mechanism. Pausing is done at the Chainlink Automation level.

### Manual Charging

If automation down, charge manually:

```typescript
// Charge single subscription
const tx = await subbase.charge(subscriptionId);
await tx.wait();

// Batch charge multiple subscriptions
const subscriptionIds = [1, 2, 3, 4, 5];
const tx = await subbase.batchCharge(subscriptionIds);
const receipt = await tx.wait();

// Parse results from events
const chargeEvents = receipt.logs.filter(
    log => log.topics[0] === subbase.interface.getEventTopic("ChargeSuccessful")
);
console.log(`Charged ${chargeEvents.length} subscriptions`);
```

### Batch Manual Charging Script

```typescript
import { ethers } from 'ethers';

async function manualBatchCharge() {
    const subbase = new ethers.Contract(address, abi, signer);

    // Get all chargeable subscriptions
    const chargeable = await subbase.getChargeableSubscriptions(50);

    if (chargeable.length === 0) {
        console.log("No subscriptions due for charging");
        return;
    }

    console.log(`Charging ${chargeable.length} subscriptions...`);

    // Charge in batch
    const tx = await subbase.batchCharge(chargeable);
    const receipt = await tx.wait();

    // Count successes and failures
    let successCount = 0;
    let failCount = 0;

    for (const log of receipt.logs) {
        if (log.topics[0] === subbase.interface.getEventTopic("ChargeSuccessful")) {
            successCount++;
        } else if (log.topics[0] === subbase.interface.getEventTopic("ChargeFailed")) {
            failCount++;
        }
    }

    console.log(`✅ Success: ${successCount}`);
    console.log(`❌ Failed: ${failCount}`);
}
```

## Gas Optimization

### Batch Size Tuning

Current: 50 subscriptions per batch (~1.5M gas average)

If hitting gas limit:
1. Reduce batch size in code (requires contract upgrade)
2. Monitor gas usage with reduced batch
3. Adjust Chainlink gas limit if needed

### Gas Costs (Estimated)

```
Empty batch: ~100k gas
Per subscription:
  - Success: ~50k gas (transferFrom + state updates)
  - Failure (insufficient balance): ~30k gas (failed transfer + state updates)
  - Cancelled/Suspended check: ~5k gas

Example calculation:
50 subscriptions, 40 success, 10 failure:
= 100k + (40 × 50k) + (10 × 30k)
= 100k + 2000k + 300k
= 2.4M gas → Exceeds 2M limit!

Solution: Reduce BATCH_SIZE constant to 35-40 subscriptions
```

### Gas Limit Recommendations

- **Conservative:** 2,000,000 gas (current setting)
- **Aggressive:** 3,000,000 gas (if network supports)
- **Batch size:** Tune based on average gas usage

## Troubleshooting

### Issue: Upkeep not triggering

**Symptoms:** `checkUpkeep` returns false even with due subscriptions

**Diagnosis:**
```typescript
// Check if subscriptions are actually due
const subscription = await subbase.getSubscription(subId);
console.log("Status:", subscription.status);
console.log("Next billing:", new Date(subscription.nextBillingTime * 1000));
console.log("Current time:", new Date());

// Check if chargeable
const isChargeable = await subbase.isChargeable(subId);
console.log("Is chargeable:", isChargeable);

// Check failed attempts
const attempts = await subbase.getFailedAttempts(subId);
console.log("Failed attempts:", attempts);
```

**Possible Causes:**
1. No subscriptions actually due
2. All due subscriptions are Cancelled/Suspended
3. Subscriptions exceeded max retry attempts

**Fix:**
- Wait for subscriptions to become due
- Check subscription statuses
- Reactivate suspended subscriptions if needed

---

### Issue: High failure rate

**Symptoms:** >20% of charges failing in batch

**Diagnosis:**
```typescript
// Listen to ChargeFailed events
contract.on("ChargeFailed", (subId, attempt, reason) => {
    console.log(`Subscription ${subId} failed: ${reason}`);
});

// Check user balances and allowances
const subscription = await subbase.getSubscription(subId);
const plan = await subbase.getPlan(subscription.planId);
const balance = await usdc.balanceOf(subscription.subscriber);
const allowance = await usdc.allowance(subscription.subscriber, subbaseAddress);

console.log(`Required: ${ethers.formatUnits(plan.price, 6)} USDC`);
console.log(`Balance: ${ethers.formatUnits(balance, 6)} USDC`);
console.log(`Allowance: ${ethers.formatUnits(allowance, 6)} USDC`);
```

**Possible Causes:**
1. Users not maintaining token allowance
2. Users don't have sufficient balance
3. Token contract issues

**Fix:**
- Implement off-chain allowance monitoring
- Send low-balance warnings to users
- Provide UX for easy allowance renewal
- Add email/webhook notifications for upcoming charges

---

### Issue: Out of gas

**Symptoms:** Automation execution reverts with "out of gas"

**Diagnosis:**
```typescript
// Check recent Chainlink upkeep executions
// View on automation.chain.link dashboard

// Estimate gas for current batch
const chargeable = await subbase.getChargeableSubscriptions(50);
const gasEstimate = await subbase.estimateGas.performUpkeep(
    ethers.AbiCoder.defaultAbiCoder().encode(["uint256[]"], [chargeable])
);
console.log(`Estimated gas: ${gasEstimate}`);
```

**Possible Causes:**
1. Batch size too large
2. Unexpected gas-heavy operation
3. Network congestion

**Fix:**
- Requires contract upgrade to reduce BATCH_SIZE constant
- Or increase Chainlink gas limit to 3,000,000

---

### Issue: Subscriptions stuck in PastDue

**Symptoms:** Subscriptions remain PastDue despite users having balance

**Diagnosis:**
```typescript
const subscription = await subbase.getSubscription(subId);
const plan = await subbase.getPlan(subscription.planId);
const balance = await usdc.balanceOf(subscription.subscriber);
const allowance = await usdc.allowance(subscription.subscriber, subbaseAddress);

console.log("Status:", subscription.status);
console.log("Next billing:", new Date(subscription.nextBillingTime * 1000));
console.log("Failed attempts:", await subbase.getFailedAttempts(subId));
console.log("Balance:", ethers.formatUnits(balance, 6));
console.log("Allowance:", ethers.formatUnits(allowance, 6));
console.log("Required:", ethers.formatUnits(plan.price, 6));
```

**Possible Causes:**
1. Insufficient allowance (common!)
2. Charge not attempted yet (wait for next upkeep)
3. Exceeded max retry attempts

**Fix:**
- User needs to approve more USDC
- Manually retry charge: `await subbase.retryCharge(subId)`
- If suspended, user must call `reactivate()`

---

## Production Checklist

Before going live:

### Chainlink Automation
- [ ] Chainlink upkeep registered on automation.chain.link
- [ ] Upkeep funded with >50 LINK
- [ ] Gas limit set to 2,000,000
- [ ] Check interval set to 1 hour (3600 seconds)
- [ ] Upkeep is active (not paused)

### Contract Configuration
- [ ] Grace period set to 7 days (604800 seconds)
- [ ] Max retry attempts set to 3
- [ ] USDC token address correct for network
- [ ] Contract ownership transferred to multisig (if applicable)

### Monitoring Setup
- [ ] Event monitoring configured (ChargeSuccessful, ChargeFailed, etc.)
- [ ] Dashboard for subscription metrics
- [ ] Alert thresholds set (LINK balance < 10, success rate < 80%)
- [ ] Email/webhook notifications for suspensions
- [ ] Gas usage tracking enabled

### Documentation
- [ ] Emergency procedures documented
- [ ] Team trained on manual charging
- [ ] Runbook created for common issues
- [ ] Contact info for Chainlink support saved

### Testing
- [ ] Test charge performed successfully on testnet
- [ ] Batch charge tested with mixed results
- [ ] Failure scenarios tested (no balance, no allowance)
- [ ] Grace period and suspension flow verified
- [ ] Reactivation tested

---

## Support Resources

### Chainlink Documentation
- [Chainlink Automation Docs](https://docs.chain.link/chainlink-automation)
- [Custom Logic Automation](https://docs.chain.link/chainlink-automation/guides/compatible-contracts)
- [Automation Best Practices](https://docs.chain.link/chainlink-automation/guides/automation-architecture)

### SubBase Resources
- [SubBase GitHub](https://github.com/karinasvatk/SubBase)
- [State Machine Documentation](./STATE_MACHINES.md)
- [Smart Contract Source](../src/)

### Getting Help
- **GitHub Issues:** [Report bugs](https://github.com/karinasvatk/SubBase/issues)
- **Email:** savitskayakarrina@outlook.com
- **Chainlink Discord:** [Get automation support](https://discord.gg/chainlink)

---

## Appendix: Event Reference

### ChargeSuccessful
```solidity
event ChargeSuccessful(
    uint256 indexed subscriptionId,
    uint256 amount,
    uint256 nextBillingTime
);
```
Emitted when a charge succeeds.

### ChargeFailed
```solidity
event ChargeFailed(
    uint256 indexed subscriptionId,
    uint256 attempt,
    string reason
);
```
Emitted when a charge fails.
**Reasons:** "Transfer failed", "Insufficient balance"

### SubscriptionPastDue
```solidity
event SubscriptionPastDue(
    uint256 indexed subscriptionId,
    uint256 gracePeriodEnd
);
```
Emitted when subscription enters PastDue status on first failure.

### SubscriptionSuspended
```solidity
event SubscriptionSuspended(
    uint256 indexed subscriptionId
);
```
Emitted when subscription suspended after 3 failed attempts.

### SubscriptionReactivated
```solidity
event SubscriptionReactivated(
    uint256 indexed subscriptionId
);
```
Emitted when suspended subscription is manually reactivated.

---

**Last Updated:** 2025-12-13
**Version:** 2.0.0
**Maintainer:** karinasvatk
