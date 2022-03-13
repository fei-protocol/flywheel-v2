// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solmate/auth/Auth.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeCastLib.sol";
import "../../lib/EnumerableSet.sol";

/** 
 @title  An ERC20 with an embedded "Gauge" style vote with liquid weights
 @author Tribe DAO
 @notice This contract is meant to be used to support gauge style votes with weights associated with resource allocation.
         Holders can allocate weight in any proportion to supported gauges.
         A "gauge" is represented by an address which would receive the resources periodically or continuously.

         For example, gauges can be used to direct token emissions, similar to Curve or Tokemak.
         Alternatively, gauges can be used to direct another quantity such as relative access to a line of credit.

         The contract's Authority <https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol> manages the gauge set and cap.
         "Live" gauges are in the set.  
         Users can only add weight to live gauges but can remove weight from live or deprecated gauges.
         Gauges can be deprecated and reinstated, and will maintain any non-removed weight from before.

 @dev    SECURITY NOTES: `maxGauges` is a critical variable to protect against gas DOS attacks upon token transfer. 
         This must be low enough to allow complicated transactions to fit in a block.
 
         Weight state is preserved on the gauge and user level even when a gauge is removed, in case it is re-added. 
         This maintains state efficiently, and global accounting is managed only on the `_totalWeight`
*/
abstract contract ERC20Gauges is ERC20, Auth {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    /*///////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidGaugeError();

    error SizeMismatchError();

    error MaxGaugeError();

    error OverWeightError();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event IncrementGaugeWeight(address indexed user, address indexed gauge, uint256 weight);
    
    event DecrementGaugeWeight(address indexed user, address indexed gauge, uint256 weight);
    
    event AddGauge(address indexed gauge);
    
    event RemoveGauge(address indexed gauge);

    event MaxGaugesUpdate(uint256 oldMaxGauges, uint256 newMaxGauges);

    /*///////////////////////////////////////////////////////////////
                        GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice the length of a gauge cycle
    uint32 public immutable gaugeCycleLength;

    struct Weight {
        uint112 storedWeight;
        uint112 currentWeight;
        uint32 currentCycle;
    }

    /// @notice the maximum amount of live gauges at a given time
    uint256 public maxGauges;

    /// @notice a mapping from users to gauges to a user's allocated weight to that gauge
    mapping(address => mapping(address => uint112)) public getUserGaugeWeight;

    /// @notice a mapping from a user to their total allocated weight across all gauges
    /// @dev NOTE this may contain weights for deprecated gauges
    mapping(address => uint112) public getUserWeight;

    /// @notice a mapping from a gauge to the total weight allocated to it
    /// @dev NOTE this may contain weights for deprecated gauges
    mapping(address => Weight) internal _getGaugeWeight;

    /// @notice the total global allocated weight ONLY of live gauges
    Weight internal _totalWeight;

    EnumerableSet.AddressSet internal _gauges;

    // Store deprecated gauges in case a user needs to free dead weight
    EnumerableSet.AddressSet internal _deprecatedGauges;


    constructor(uint32 _gaugeCycleLength) {
        gaugeCycleLength = _gaugeCycleLength;
    }

    /*///////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the current weight of a given gauge
    function getGaugeWeight(address gauge) public view returns(uint112) {
        return _getGaugeWeight[gauge].currentWeight;
    }

    /// @notice returns the current total allocated weight
    function totalWeight() external view returns(uint112) {
        return _totalWeight.currentWeight;
    }

    /// @notice returns the set of live gauges
    function gauges() external view returns(address[] memory) {
        return _gauges.values();
    }

    /// @notice returns the set of previously live but now deprecated gauges
    function deprecatedGauges() external view returns(address[] memory) {
        return _deprecatedGauges.values();
    }

    /// @notice returns the number of live gauges
    function numGauges() external view returns(uint256) {
        return _gauges.length();
    }

    /// @notice helper function exposing the amount of weight available to allocate for a user
    function userUnusedWeight(address user) external view returns(uint256) {
        return balanceOf[user] - getUserWeight[user];
    }

    /** 
     @notice helper function for calculating the proportion of a `quantity` allocated to a gauge
     @param gauge the gauge to calculate allocation of
     @param quantity a representation of a resource to be shared among all gauges
     @return the proportion of `quantity` allocated to `gauge`. Returns 0 if gauge is not live, even if it has weight.
    */
    function calculateGaugeAllocation(address gauge, uint256 quantity) external view returns(uint256) {
        if (!_gauges.contains(gauge)) return 0;
        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength; // todo consider cycle as input parameter
        
        Weight memory gaugeWeight = _getGaugeWeight[gauge];
        
        uint112 total =  _totalWeight.currentCycle < currentCycle ? _totalWeight.currentWeight : _totalWeight.storedWeight;
        uint112 weight =  gaugeWeight.currentCycle < currentCycle ? gaugeWeight.currentWeight : gaugeWeight.storedWeight;
        return quantity * weight / total;
    }

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice increment a gauge with some weight for the caller
     @param gauge the gauge to increment
     @param weight the amount of weight to increment on gauge
     @return newUserWeight the new user weight
    */
    function incrementGauge(address gauge, uint112 weight) external returns(uint112 newUserWeight) {
        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;
        _incrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        return _incrementUserAndGlobalWeights(msg.sender, weight, currentCycle);
    } 

    function _incrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle) internal {
        if (!_gauges.contains(gauge)) revert InvalidGaugeError();

        getUserGaugeWeight[user][gauge] += weight;

        _writeGaugeWeight(_getGaugeWeight[gauge], _add, weight, cycle); 

        emit IncrementGaugeWeight(user, gauge, weight);
    }

    function _incrementUserAndGlobalWeights(address user, uint112 weight, uint32 cycle) internal returns(uint112 newUserWeight) {
        newUserWeight = getUserWeight[user] + weight;
        // Ensure under weight
        if (newUserWeight > balanceOf[user]) revert OverWeightError();

        // Update gauge state
        getUserWeight[user] = newUserWeight; 

        _writeGaugeWeight(_totalWeight, _add, weight, cycle); 
    }

    /** 
     @notice increment a list of gauges with some weights for the caller
     @param gaugeList the gauges to increment
     @param weights the weights to increment by
     @return newUserWeight the new user weight
    */
    function incrementGauges(address[] calldata gaugeList, uint112[] calldata weights) external returns(uint256 newUserWeight) {
        
        uint256 size = gaugeList.length;
        if (weights.length != size) revert SizeMismatchError();

        // store total in summary for batch update on user/global state
        uint112 weightsSum;

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        // Update gauge specific state
        for (uint256 i = 0; i < size; i++) {
            address gauge = gaugeList[i];
            uint112 weight = weights[i];
            weightsSum += weight;

            _incrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        }
        return _incrementUserAndGlobalWeights(msg.sender, weightsSum, currentCycle);
    }

    /** 
     @notice decrement a gauge with some weight for the caller
     @param gauge the gauge to decrement
     @param weight the amount of weight to decrement on gauge
     @return newUserWeight the new user weight
    */
    function decrementGauge(address gauge, uint112 weight) external returns (uint112 newUserWeight) {
        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;
        
        // All operations will revert on underflow, protecting against bad inputs
        _decrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        return _decrementUserAndGlobalWeights(msg.sender, weight, currentCycle);
    }

    function _decrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle) internal {
        getUserGaugeWeight[user][gauge] -= weight;

        _writeGaugeWeight(_getGaugeWeight[gauge], _subtract, weight, cycle); 

        emit DecrementGaugeWeight(user, gauge, weight);
    }

    function _decrementUserAndGlobalWeights(address user, uint112 weight, uint32 cycle) internal returns(uint112 newUserWeight) {
        newUserWeight = getUserWeight[user] - weight;

        getUserWeight[user] = newUserWeight;
        _writeGaugeWeight(_totalWeight, _subtract, weight, cycle); 
    }

    /** 
     @notice decrement a list of gauges with some weights for the caller
     @param gaugeList the gauges to decrement
     @param weights the list of weights to decrement on the gauges
     @return newUserWeight the new user weight
    */
    function decrementGauges(address[] calldata gaugeList, uint112[] calldata weights) external returns (uint112 newUserWeight) {
        uint256 size = gaugeList.length;
        if (weights.length != size) revert SizeMismatchError();

        // store total in summary for batch update on user/global state
        uint112 weightsSum;

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        // Update gauge specific state
        // All operations will revert on underflow, protecting against bad inputs
        for (uint256 i = 0; i < size; i++) {
            address gauge = gaugeList[i];
            uint112 weight = weights[i];
            weightsSum += weight;

            _decrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        }
        return _decrementUserAndGlobalWeights(msg.sender, weightsSum, currentCycle);
    }

    /// @notice free deprecated gauges for a user. This method can be called by anyone.
    function freeDeprecatedGauges(address user, address[] memory gaugeList) public {
        uint256 size = gaugeList.length;

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        uint112 totalFree;
        for (uint256 i = 0; i < size; i++) {
            address gauge = gaugeList[i];
            if (!_deprecatedGauges.contains(gauge)) revert InvalidGaugeError();

            uint112 weight = getUserGaugeWeight[user][gauge];
            if (weight != 0) {
                totalFree += weight;
                _decrementGaugeWeight(user, gauge, weight, currentCycle);
            }
        }
        getUserWeight[user] -= totalFree;
    }

    function _writeGaugeWeight(
        Weight storage weight,
        function(uint112, uint112) view returns (uint112) op,
        uint112 delta,
        uint32 cycle
    ) private {
        uint112 previousCurrent = weight.currentWeight;
        uint112 stored = weight.currentCycle < cycle ? previousCurrent : weight.storedWeight;

        weight.storedWeight = stored;
        weight.currentWeight = op(previousCurrent, delta);
        weight.currentCycle = cycle;
    }

    function _add(uint112 a, uint112 b) private pure returns (uint112) {
        return a + b;
    }

    function _subtract(uint112 a, uint112 b) private pure returns (uint112) {
        return a - b;
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice add a new gauge. Requires auth by `authority`.
    function addGauge(address gauge) external requiresAuth {
        if (_gauges.length() >= maxGauges) revert MaxGaugeError();
        _addGauge(gauge);
    }

    function _addGauge(address gauge) internal {
        // add and fail loud if already present or zero address
        if (gauge == address(0) || !_gauges.add(gauge)) revert InvalidGaugeError();
        _deprecatedGauges.remove(gauge); // silently remove gauge from deprecated if present

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        // Check if some previous weight exists and re-add to total. Gauge and user weights are preserved.
        uint112 weight = _getGaugeWeight[gauge].currentWeight;
        if (weight > 0) {
            _writeGaugeWeight(_totalWeight, _add, weight, currentCycle);
        }

        emit AddGauge(gauge);
    }

    /// @notice remove a new gauge. Requires auth by `authority`.
    function removeGauge(address gauge) external requiresAuth {
        _removeGauge(gauge);
    }

    function _removeGauge(address gauge) internal {
        // remove and fail loud if not present
        if (!_gauges.remove(gauge)) revert InvalidGaugeError(); 
        _deprecatedGauges.add(gauge); // add gauge to deprecated. Must not be present if previously in live set.

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        // Remove weight from total but keep the gauge and user weights in storage in case gauge is re-added.
        uint112 weight = _getGaugeWeight[gauge].currentWeight;
        if (weight > 0) {
            _writeGaugeWeight(_totalWeight, _subtract, weight, currentCycle);
        }

        emit RemoveGauge(gauge);
    }

    /// @notice replace a gauge. Requires auth by `authority`.
    function replaceGauge(address oldGauge, address newGauge) external requiresAuth {
        _removeGauge(oldGauge);
        _addGauge(newGauge);
    }

    /// @notice set the new max gauges. Requires auth by `authority`.
    function setMaxGauges(uint256 newMax) external requiresAuth {
        if (newMax < _gauges.length()) revert MaxGaugeError();

        uint256 oldMax = maxGauges;
        maxGauges = newMax;

        emit MaxGaugesUpdate(oldMax, newMax);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires userUnusedWeight < amount.
    /// _decrementWeightUntilFree is called as a greedy algorithm to free up weight.
    /// It may be more gas efficient to free weight before burning or transferring tokens.


    function _burn(address from, uint256 amount) internal virtual override {
        _decrementWeightUntilFree(from, amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns(bool) {
        _decrementWeightUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns(bool) {
        _decrementWeightUntilFree(from, amount);
        return super.transferFrom(from, to, amount);
    }

    /// a greedy algorithm for freeing weight before a token burn/transfer
    /// frees up entire gauges, so likely will free more than `weight`
    function _decrementWeightUntilFree(address user, uint256 weight) internal {
        uint256 userFreeWeight = balanceOf[user] - getUserWeight[user];

        // early return if already free
        if (userFreeWeight >= weight) return;

        uint32 currentCycle = (uint32(block.timestamp) + gaugeCycleLength) / gaugeCycleLength * gaugeCycleLength;

        // cache total for batch updates
        uint112 totalFreed;

        // Loop through all live gauges
        address[] memory gaugeList = _gauges.values();

        // Free gauges until through entire list or under weight
        uint256 size = gaugeList.length;
        for (uint256 i = 0; i < size && (userFreeWeight + totalFreed) < weight; i++) {
            address gauge = gaugeList[i];
            uint112 userGaugeWeight = getUserGaugeWeight[user][gauge];
            if (userGaugeWeight != 0) {
                totalFreed += userGaugeWeight;
                _decrementGaugeWeight(user, gauge, userGaugeWeight, currentCycle);
            }
        }

        getUserWeight[user] -= totalFreed;
        _writeGaugeWeight(_totalWeight, _subtract, totalFreed, currentCycle);

        // If still not under weight, either user has deprecated weight OR weight > user balance.
        if (userFreeWeight + totalFreed < weight) {
            freeDeprecatedGauges(user, _deprecatedGauges.values());
            assert(getUserWeight[user] == 0); // everything should be free now
        }
    }
}
