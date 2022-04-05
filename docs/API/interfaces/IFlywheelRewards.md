## `IFlywheelRewards`






### `getAccruedRewards(contract ERC20 strategy, uint32 lastUpdatedTimestamp) → uint256 rewards` (external)

calculate the rewards amount accrued to a strategy since the last update.
     @param strategy the strategy to accrue rewards for.
     @param lastUpdatedTimestamp the last time rewards were accrued for the strategy.
     @return rewards the amount of rewards accrued to the market



### `flywheel() → contract FlywheelCore` (external)

return the flywheel core address



### `rewardToken() → contract ERC20` (external)

return the reward token associated with flywheel core.






