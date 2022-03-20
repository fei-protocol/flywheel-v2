# Flywheel v2
Flywheel is a suite of open source token incentives and governance infrastructure using modern and modular solidity patterns to easily interface with other platforms.

It is built by the [Tribe DAO](http://tribedao.xyz/) using [Foundry](https://github.com/gakonst/foundry) and [Solmate](https://github.com/Rari-Capital/solmate).

Flywheel is completely on-chain and composable, for maximum compatibility with smart contract systems.

**Coming Soon**
- xERC4626 - single sided staking
- ERC20Gauges/FlywheelGaugeRewards - allow token holders to direct rewards
- ERC20MultiVotes - GovernorBravo voting with multi-delegation capabilities


## Overview

Flywheel has two major components, the core incentives engine (including a suite of rewards modules and boosters) and ERC20 token utilities (xERC4626, ERC20MultiVotes, ERC20Gauges).

Production examples of the incentives engine:
* [fuse-flywheel](https://github.com/fei-protocol/fuse-flywheel) used to reward depositors to Fuse lending markets.

### FlywheelCore Incentives Engine
The incentives engine is used to reward *users* for holding tokens in *strategies*. This can be as simple as vanilla liquidity mining or involve complex vote-escrow and boosting mechanics. Some common strategies include:
* Lending (or borrowing) on [Fuse](https://app.rari.capital/fuse) or other platforms.
* Depositing to an [ERC-4626 Vault](https://eips.ethereum.org/EIPS/eip-4626).

The core incentives engine supports a single reward token, and multiple reward tokens can easily be supported by adding multiple flywheels.

The rewards accrue to each strategy via a *rewards module.* By default, the rewards are distributed pro rata to users holding the strategy over time, but this can be transformed via a *booster module*.

### Rewards Module
The rewards module determines how many tokens go to each strategy over time. Assume a single constant or variable reward stream of tokens which needs to be divided amongst all the strategies.

The rewards can be divided according to any algorithm, some examples:
* constant reward stream per second/block
* proportional according to weights. Weights could be determined via liquid governance like [Curve gauges](https://resources.curve.fi/base-features/understanding-gauges).
* dynamically pass through rewards from an upstream plugin. For example passing through convex or balancer rewards to stakers. [Convex Fuse Pool example](https://app.rari.capital/fuse/pool/156).

### Boosting Module

Normally, rewards for users are calulated by dividing the user's `balanceOf` on the strategy divided by the `totalSupply` of the strategy.

However, some strategies require additional logic to boost or otherwise transform the user's balance. This is where the boosting module can do just that. If added to the incentives engine, it calculates a users rewards by dividing their boosted balance by the bosoted total supply.

### ERC20 Token Utilities

**Coming Soon**

## Adding Flywheel to Your Smart Contracts

To add flywheel to a forge compatible repository, simply run:

`forge install fei-protocol/flywheel-v2`

Alternatively, fork the flywheel-v2 repository to build directly using the repo.

### Flywheel Core
The FlywheelCore contract maintains all reward amounts for all user,strategy pairs. In order to have fully accurate accounting, the flywheel core needs to be updated every time the composition of the strategy changes. When the strategy is an ERC-20 or ERC-4626, this means that on mint/burn/transfer the `accrue` function needs to be called atomically for all affected users.

Example: on Fuse the `flywheelPre*` [hooks](https://github.com/Rari-Capital/compound-protocol/blob/fuse-final/contracts/Comptroller.sol#L738).

### FlywheelRewards Modules

The flywheel rewards needs to approve `rewardToken` to the FlywheelCore contract so that when users claim their rewards can be transferred from the rewards module to the user. The flywheelRewards must then eventually hold custody over all claimable tokens.

Every time flywheelCore calls getAccruedRewards(), the returned amount needs to be added to (or already held by) the flywheel rewards module.