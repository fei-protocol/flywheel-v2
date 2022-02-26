// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

import {ERC20Gauges} from "../token/ERC20Gauges.sol";

/** 
 @title Flywheel Gauge Reward Stream
 @notice Determines rewards based on gauges
*/ 
contract FlywheelGaugeRewards is Auth, IFlywheelRewards {
    using SafeTransferLib for ERC20;

    event RewardsInfoUpdate(ERC20 indexed market, uint224 rewardsPerSecond, uint32 rewardsEndTimestamp);

    /// @notice the reward token paid
    ERC20 public immutable rewardToken;

    /// @notice the flywheel core contract
    address public immutable flywheel;

    uint32 public rewardsCycleEnd;

    uint32 public rewardsCycleLength;

    /// @notice rewards info per market
    mapping(ERC20 => uint256) public rewardsPerSecond;

    uint256 totalRewardsPerSecond;

    ERC20Gauges public gaugeToken;

    constructor(
        ERC20 _rewardToken, 
        address _flywheel, 
        address _owner, 
        Authority _authority
    ) Auth(_owner, _authority) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
    }

    function refreshRewardsPerSecond() public {
        uint256 oldCycleEnd = rewardsCycleEnd;
        uint256 cycleLength = rewardsCycleLength;
        require(block.timestamp > oldCycleEnd);
        uint256 cyclesBehind = ((block.timestamp - oldCycleEnd) / cycleLength) + 1;

        rewardsCycleEnd = uint32(oldCycleEnd + (cycleLength * cyclesBehind));

        address[] memory gauges = gaugeToken.gauges();
        uint256 size = gauges.length;
        for (uint256 i = 0; i < size; i++) {
            address gauge = gauges[i];
            uint256 marketRewardsPerSecond = gaugeToken.calculateGaugeAllocation(gauge, totalRewardsPerSecond);
        }
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for market
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 market, uint32 lastUpdatedTimestamp) external override returns (uint256 amount) {
        require(msg.sender == flywheel, "!flywheel");

        uint256 elapsed = block.timestamp - lastUpdatedTimestamp;        
        amount = rewardsPerSecond[market] * elapsed;

        uint256 balance = rewardToken.balanceOf(address(this));

        if (balance < amount) {
            amount = balance;
        }

        if (amount != 0) {
            rewardToken.safeTransfer(flywheel, amount);
        }
    }
}
