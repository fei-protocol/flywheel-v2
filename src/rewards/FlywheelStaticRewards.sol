// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

/** 
 @title Flywheel Static Reward Stream
 @notice Determines rewards based on a fixed reward rate per second
*/ 
contract FlywheelStaticRewards is Auth, IFlywheelRewards {
    using SafeTransferLib for ERC20;

    event RewardsInfoUpdate(ERC20 indexed market, uint224 rewardsPerSecond, uint32 rewardsEndTimestamp);

    /// @notice the reward token paid
    ERC20 public immutable rewardToken;

    /// @notice the flywheel core contract
    address public immutable flywheel;

    struct RewardsInfo {
        /// @notice Rewards per second
        uint224 rewardsPerSecond;

        /// @notice The timestamp the rewards end at
        /// @dev use 0 to specify no end
        uint32 rewardsEndTimestamp;
    }

    /// @notice rewards info per market
    mapping(ERC20 => RewardsInfo) public rewardsInfo;

    constructor(
        ERC20 _rewardToken, 
        address _flywheel, 
        address _owner, 
        Authority _authority
    ) Auth(_owner, _authority) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
    }

    /**
     @notice set rewards per second and rewards end time for Fei Rewards
     @param market the market to accrue rewards for
     @param rewards the rewards info for the market
     */    
    function setRewardsInfo(ERC20 market, RewardsInfo calldata rewards) external requiresAuth {
        rewardsInfo[market] = rewards;
        emit RewardsInfoUpdate(market, rewards.rewardsPerSecond, rewards.rewardsEndTimestamp);
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for market
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 market, uint32 lastUpdatedTimestamp) external override returns (uint256 amount) {
        require(msg.sender == flywheel, "!flywheel");

        RewardsInfo memory rewards = rewardsInfo[market];

        uint256 elapsed;
        if (rewards.rewardsEndTimestamp == 0 || rewards.rewardsEndTimestamp > block.timestamp) {
            elapsed = block.timestamp - lastUpdatedTimestamp;
        } else if (rewards.rewardsEndTimestamp > lastUpdatedTimestamp) {
            elapsed = rewards.rewardsEndTimestamp - lastUpdatedTimestamp;
        }
        
        amount = rewards.rewardsPerSecond * elapsed;

        uint256 balance = rewardToken.balanceOf(address(this));

        if (balance < amount) {
            amount = balance;
        }

        if (amount != 0) {
            rewardToken.safeTransfer(flywheel, amount);
        }
    }
}
