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

    /// @notice the end of the current cycle
    uint32 public rewardsCycleEnd;

    /// @notice the delayed start of the current cycle
    uint32 public lastSync;

    /// @notice the total amount of rewards to be distributed in a given cycle
    uint256 public lastRewardTotal;

    /// @notice the amount of rewards transferred in a given cycle
    uint256 public lastRewardTransferred;

    constructor(ERC20 _rewardToken, address _flywheel, uint32 _rewardsCycleLength) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
        rewardsCycleLength = _rewardsCycleLength;
        // seed initial rewardsCycleEnd
        rewardsCycleEnd = uint32(block.timestamp) / rewardsCycleLength * rewardsCycleLength;
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 market, uint32) external override returns (uint256 amount) {
        require(msg.sender == flywheel, "!flywheel");
        uint32 timestamp = block.timestamp.safeCastTo32();

        uint balance = rewardToken.balanceOf(address(market));
        // if cycle has ended, transfer all available and reset cycle
        if (timestamp >= rewardsCycleEnd) {
            uint256 lastRewardRemaining = lastRewardTotal - lastRewardTransferred;
            uint256 nextRewards = balance - lastRewardRemaining;

            // safeCast check.
            require(nextRewards <= type(uint160).max);
            
            lastSync = timestamp;
            rewardsCycleEnd = (timestamp + rewardsCycleLength) / rewardsCycleLength * rewardsCycleLength;
            rewardToken.transferFrom(address(market), flywheel, amount = lastRewardRemaining);
            lastRewardTotal = nextRewards;
            lastRewardTransferred = 0;
        }
        // increase distribution linearly from lastSync until cycle end
        else {
            uint256 lastRewardTransferred_ = lastRewardTransferred;
            uint256 unlockedRewards = lastRewardTotal * (timestamp - lastSync) / (rewardsCycleEnd - lastSync);
            lastRewardTransferred += (unlockedRewards - lastRewardTransferred_);
            rewardToken.transferFrom(address(market), flywheel, amount = (unlockedRewards - lastRewardTransferred));
        }
    }
}
