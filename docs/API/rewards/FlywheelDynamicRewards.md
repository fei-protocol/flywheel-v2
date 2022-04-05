## `FlywheelDynamicRewards`






### `constructor(contract FlywheelCore _flywheel, uint32 _rewardsCycleLength)` (internal)





### `getAccruedRewards(contract ERC20 strategy, uint32 lastUpdatedTimestamp) → uint256 amount` (external)

calculate and transfer accrued rewards to flywheel core
     @param strategy the strategy to accrue rewards for
     @return amount the amount of tokens accrued and transferred



### `getNextCycleRewards(contract ERC20 strategy) → uint192` (internal)






### `NewRewardsCycle(uint32 start, uint32 end, uint192 reward)`






### `RewardsCycle`


uint32 start


uint32 end


uint192 reward



