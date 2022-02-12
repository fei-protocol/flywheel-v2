// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockBooster {

    uint256 public totalBoost;

    mapping(address=>uint256) public boosts;

    function setBoost(address user, uint256 boost) public {
        totalBoost -= boosts[user];
        boosts[user] = boost;
        totalBoost += boost;
    }

    function boostedTotalSupply(ERC20 market) external view returns(uint256) {
        return market.totalSupply() + totalBoost;
    }

    function boostedBalanceOf(ERC20 market, address user) external view returns(uint256) {
        return market.balanceOf(user) + boosts[user];
    }
}
