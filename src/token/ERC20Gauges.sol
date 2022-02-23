// SPDX-License-Identifier: MIT
// Forked logic from OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "solmate/auth/Auth.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeCastLib.sol";
import "../../lib/EnumerableSet.sol";

abstract contract ERC20Gauges is ERC20, Auth {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    uint256 public maxGauges;

    struct GaugeVote {
        uint32 goodSince;
        address gauge;
    }
    
    // user -> gaugeVote
    mapping(address => GaugeVote) public getUserGaugeVote;

    // gauge -> weight
    mapping(address => uint256) public getGaugeWeight;

    // gauge -> timestamp
    mapping(address => uint32) public gaugeGoodSince;

    uint256 public totalWeight;

    EnumerableSet.AddressSet internal _gauges;

    modifier checkGauge(address gauge) {
        require(_gauges.contains(gauge));
        _;
    }

    function gauges() external view returns(address[] memory) {
        return _gauges.values();
    }

    function numGauges() external view returns(uint256) {
        return _gauges.length();
    }

    function unusedWeight() external view returns(uint256) {
        return totalSupply - totalWeight;
    }

    function stakeGauge(address gauge) external {
        _unstakeGauge(msg.sender);

        getGaugeWeight[gauge] += balanceOf[msg.sender];
    } 

    function _incrementGauge(address to, address gauge, uint256 amount) external {
        getGaugeWeight[gauge] += amount;
        totalWeight += amount;
    }

    function unstakeGauge() external {
        _unstakeGauge(msg.sender);
    }

    function _unstakeGauge(address from) internal {

    }

    ////// Admin Gauge Ops

    function addGauge(address gauge) external requiresAuth {
        require(_gauges.length() <= maxGauges);
        _addGauge(gauge);
    }

    function _addGauge(address gauge) internal {
        require(_gauges.length() <= maxGauges);
        gaugeGoodSince[gauge] = block.timestamp.safeCastTo32();
    }

    function removeGauge(address gauge) external requiresAuth {
        _removeGauge(gauge);
    }

    function _removeGauge(address gauge) internal {
        require(_gauges.remove(gauge)); // fail loud
        gaugeGoodSince[gauge] = 0;
        totalWeight -= getGaugeWeight[gauge];
        getGaugeWeight[gauge] = 0;
    }

    function replaceGauge(address oldGauge, address newGauge) external requiresAuth {
        _removeGauge(oldGauge);
        _addGauge(newGauge);
    }

    function setMaxGauges(uint256 newMax) external requiresAuth {
        require(newMax >= _gauges.length());
        maxGauges = newMax;
    }

    /**
     * @dev Enforce user has removed from gauge before burning
     */
    function _burn(address from, uint256 amount) internal virtual override {
        _unstakeGauge(from);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns(bool) {
        _unstakeGauge(msg.sender);
        super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns(bool) {
        _unstakeGauge(from);
        super.transferFrom(from, to, amount);
    }
}