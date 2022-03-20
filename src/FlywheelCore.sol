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

    event AddStrategy(address indexed newStrategy);

    event FlywheelRewardsUpdate(address indexed newFlywheelRewards);

    event FlywheelBoosterUpdate(address indexed newBooster);

    event AccrueRewards(ERC20 indexed cToken, address indexed owner, uint rewardsDelta, uint rewardsIndex);
    
    event ClaimRewards(address indexed owner, uint256 amount);

    struct RewardsState {
        /// @notice The strategy's last updated index
        uint224 index;

        /// @notice The timestamp the index was last updated at
        uint32 lastUpdatedTimestamp;
    }

    /// @notice The token to reward
    ERC20 public immutable rewardToken;

    /// @notice the rewards contract for managing streams
    IFlywheelRewards public flywheelRewards;

    /// @notice optional booster module for calculating virtual balances on strategies
    IFlywheelBooster public flywheelBooster;

    /// @notice the fixed point factor of flywheel
    uint224 public constant ONE = 1e18;

    /// @notice The strategy index and last updated per strategy
    mapping(ERC20 => RewardsState) public strategyState;

    /// @notice user index per strategy
    mapping(ERC20 => mapping(address => uint224)) public userIndex;

    /// @notice The accrued but not yet transferred rewards for each user
    mapping(address => uint256) public rewardsAccrued;

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
    }

    /// @notice initialize a new strategy
    function addStrategyForRewards(ERC20 strategy) external requiresAuth {
        require(strategyState[strategy].index == 0, "strategy");
        strategyState[strategy] = RewardsState({
            index: ONE,
            lastUpdatedTimestamp: uint32(block.timestamp)
        });

        emit AddStrategy(address(strategy));
    }

    /// @notice swap out the flywheel rewards contract
    function setFlywheelRewards(IFlywheelRewards newFlywheelRewards) external requiresAuth {
        flywheelRewards = newFlywheelRewards;

        emit FlywheelRewardsUpdate(address(newFlywheelRewards));
    }

    /// @notice swap out the flywheel booster contract
    function setBooster(IFlywheelBooster newBooster) external requiresAuth {
        flywheelBooster = newBooster;

        emit FlywheelBoosterUpdate(address(newBooster));
    }

    /// @notice accrue rewards for a single user on a strategy
    function accrue(ERC20 strategy, address user) public returns (uint256) {
        RewardsState memory state = strategyState[strategy];

        if (state.index == 0) return 0;

        state = accrueStrategy(strategy, state);
        return accrueUser(strategy, user, state);
    }

    /// @notice accrue rewards for two users on a strategy
    function accrue(ERC20 strategy, address user, address secondUser) public returns (uint256, uint256) {
        RewardsState memory state = strategyState[strategy];

        if (state.index == 0) return (0, 0);

        state = accrueStrategy(strategy, state);
        return (accrueUser(strategy, user, state), accrueUser(strategy, secondUser, state));
    }

    /// @notice claim rewards for a given owner
    function claimRewards(address owner) external {
        uint256 accrued = rewardsAccrued[owner];

        if (accrued != 0) {
            rewardsAccrued[owner] = 0;

            rewardToken.safeTransferFrom(address(flywheelRewards), owner, accrued); 

            emit ClaimRewards(owner, accrued);
        }
    }

    /// @notice accumulate global rewards on a strategy
    function accrueStrategy(ERC20 strategy, RewardsState memory state) private returns(RewardsState memory rewardsState) {
        // calculate accrued rewards through module
        uint256 strategyRewardsAccrued = flywheelRewards.getAccruedRewards(strategy, state.lastUpdatedTimestamp);

        rewardsState = state;
        if (strategyRewardsAccrued > 0) {
            // use the booster or token supply to calculate reward index denominator
            uint256 supplyTokens = address(flywheelBooster) != address(0) ? flywheelBooster.boostedTotalSupply(strategy): strategy.totalSupply();

            // accumulate rewards per token onto the index, multiplied by fixed-point factor
            rewardsState = RewardsState({
                index: state.index + uint224(strategyRewardsAccrued * ONE / supplyTokens),
                lastUpdatedTimestamp: uint32(block.timestamp)
            });
            strategyState[strategy] = rewardsState;
        }
    }

    /// @notice accumulate rewards on a strategy for a specific user
    function accrueUser(ERC20 strategy, address user, RewardsState memory state) private returns (uint256) {
        // load indices
        uint224 supplyIndex = state.index;
        uint224 supplierIndex = userIndex[strategy][user];

        // sync user index to global
        userIndex[strategy][user] = supplyIndex;

        // if user hasn't yet accrued rewards, grant them interest from the strategy beginning if they have a balance
        // zero balances will have no effect other than syncing to global index
        if (supplierIndex == 0) {
            supplierIndex = ONE;
        }

        uint224 deltaIndex = supplyIndex - supplierIndex;
        // use the booster or token balance to calculate reward balance multiplier
        uint256 supplierTokens = address(flywheelBooster) != address(0) ? flywheelBooster.boostedBalanceOf(strategy, user) : strategy.balanceOf(user);

        // accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta = supplierTokens * deltaIndex / ONE;
        uint256 supplierAccrued = rewardsAccrued[user] + supplierDelta;
        
        rewardsAccrued[user] = supplierAccrued;

        emit AccrueRewards(strategy, user, supplierDelta, supplyIndex);

        return supplierAccrued;
    }
}
