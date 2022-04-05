## `FlywheelGaugeRewards`






### `constructor(contract FlywheelCore _flywheel, address _owner, contract Authority _authority, contract ERC20Gauges _gaugeToken, contract IRewardsStream _rewardsStream)` (public)





### `queueRewardsForCycle() → uint256 totalQueuedForCycle` (external)

Iterates over all live gauges and queues up the rewards for the cycle
        @return totalQueuedForCycle the max amount of rewards to be distributed over the cycle



### `queueRewardsForCyclePaginated(uint256 numRewards)` (external)

Iterates over all live gauges and queues up the rewards for the cycle



### `_queueRewards(address[] gauges, uint32 currentCycle, uint32 lastCycle, uint256 totalQueuedForCycle)` (internal)





### `getAccruedRewards(contract ERC20 gauge, uint32 lastUpdatedTimestamp) → uint256 accruedRewards` (external)

calculate and transfer accrued rewards to flywheel core
     @param gauge the gauge to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for gauge
     @return accruedRewards the amount of reward tokens accrued.



### `setRewardsStream(contract IRewardsStream newRewardsStream)` (external)

set the rewards stream contract




### `CycleStart(uint32 cycleStart, uint256 rewardAmount)`

emitted when a cycle has completely queued and started



### `QueueRewards(address gauge, uint32 cycleStart, uint256 rewardAmount)`

emitted when a single gauge is queued. May be emitted before the cycle starts if the queue is done via pagination.




### `QueuedRewards`


uint112 priorCycleRewards


uint112 cycleRewards


uint32 storedCycle



