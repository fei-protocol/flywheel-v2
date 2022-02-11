// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IFlywheelRewards} from "./interfaces/IFlywheelRewards.sol";
import {IFlywheelController} from "./interfaces/IFlywheelController.sol";
import {IFlywheelBooster} from "./interfaces/IFlywheelBooster.sol";

contract FlywheelCore {

    struct RewardsState {
        /// @notice The market's last updated index or
        uint224 index;

        /// @notice The timestamp the index was last updated at
        uint32 lastUpdatedTimestamp;
    }

    /// @dev The token to reward
    ERC20 public immutable rewardToken;

    IFlywheelRewards public immutable flywheelRewards;

    IFlywheelController public immutable flywheelController;

    IFlywheelBooster public immutable flywheelBooster;

    uint224 public constant ONE = 1e18;

    /// @notice The market index
    mapping(ERC20 => RewardsState) public marketState;

    /// @notice user index per market
    mapping(ERC20 => mapping(address => uint224)) public userIndex;

    /// @notice The accrued but not yet transferred to each user
    mapping(address => uint256) public rewardsAccrued;

    bool internal immutable applyBoosting;

    constructor(
        ERC20 _rewardToken, 
        IFlywheelRewards _flywheelRewards, 
        IFlywheelController _flywheelController, 
        IFlywheelBooster _flywheelBooster
    ) {
        rewardToken = _rewardToken;
        flywheelRewards = _flywheelRewards;
        flywheelController = _flywheelController;
        flywheelBooster = _flywheelBooster;

        applyBoosting = address(_flywheelBooster) != address(0);
    }

    function addMarketForRewards(ERC20 market) external {
        require(flywheelController.checkMarket(market), "bad market");
        marketState[market] = RewardsState({
            index: ONE,
            lastUpdatedTimestamp: uint32(block.timestamp)
        });
    }

    function accrueMarket(ERC20 market, RewardsState memory state) internal {
        uint256 marketRewardsAccrued = flywheelRewards.rewardsPerTokenAccrued(market, state.lastUpdatedTimestamp);
        if (marketRewardsAccrued > 0) {
            uint256 supplyTokens = applyBoosting ? flywheelBooster.boostedTotalSupply(market): market.totalSupply();

            marketState[market] = RewardsState({
                index: state.index + uint224(marketRewardsAccrued * ONE / supplyTokens),
                lastUpdatedTimestamp: uint32(block.timestamp)
            });
        }
    }

    function accrueUser(ERC20 market, address user, RewardsState memory state) internal {
        uint224 supplyIndex = state.index;
        uint224 supplierIndex = userIndex[market][user];
        userIndex[market][user] = supplyIndex;

        if (supplierIndex == 0) {
            supplierIndex = ONE;
        }

        uint224 deltaIndex = supplyIndex - supplierIndex;
        uint256 supplierTokens = applyBoosting ? flywheelBooster.boostedBalanceOf(market, user) : market.balanceOf(user);

        uint256 supplierDelta = supplierTokens * deltaIndex / ONE;
        uint256 supplierAccrued = rewardsAccrued[user] + supplierDelta;
        
        rewardsAccrued[user] = supplierAccrued;
    }

    function accrue(ERC20 market, address user) public {
        RewardsState memory state = marketState[market];

        if (state.index == 0) return;

        accrueMarket(market, state);
        accrueUser(market, user, state);
    }

    function accrue(ERC20 market, address user, address secondUser) public {
        RewardsState memory state = marketState[market];

        if (state.index == 0) return;

        accrueMarket(market, state);
        accrueUser(market, user, state);
        accrueUser(market, secondUser, state);
    }

    function claim(address owner) external {
        uint256 accrued = rewardsAccrued[owner];
        rewardsAccrued[owner] = 0;

        rewardToken.transfer(owner, accrued); 
    }
}
