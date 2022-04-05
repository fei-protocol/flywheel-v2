## `FlywheelCore`






### `constructor(contract ERC20 _rewardToken, contract IFlywheelRewards _flywheelRewards, contract IFlywheelBooster _flywheelBooster, address _owner, contract Authority _authority)` (public)





### `accrue(contract ERC20 strategy, address user) → uint256` (public)

accrue rewards for a single user on a strategy
      @param strategy the strategy to accrue a user's rewards on
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)



### `accrue(contract ERC20 strategy, address user, address secondUser) → uint256, uint256` (public)

accrue rewards for a two users on a strategy
      @param strategy the strategy to accrue a user's rewards on
      @param user the first user to be accrued
      @param user the second user to be accrued
      @return the cumulative amount of rewards accrued to the first user (including prior)
      @return the cumulative amount of rewards accrued to the second user (including prior)



### `claimRewards(address user)` (external)

claim rewards for a given user
      @param user the user claiming rewards
      @dev this function is public, and all rewards transfer to the user



### `addStrategyForRewards(contract ERC20 strategy)` (external)

initialize a new strategy



### `_addStrategyForRewards(contract ERC20 strategy)` (internal)





### `getAllStrategies() → contract ERC20[]` (external)





### `setFlywheelRewards(contract IFlywheelRewards newFlywheelRewards)` (external)

swap out the flywheel rewards contract



### `setBooster(contract IFlywheelBooster newBooster)` (external)

swap out the flywheel booster contract




### `AccrueRewards(contract ERC20 strategy, address user, uint256 rewardsDelta, uint256 rewardsIndex)`

Emitted when a user's rewards accrue to a given strategy.
      @param strategy the updated rewards strategy
      @param user the user of the rewards
      @param rewardsDelta how many new rewards accrued to the user
      @param rewardsIndex the market index for rewards per token accrued



### `ClaimRewards(address user, uint256 amount)`

Emitted when a user claims accrued rewards.
      @param user the user of the rewards
      @param amount the amount of rewards claimed



### `AddStrategy(address newStrategy)`

Emitted when a new strategy is added to flywheel by the admin
      @param newStrategy the new added strategy



### `FlywheelRewardsUpdate(address newFlywheelRewards)`

Emitted when the rewards module changes
      @param newFlywheelRewards the new rewards module



### `FlywheelBoosterUpdate(address newBooster)`

Emitted when the booster module changes
      @param newBooster the new booster module




### `RewardsState`


uint224 index


uint32 lastUpdatedTimestamp



