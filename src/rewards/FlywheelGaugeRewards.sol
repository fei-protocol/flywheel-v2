// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

import {ERC20Gauges} from "../token/ERC20Gauges.sol";

/// @notice a contract which streams reward tokens to the FlywheelRewards module
interface IRewardsStream {

    /// @notice read and transfer reward token chunk to FlywheelRewards module
    function getRewards() external returns(uint256);
}

/** 
 @title Flywheel Gauge Reward Stream
 @notice Distributes rewards from a stream based on gauge weights

 The contract assumes an arbitrary stream of rewards `S` of rewardToken. It chunks the rewards into cycles of length `l`.

 The allocation function for each cycle A(g, S) proportions the stream to each gauge such that SUM(A(g, S)) over all gauges <= S. 
 NOTE it should be approximately S, but may be less due to truncation.

 Rewards are accumulated every time a new rewards cycle begins, and all prior rewards are cached in the previous cycle.
 When the Flywheel Core requests accrued rewards for a specific gauge:
 1. All prior rewards before this cycle are distributed
 2. Rewards for the current cycle are distributed proportionally to the remaining time in the cycle. 
    If `e` is the cycle end, `t` is the min of e and current timestamp, and `p` is the prior updated time:
    For `A` accrued rewards over the cycle, distribute `min(A * (t-p)/(e-p), A)`.
*/ 
contract FlywheelGaugeRewards is Auth, IFlywheelRewards {
    using SafeTransferLib for ERC20;

    // TODO add events

    /// @notice the flywheel core contract
    address public immutable flywheel;

    /// @notice the reward token paid
    ERC20 public immutable rewardToken;

    /// @notice the end of the current cycle
    uint32 public rewardsCycleEnd;

    /// @notice the length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    /// @notice rewards queued from prior and current cycles
    struct QueuedRewards {
        uint128 priorCycleRewards;
        uint128 currentCycleRewards;
    }

    /// @notice mapping from gauges to queued rewards
    mapping(ERC20 => QueuedRewards) public marketQueuedRewards;

    /// @notice the gauge token for determining gauge allocations of the rewards stream
    ERC20Gauges public immutable gaugeToken;

    /// @notice contract to pull reward tokens from
    IRewardsStream public rewardsStream;

    constructor(
        ERC20 _rewardToken, 
        address _flywheel, 
        address _owner, 
        Authority _authority,
        uint32 _rewardsCycleLength,
        ERC20Gauges _gaugeToken,
        IRewardsStream _rewardsStream
    ) Auth(_owner, _authority) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
        rewardsCycleLength = _rewardsCycleLength;

        // seed initial rewardsCycleEnd
        rewardsCycleEnd = uint32(block.timestamp) / rewardsCycleLength * rewardsCycleLength;

        gaugeToken = _gaugeToken;

        rewardsStream = _rewardsStream;
    }

    /**
        @notice Iterates over all live gauges and queues up the rewards for the cycle
        @return totalQueuedForCycle the max amount of rewards to be distributed over the cycle
        @dev critical that there is no pagination to prevent double spending. All gauges must be synced atomically, unless the gaugeToken checkpoints rewards.

        GAS: Average path for `n` gauges - SLOAD * (n + 7) + SSTORE * (n + 1) + 1 token transfer
    */
    function queueRewardsForCycle() external requiresAuth returns (uint256 totalQueuedForCycle) {
        // ensure new cycle has begun
        require(block.timestamp > rewardsCycleEnd); // SLOAD
        
        // next cycle is always the next even divisor of the cycle length above current block timestamp.
        rewardsCycleEnd = (uint32(block.timestamp) + rewardsCycleLength) / rewardsCycleLength * rewardsCycleLength; // SSTORE

        // queue the rewards stream and sanity check the tokens were received
        uint256 balanceBefore = rewardToken.balanceOf(address(this)); // SLOAD
        totalQueuedForCycle = rewardsStream.getRewards();
        require(rewardToken.balanceOf(address(this)) - balanceBefore >= totalQueuedForCycle); // SLOAD

        // iterate over all gauges and update the rewards allocations
        address[] memory gauges = gaugeToken.gauges(); // n * SLOAD
        uint256 size = gauges.length;
        for (uint256 i = 0; i < size; i++) {
            ERC20 gauge = ERC20(gauges[i]);
            
            QueuedRewards memory queuedRewards = marketQueuedRewards[gauge]; // SLOAD

            // SSTORE
            marketQueuedRewards[gauge] = QueuedRewards({
                priorCycleRewards: queuedRewards.priorCycleRewards + queuedRewards.currentCycleRewards,
                currentCycleRewards: uint128(gaugeToken.calculateGaugeAllocation(address(gauge), totalQueuedForCycle)) // SLOAD * 3
            });
        }
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for market
     @return accruedRewards the amount of reward tokens accrued and transferred

     GAS: Average path includes 2 SLOAD, 1 warm SSTORE and 1 ERC20 transfer.
    */
    function getAccruedRewards(ERC20 market, uint32 lastUpdatedTimestamp) external override returns (uint256 accruedRewards) {
        require(msg.sender == flywheel, "!flywheel");

        QueuedRewards memory queuedRewards = marketQueuedRewards[market]; // SLOAD

        // no rewards
        if (queuedRewards.priorCycleRewards == 0 && queuedRewards.currentCycleRewards == 0) {
            return 0;
        }

        uint32 cycleEnd = rewardsCycleEnd; // SLOAD

        // If cycle ended, accrue all rewards
        if (block.timestamp >= cycleEnd) {
            accruedRewards = queuedRewards.priorCycleRewards + queuedRewards.currentCycleRewards;
            // TODO should I leave this > 0 to prevent cold SSTORE next cycle?
            delete marketQueuedRewards[market]; // SSTORE
        } else {
            // otherwise, return proportion of remaining rewards in cycle
            uint32 elapsed = uint32(block.timestamp) - lastUpdatedTimestamp;
            uint32 remaining = cycleEnd - lastUpdatedTimestamp;
                
            uint128 currentAccrued = queuedRewards.currentCycleRewards * elapsed / remaining;

            // SSTORE
            marketQueuedRewards[market] = QueuedRewards({
                priorCycleRewards: 0,
                currentCycleRewards: queuedRewards.currentCycleRewards - currentAccrued
            });

            // always accrue prior cycle completely plus proportion of current cycle complete
            accruedRewards = queuedRewards.priorCycleRewards + currentAccrued;
        }

        // finally, transfer tokens
        if (accruedRewards != 0) {
            rewardToken.safeTransfer(flywheel, accruedRewards);
        }
    }

    /// @notice set the rewards stream contract
    function setRewardsStream(IRewardsStream newRewardsStream) external requiresAuth {
        rewardsStream = newRewardsStream;
    }
}
