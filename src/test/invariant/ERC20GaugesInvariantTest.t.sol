// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20Gauges} from "../mocks/MockERC20Gauges.sol";

contract ERC20GaugesInvariantTest is DSTestPlus {

    MockERC20Gauges token;

    function setUp() public {
        token = new MockERC20Gauges(address(this), 3600); // 1 hour cycles
        token.mint(address(this), 100e18);
    }

    function invariant_userWeight() public {
        require(token.getUserWeight(address(this)) <= token.balanceOf(address(this)));
        require(token.userUnusedWeight(address(this)) == token.balanceOf(address(this)) - token.getUserWeight(address(this)));
        require(token.userWeightSum(address(this)) == token.getUserWeight(address(this)));
    }

    function invariant_maxGauges() public {
        require(token.canContractExceedMaxGauges(address(this)) || token.numUserGauges(address(this)) <= token.maxGauges());
    }

    function invariant_currentCycle() public {
        require(token.getCurrentCycle() >= block.timestamp);
        require(token.getCurrentCycle() % token.gaugeCycleLength() == 0);
    }

    function invariant_totalWeight() public {
        require(token.totalWeight() <= token.totalSupply());
        require(token.totalWeight() == token.gaugeWeightSum());
    }

    function invariant_storedTotalWeight() public {
        require(token.storedTotalWeight() == token.storedGaugeWeightSum());
    }

    function invariant_allocation() public {
        require(token.summedGaugeAllocation(1_000_000e18) <= 1_000_000e18);
    }
}