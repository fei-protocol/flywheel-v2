// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IFlywheelRewards} from "./interfaces/IFlywheelRewards.sol";
import {IFlywheelBooster} from "./interfaces/IFlywheelBooster.sol";

/**
 @title Flywheel Core Incentives Manager
 @notice Flywheel is a general framework for managing token incentives.
         It is comprised of the Core (this contract), Rewards module, and optional Booster module.

         Core is responsible for maintaining reward accrual through reward indexes. 
         It delegates the actual accrual logic to the Rewards Module.

         For maximum accuracy and to avoid exploits, rewards accrual should be notified atomically through the accrue hook. 
         Accrue should be called any time tokens are transferred, minted, or burned.
 */
contract FlywheelCore is Auth {
    using SafeTransferLib for ERC20;

    event AddMarket(address indexed newMarket);

    event FlywheelRewardsUpdate(address indexed oldFlywheelRewards, address indexed newFlywheelRewards);

    event AccrueRewards(ERC20 indexed cToken, address indexed owner, uint rewardsDelta, uint rewardsIndex);
    
    event ClaimRewards(address indexed owner, uint256 amount);

    struct RewardsState {
        /// @notice The market's last updated index
        uint224 index;

        /// @notice The timestamp the index was last updated at
        uint32 lastUpdatedTimestamp;
    }

    /// @notice The token to reward
    ERC20 public immutable rewardToken;

    /// @notice the rewards contract for managing streams
    IFlywheelRewards public flywheelRewards;

    /// @notice optional booster module for calculating virtual balances on markets
    IFlywheelBooster public immutable flywheelBooster;

    /// @notice the fixed point factor of flywheel
    uint224 public constant ONE = 1e18;

    /// @notice The market index and last updated per market
    mapping(ERC20 => RewardsState) public marketState;

    /// @notice user index per market
    mapping(ERC20 => mapping(address => uint224)) public userIndex;

    /// @notice The accrued but not yet transferred rewards for each user
    mapping(address => uint256) public rewardsAccrued;

    /// @dev immutable flag for short-circuiting boosting logic
    bool internal immutable applyBoosting;

    constructor(
        ERC20 _rewardToken, 
        IFlywheelRewards _flywheelRewards, 
        IFlywheelBooster _flywheelBooster,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) {
        rewardToken = _rewardToken;
        flywheelRewards = _flywheelRewards;
        flywheelBooster = _flywheelBooster;

        applyBoosting = address(_flywheelBooster) != address(0);
    }

    /// @notice initialize a new market
    function addMarketForRewards(ERC20 market) external requiresAuth {
        marketState[market] = RewardsState({
            index: ONE,
            lastUpdatedTimestamp: uint32(block.timestamp)
        });

        emit AddMarket(address(market));
    }

    /// @notice swap out the flywheel rewards contract
    function setFlywheelRewards(IFlywheelRewards newFlywheelRewards) external requiresAuth {
        address oldFlywheelRewards = address(flywheelRewards);

        flywheelRewards = newFlywheelRewards;

        emit FlywheelRewardsUpdate(oldFlywheelRewards, address(newFlywheelRewards));
    }

    /// @notice accrue rewards for a single user on a market
    function accrue(ERC20 market, address user) public returns (uint256) {
        RewardsState memory state = marketState[market];

        if (state.index == 0) return 0;

        state = accrueMarket(market, state);
        return accrueUser(market, user, state);
    }

    /// @notice accrue rewards for two users on a market
    function accrue(ERC20 market, address user, address secondUser) public returns (uint256, uint256) {
        RewardsState memory state = marketState[market];

        if (state.index == 0) return (0, 0);

        state = accrueMarket(market, state);
        return (accrueUser(market, user, state), accrueUser(market, secondUser, state));
    }

    /// @notice claim rewards for a given owner
    function claim(address owner) external {
        uint256 accrued = rewardsAccrued[owner];

        if (accrued != 0) {
            rewardsAccrued[owner] = 0;

            rewardToken.safeTransfer(owner, accrued); 

            emit ClaimRewards(owner, accrued);
        }
    }

    /// @notice accumulate global rewards on a market
    function accrueMarket(ERC20 market, RewardsState memory state) private returns(RewardsState memory rewardsState) {
        // calculate accrued rewards through module
        uint256 marketRewardsAccrued = flywheelRewards.getAccruedRewards(market, state.lastUpdatedTimestamp);

        rewardsState = state;
        if (marketRewardsAccrued > 0) {
            // use the booster or token supply to calculate reward index denominator
            uint256 supplyTokens = applyBoosting ? flywheelBooster.boostedTotalSupply(market): market.totalSupply();

            // accumulate rewards per token onto the index, multiplied by fixed-point factor
            rewardsState = RewardsState({
                index: state.index + uint224(marketRewardsAccrued * ONE / supplyTokens),
                lastUpdatedTimestamp: uint32(block.timestamp)
            });
            marketState[market] = rewardsState;
        }
    }

    /// @notice accumulate rewards on a market for a specific user
    function accrueUser(ERC20 market, address user, RewardsState memory state) private returns (uint256) {
        // load indices
        uint224 supplyIndex = state.index;
        uint224 supplierIndex = userIndex[market][user];

        // sync user index to global
        userIndex[market][user] = supplyIndex;

        // if user hasn't yet accrued rewards, grant them interest from the market beginning if they have a balance
        // zero balances will have no effect other than syncing to global index
        if (supplierIndex == 0) {
            supplierIndex = ONE;
        }

        uint224 deltaIndex = supplyIndex - supplierIndex;
        // use the booster or token balance to calculate reward balance multiplier
        uint256 supplierTokens = applyBoosting ? flywheelBooster.boostedBalanceOf(market, user) : market.balanceOf(user);

        // accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta = supplierTokens * deltaIndex / ONE;
        uint256 supplierAccrued = rewardsAccrued[user] + supplierDelta;
        
        rewardsAccrued[user] = supplierAccrued;

        emit AccrueRewards(market, user, supplierDelta, supplyIndex);

        return supplierAccrued;
    }
}
