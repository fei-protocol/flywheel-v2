## `ERC20Gauges`






### `constructor(uint32 _gaugeCycleLength, uint32 _incrementFreezeWindow)` (internal)





### `getGaugeCycleEnd() → uint32` (public)

return the end of the current cycle. This is the next unix timestamp which evenly divides `gaugeCycleLength`



### `_getGaugeCycleEnd() → uint32` (internal)

see `getGaugeCycleEnd()`



### `getGaugeWeight(address gauge) → uint112` (public)

returns the current weight of a given gauge



### `getStoredGaugeWeight(address gauge) → uint112` (public)

returns the stored weight of a given gauge. This is the snapshotted weight as-of the end of the last cycle.



### `_getStoredWeight(struct ERC20Gauges.Weight gaugeWeight, uint32 currentCycle) → uint112` (internal)

see `getStoredGaugeWeight()`



### `totalWeight() → uint112` (external)

returns the current total allocated weight



### `storedTotalWeight() → uint112` (external)

returns the stored total allocated weight



### `gauges() → address[]` (external)

returns the set of live gauges



### `gauges(uint256 offset, uint256 num) → address[] values` (external)

returns a paginated subset of live gauges
      @param offset the index of the first gauge element to read
      @param num the number of gauges to return



### `isGauge(address gauge) → bool` (external)

returns true if `gauge` is in gauges



### `numGauges() → uint256` (external)

returns the number of live gauges



### `deprecatedGauges() → address[]` (external)

returns the set of previously live but now deprecated gauges



### `numDeprecatedGauges() → uint256` (external)

returns the number of live gauges



### `userGauges(address user) → address[]` (external)

returns the set of gauges the user has allocated to, may be live or deprecated.



### `isUserGauge(address user, address gauge) → bool` (external)

returns true if `gauge` is in user gauges



### `userGauges(address user, uint256 offset, uint256 num) → address[] values` (external)

returns a paginated subset of gauges the user has allocated to, may be live or deprecated.
      @param user the user to return gauges from.
      @param offset the index of the first gauge element to read.
      @param num the number of gauges to return.



### `numUserGauges(address user) → uint256` (external)

returns the number of user gauges



### `userUnusedWeight(address user) → uint256` (external)

helper function exposing the amount of weight available to allocate for a user



### `calculateGaugeAllocation(address gauge, uint256 quantity) → uint256` (external)

helper function for calculating the proportion of a `quantity` allocated to a gauge
     @param gauge the gauge to calculate allocation of
     @param quantity a representation of a resource to be shared among all gauges
     @return the proportion of `quantity` allocated to `gauge`. Returns 0 if gauge is not live, even if it has weight.



### `incrementGauge(address gauge, uint112 weight) → uint112 newUserWeight` (external)

increment a gauge with some weight for the caller
     @param gauge the gauge to increment
     @param weight the amount of weight to increment on gauge
     @return newUserWeight the new user weight



### `_incrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle)` (internal)





### `_incrementUserAndGlobalWeights(address user, uint112 weight, uint32 cycle) → uint112 newUserWeight` (internal)





### `incrementGauges(address[] gaugeList, uint112[] weights) → uint256 newUserWeight` (external)

increment a list of gauges with some weights for the caller
     @param gaugeList the gauges to increment
     @param weights the weights to increment by
     @return newUserWeight the new user weight



### `decrementGauge(address gauge, uint112 weight) → uint112 newUserWeight` (external)

decrement a gauge with some weight for the caller
     @param gauge the gauge to decrement
     @param weight the amount of weight to decrement on gauge
     @return newUserWeight the new user weight



### `_decrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle)` (internal)





### `_decrementUserAndGlobalWeights(address user, uint112 weight, uint32 cycle) → uint112 newUserWeight` (internal)





### `decrementGauges(address[] gaugeList, uint112[] weights) → uint112 newUserWeight` (external)

decrement a list of gauges with some weights for the caller
     @param gaugeList the gauges to decrement
     @param weights the list of weights to decrement on the gauges
     @return newUserWeight the new user weight



### `addGauge(address gauge)` (external)

add a new gauge. Requires auth by `authority`.



### `_addGauge(address gauge)` (internal)





### `removeGauge(address gauge)` (external)

remove a new gauge. Requires auth by `authority`.



### `_removeGauge(address gauge)` (internal)





### `replaceGauge(address oldGauge, address newGauge)` (external)

replace a gauge. Requires auth by `authority`.



### `setMaxGauges(uint256 newMax)` (external)

set the new max gauges. Requires auth by `authority`.



### `setContractExceedMaxGauges(address account, bool canExceedMax)` (external)

set the canContractExceedMaxGauges flag for an account.



### `_burn(address from, uint256 amount)` (internal)

NOTE: any "removal" of tokens from a user requires userUnusedWeight < amount.
_decrementWeightUntilFree is called as a greedy algorithm to free up weight.
It may be more gas efficient to free weight before burning or transferring tokens.



### `transfer(address to, uint256 amount) → bool` (public)





### `transferFrom(address from, address to, uint256 amount) → bool` (public)





### `_decrementWeightUntilFree(address user, uint256 weight)` (internal)

a greedy algorithm for freeing weight before a token burn/transfer
frees up entire gauges, so likely will free more than `weight`




### `IncrementGaugeWeight(address user, address gauge, uint256 weight, uint32 cycleEnd)`

emitted when incrementing a gauge



### `DecrementGaugeWeight(address user, address gauge, uint256 weight, uint32 cycleEnd)`

emitted when decrementing a gauge



### `AddGauge(address gauge)`

emitted when adding a new gauge to the live set.



### `RemoveGauge(address gauge)`

emitted when removing a gauge from the live set.



### `MaxGaugesUpdate(uint256 oldMaxGauges, uint256 newMaxGauges)`

emitted when updating the max number of gauges a user can delegate to.



### `CanContractExceedMaxGaugesUpdate(address account, bool canContractExceedMaxGauges)`

emitted when changing a contract's approval to go over the max gauges.




### `Weight`


uint112 storedWeight


uint112 currentWeight


uint32 currentCycle



