// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

/** 
 @title Flywheel Dynamic Reward Stream Cyclic
 @notice Determines rewards based on reward cycle
*/ 
contract FlywheelDynamicRewardsCycle is IFlywheelRewards {
    using SafeTransferLib for ERC20;

    /// @notice the reward token paid
    ERC20 public immutable rewardToken;

    /// @notice the flywheel core contract
    address public immutable flywheel;

    /// @notice the length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    struct RewardsCycle {
        uint32 lastSync;
        uint32 rewardsCycleEnd;
        uint192 lastReward;
    }
    
    mapping(ERC20 => RewardsCycle) public rewardsCycle;

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
        RewardsCycle memory cycle = rewardsCycle[market];
        
        // if cycle has ended, reset cycle and transfer all available 
        if (block.timestamp >= cycle.rewardsCycleEnd) {
            amount = cycle.lastReward;
            // reset for next cycle
            rewardsCycle[market] = RewardsCycle ({
                lastSync: uint32(block.timestamp),
                rewardsCycleEnd: (uint32(block.timestamp) + rewardsCycleLength) / rewardsCycleLength * rewardsCycleLength,
                lastReward: uint192(rewardToken.balanceOf(address(market)))
            });
            if(rewardsCycle[market].lastReward > 0) rewardToken.transferFrom(address(market), address(this), rewardsCycle[market].lastReward);
        }
        // increase distribution linearly from lastSync until cycle end
        else {
            amount = cycle.lastReward * (lastUpdatedTimestamp - cycle.lastSync) / (cycle.rewardsCycleEnd - cycle.lastSync);
        }
    }
}
