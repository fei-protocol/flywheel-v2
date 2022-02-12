# Flywheel v2
Flywheel is the mechanism by which teams can add token incentives to Fuse positions.

Flywheel v1 has some drawbacks:
1. Opinionated implementation (tokens per block)
2. Compound Architecture (old solidity version and difficult repo)
3. No customization

Flywheel v2 should be a general architecture for token incentives which is compatible with Fuse v1, Fuse v2, and ERC-4626 broadly

Critically, it should include customization modules such as a liquid emissions control module.

## General Incentives Architecture 
![](https://i.imgur.com/k29SnsF.png)

Incentives systems can be broken down into the following components

## Indexes and Claiming
The "index" *I* tells how many rewards have accrued per staked unit since the contract start. This is stored on a global and per user level.

### Index initialization
Start the reward stream at some unit, usually 1 * some fixed point factor.

For a user, the index should match the current global index when they enter the strategy. This is accomplished by always accruing and syncing before mint or redeem actions. Likewise its applied across both users before a transfer.

If a user was in the market before, they should initialize to the same index the global unit started at, so they accrue all rewards proportionately.

### Accruing
As tokens are claimed they are accrued against the index so there is no double spending.

A user receives `balance(user) / totalSupply() * accruedRewards()` tokens.

### Claim
The "claim" action locks in rewards and transfers them to the owner.

---
Initialization, Accruing, and Claiming together form the "core" of an incentives architecture. In Flywheel v2 they will be the immutable center, with  other features plugging in.

## Rewards Module
There are several ways to carve up the weights on a given reward stream. Rewards can be given in absolute terms according to a fixed governance process (a la Compound TRIBE per block) or relative terms (a la Sushiswap MasterChef allocation points).

Some of the most effective structures give some or all of the emissions control to the token holders themselves through a liquid "Rewards delegation" procedure.

Flywheel v2 will support both of these use cases, and have the flexibility to accommodate many more through the configurable weights module.

The initial rewards calculation module "FlywheelDynamicRewards" will simply passthrough tokens that accrue directly to the strategy back to the depositors in that strategy.

## Balance Boosting
Balance boosting is a way to virtualize a user's deposit weight in the strategy. This can be used for example to incentivize borrowing or apply vote-escrowed boosting.

The booster module is assumed to have correct accounting and state management.
