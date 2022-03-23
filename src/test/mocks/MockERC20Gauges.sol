
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../token/ERC20Gauges.sol";

import {Hevm} from "solmate/test/utils/Hevm.sol";

contract MockERC20Gauges is ERC20Gauges {
    using EnumerableSet for EnumerableSet.AddressSet;

    Hevm internal constant hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    constructor(
        address _owner,
        uint32 _cycleLength
    ) ERC20("Token", "TKN", 18) Auth(_owner, Authority(address(0))) ERC20Gauges(_cycleLength) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }

    ////// Invariant test helpers

    function incrementGaugeByNum(uint256 gaugeNum, uint112 weight) public virtual {
        uint256 max = _gauges.length();
        gaugeNum = gaugeNum % max;
        uint32 currentCycle = getCurrentCycle();
        _incrementGaugeWeight(msg.sender, _gauges.at(gaugeNum), weight, currentCycle);
        _incrementUserAndGlobalWeights(msg.sender, weight, currentCycle);
    }

    function warpCycle(uint256 warp) public {
        hevm.warp(block.timestamp + (warp % gaugeCycleLength));
    }

    function gaugeWeightSum() public view virtual returns (uint112 sum) {
        for (uint256 i = 0; i < _gauges.length(); i++) {
            sum += getGaugeWeight(_gauges.at(i));
        }
    }

    function storedGaugeWeightSum() public view virtual returns (uint112 sum) {
        for (uint256 i = 0; i < _gauges.length(); i++) {
            sum += getStoredGaugeWeight(_gauges.at(i));
        }
    }

    function userWeightSum(address user) public view returns (uint112 sum) {
        for (uint256 i = 0; i < _userGauges[user].length(); i++) {
            sum += getGaugeWeight(_userGauges[user].at(i));
        }
    }

    function summedGaugeAllocation(uint256 quantity) public view returns(uint256 sum) {
        for (uint256 i = 0; i < _gauges.length(); i++) {
            sum += this.calculateGaugeAllocation(_gauges.at(i), quantity);
        }
    }
}
