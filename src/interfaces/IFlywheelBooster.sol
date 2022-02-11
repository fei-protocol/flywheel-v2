// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

interface IFlywheelBooster {
    function boostedTotalSupply(ERC20 market) external view returns(uint256);

    function boostedBalanceOf(ERC20 market, address user) external view returns(uint256);
}
