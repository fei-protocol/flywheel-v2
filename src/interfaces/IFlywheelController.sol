// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

interface IFlywheelController {
    function checkMarket(ERC20 market) external view returns (bool);
}