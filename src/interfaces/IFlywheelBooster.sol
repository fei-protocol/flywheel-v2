// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 @title Balance Booster Module for Flywheel
 @notice An optional module for virtually boosting user balances. This allows a Flywheel Core to plug into some balance boosting logic.

 Boosting logic can be associated with referrals, vote-escrow, or other strategies. It can even be used to model exotic strategies like borrowing.
 */
interface IFlywheelBooster {
    function boostedTotalSupply(ERC20 market) external view returns(uint256);

    function boostedBalanceOf(ERC20 market, address user) external view returns(uint256);
}
