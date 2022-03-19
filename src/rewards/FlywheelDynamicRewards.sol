// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "./BaseFlywheelRewards.sol";

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on how many reward tokens appeared in the strategy itself since last accrual.
 All rewards are transferred atomically, so there is no need to use the last reward timestamp.
*/ 
contract FlywheelDynamicRewards is BaseFlywheelRewards {
    using SafeTransferLib for ERC20;

    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param strategy the strategy to accrue rewards for
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 strategy, uint32) external override onlyFlywheel returns (uint256 amount) {
        amount = rewardToken.balanceOf(address(strategy));
        if (amount > 0) rewardToken.safeTransferFrom(address(strategy), address(this), amount);
    }
}
