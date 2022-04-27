// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import "./BaseFlywheelRewards.sol";

/** 
 @title Flywheel Proportional Reward Stream
 @notice Determines rewards per strategy based off of a fixed reward percentage per year (ie, an apr)   
         Uses an underlying ERC4626 vault's totalAssets() to determine the amount of tokens to reward.
 **/
contract FlywheelProportionalRewards is Auth, BaseFlywheelRewards {
    event RewardsInfoUpdate(ERC20 indexed strategy, uint224 rewardBasisPointsPerYear, uint32 rewardsEndTimestamp);

    struct RewardsInfo {
        /// @notice ERC4626 vault to use for calculating rewards
        address vault;
        /// @notice Reward bips per year
        uint224 rewardBasisPointsPerYear;
        /// @notice The timestamp the rewards end at
        /// @dev use 0 to specify no end
        uint32 rewardsEndTimestamp;
    }

    /// @notice rewards info per strategy
    mapping(ERC20 => RewardsInfo) public rewardsInfo;

    constructor(
        FlywheelCore _flywheel,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) BaseFlywheelRewards(_flywheel) {}

    /**
     @notice set reward basis points per year for a strategy
     @param strategy the strategy to accrue rewards for
     @param rewards the rewards info for the strategy
     */
    function setRewardsInfo(ERC20 strategy, RewardsInfo calldata rewards) external requiresAuth {
        rewardsInfo[strategy] = rewards;
        emit RewardsInfoUpdate(strategy, rewards.rewardBasisPointsPerYear, rewards.rewardsEndTimestamp);
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
        ERC4626 vault = ERC4626(rewards.vault);

        uint256 elapsed;
        if (rewards.rewardsEndTimestamp == 0 || rewards.rewardsEndTimestamp > block.timestamp) {
            elapsed = block.timestamp - lastUpdatedTimestamp;
        } else if (rewards.rewardsEndTimestamp > lastUpdatedTimestamp) {
            elapsed = rewards.rewardsEndTimestamp - lastUpdatedTimestamp;
        }

        amount = rewards.rewardBasisPointsPerYear * ((vault.totalAssets() * elapsed) / 365.25 days);
    }
}
