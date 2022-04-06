# Flywheel Token Utilities

## Overview

Flywheel token utilities are meant to create standardized, fully featured ERC-20 tokens which integrate easily with flywheel incentives engine and other open source tooling.

The two token utilities are:

- ERC20MultiVotes: on-chain governance with multiple partial delegation support
- ERC20Gauges: continuous voting on a single parameter such as rewards or liquidity direction

Both utilities allow for allocating votes/weight to multiple destinations. Ideally, contracts which escrow tokens can pass delegation powers up to users to maintain composability and the governance powers of the tokens.

## ERC20MultiVotes

ERC20MultiVotes supports on-chain governance with historical voting weight storage and lookup, and allows multiple partial delegations from the same user.

Similar to OpenZeppelin [ERC20Votes](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes), commonly used with Governor Bravo/Tally.

### API Differences with ERC20Votes

For delegations, because there are multiple delegates and partial delegations, the interface changes slightly:

| Action                                           | ERC20MultiVotes                                          | ERC20Votes                                |
| ------------------------------------------------ | -------------------------------------------------------- | ----------------------------------------- |
| reading delegate(s)                              | `delegates(address) returns (address[])`                 | `delegates(address) returns (address)`    |
| single all-or-nothing delegation (same)          | `delegate(address)`                                      | `delegate(address)`                       |
| read current votes (same)                        | `getVotes(address) returns (uint256)`                    | `getVotes(address) returns (uint256)`     |
| read past votes (same)                           | `getPastVotes(address) returns (uint256)`                | `getPastVotes(address) returns (uint256)` |
| partial delegation                               | `delegate(address, uint256)`                             | N/A                                       |
| partial undelegation                             | `undelegate(address, uint256)`                           | N/A                                       |
| reading amount delegated BY a user               | `userDelegatedVotes(address) returns (uint256)`          | N/A                                       |
| reading amount delegated TO a delegate BY a user | `delegatesVotesCount(address,address) returns (uint256)` | N/A                                       |
| amount of delegates by a user                    | `delegateCount(address) returns (uint256)`               | N/A                                       |

## ERC20Gauges

An ERC20 token which allows for continuous voting on a single parameter such as rewards or liquidity direction. This is inspired by the [Curve gauges](https://resources.curve.fi/base-features/understanding-gauges) mechanism, but with the goal of not needing to "stake" tokens and have the weights held natively in the ERC20.

To save gas for users, ERC20Gauges uses a concept of cycles during which votes can be changed and not locked in.

Once the cycle ends, all votes are snapshotted and can be used to govern the desired parameter. It is critical for integrators to consume the stored voting weights to get manipulation resistant values.

There is an "increment freeze" window which is the time before a cycle ends when weights can only decrease, not increase. This prevents users from flash acquiring tokens right before the new cycle starts, and creates a minimum exposure window to influence the gauges.
