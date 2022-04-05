## `FlywheelStaticRewards`






### `constructor(contract FlywheelCore _flywheel, address _owner, contract Authority _authority)` (public)





### `setRewardsInfo(contract ERC20 strategy, struct FlywheelStaticRewards.RewardsInfo rewards)` (external)

set rewards per second and rewards end time for Fei Rewards
     @param strategy the strategy to accrue rewards for
     @param rewards the rewards info for the strategy



### `getAccruedRewards(contract ERC20 strategy, uint32 lastUpdatedTimestamp) → uint256 amount` (external)

calculate and transfer accrued rewards to flywheel core
     @param strategy the strategy to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for strategy
     @return amount the amount of tokens accrued and transferred




### `RewardsInfoUpdate(contract ERC20 strategy, uint224 rewardsPerSecond, uint32 rewardsEndTimestamp)`






### `RewardsInfo`


uint224 rewardsPerSecond


uint32 rewardsEndTimestamp



