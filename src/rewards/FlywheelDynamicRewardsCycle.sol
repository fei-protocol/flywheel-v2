// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";
import "solmate/utils/SafeCastLib.sol";

/** 
 @title Flywheel Dynamic Reward Stream Cyclic
 @notice Determines rewards based on reward cycle
*/ 
contract FlywheelDynamicRewardsCycle is IFlywheelRewards {
    using SafeTransferLib for ERC20;
    using SafeCastLib for *;

    /// @notice the reward token paid
    ERC20 public immutable rewardToken;

    /// @notice the flywheel core contract
    address public immutable flywheel;

    /// @notice the length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    /// @notice the end of the rewards cycle for a market
    mapping(ERC20 => uint32) public rewardsCycleEnd;

    /// @notice the delayed start of the current cycle for a market
    mapping(ERC20 => uint32) public lastSync;

    /// @notice the total amount of rewards to be distributed in a given cycle for a market
    mapping(ERC20 => uint256) public lastRewardTotal;

    /// @notice tracks the amount of rewards accrued in a given cycle
    mapping(ERC20 => uint256) public totalRewardsAccrued;

    constructor(ERC20 _rewardToken, address _flywheel, uint32 _rewardsCycleLength) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
        rewardsCycleLength = _rewardsCycleLength;
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 market, uint32 lastUpdatedTimestamp) external override returns (uint256 amount) {
        require(msg.sender == flywheel, "!flywheel");
        // seed initial rewardsCycleEnd
        if(rewardsCycleEnd[market] == 0) rewardsCycleEnd[market] = lastUpdatedTimestamp / rewardsCycleLength * rewardsCycleLength;

        // if cycle has ended, reset cycle and transfer all available 
        if (lastUpdatedTimestamp >= rewardsCycleEnd[market]) {
            // accrue remaining rewards (skip init cycle)
            if (lastRewardTotal[market] != 0) amount = lastRewardTotal[market] - totalRewardsAccrued[market];
            // reset for next cycle
            lastSync[market] = lastUpdatedTimestamp;
            lastRewardTotal[market] = rewardToken.balanceOf(address(market));
            rewardsCycleEnd[market] = (lastUpdatedTimestamp + rewardsCycleLength) / rewardsCycleLength * rewardsCycleLength;
            
            if(lastRewardTotal[market] > 0) rewardToken.transferFrom(address(market), flywheel, lastRewardTotal[market]);
            totalRewardsAccrued[market] = 0;
        }
        // increase distribution linearly from lastSync until cycle end
        else {
            uint256 unlockedRewards = lastRewardTotal[market] * (lastUpdatedTimestamp - lastSync[market]) / (rewardsCycleEnd[market] - lastSync[market]);
            amount = unlockedRewards - totalRewardsAccrued[market];
            totalRewardsAccrued[market] = unlockedRewards;
        }
    }
}
