// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "./BaseFlywheelRewards.sol";

/** 
 @title Flywheel Static Reward Stream
 @notice Determines rewards per strategy based on a fixed reward rate per second
*/
contract FlywheelStaticRewards is BaseFlywheelRewards {
    event RewardsInfoUpdate(ERC20 indexed strategy, uint224 rewardsPerSecond, uint32 rewardsEndTimestamp);

    struct RewardsInfo {
        /// @notice Rewards per second
        uint224 rewardsPerSecond;
        /// @notice The timestamp the rewards end at
        /// @dev use 0 to specify no end
        uint32 rewardsEndTimestamp;
    }

    /// @notice rewards info per strategy
    mapping(ERC20 => RewardsInfo) public rewardsInfo;

    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    /**
     @notice initialize the state of the strategy with external data
     @param strategy the strategy to initialize
     @param data arbitrary data that is abi.encode()-ed
    */
    function initializeStrategy(ERC20 strategy, bytes memory data) external onlyFlywheel {
        RewardsInfo memory rewards = abi.decode(data, (RewardsInfo));
        rewardsInfo[strategy] = rewards;
        emit RewardsInfoUpdate(strategy, rewards.rewardsPerSecond, rewards.rewardsEndTimestamp);
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param strategy the strategy to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for strategy
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 strategy, uint32 lastUpdatedTimestamp)
        external
        view
        override
        onlyFlywheel
        returns (uint256 amount)
    {
        RewardsInfo memory rewards = rewardsInfo[strategy];

        uint256 elapsed;
        if (rewards.rewardsEndTimestamp == 0 || rewards.rewardsEndTimestamp > block.timestamp) {
            elapsed = block.timestamp - lastUpdatedTimestamp;
        } else if (rewards.rewardsEndTimestamp > lastUpdatedTimestamp) {
            elapsed = rewards.rewardsEndTimestamp - lastUpdatedTimestamp;
        }

        amount = rewards.rewardsPerSecond * elapsed;
    }
}
