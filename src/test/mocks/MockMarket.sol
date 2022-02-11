// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {MockERC20, ERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract MockMarket is MockERC20 {
    constructor() MockERC20("test token", "TKN", 18) {}

    function approve(ERC20 token, address spender) public {
        token.approve(spender, type(uint256).max);
    }
}
