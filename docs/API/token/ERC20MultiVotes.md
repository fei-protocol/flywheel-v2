## `ERC20MultiVotes`






### `checkpoints(address account, uint32 pos) → struct ERC20MultiVotes.Checkpoint` (public)

Get the `pos`-th checkpoint for `account`.



### `numCheckpoints(address account) → uint32` (public)

Get number of checkpoints for `account`.



### `freeVotes(address account) → uint256` (public)

Gets the amount of unallocated votes for `account`.




### `getVotes(address account) → uint256` (public)

Gets the current votes balance for `account`.




### `getPastVotes(address account, uint256 blockNumber) → uint256` (public)

Retrieve the number of votes for `account` at the end of `blockNumber`.




### `average(uint256 a, uint256 b) → uint256` (internal)





### `setMaxDelegates(uint256 newMax)` (external)

set the new max delegates per user. Requires auth by `authority`.



### `setContractExceedMaxDelegates(address account, bool canExceedMax)` (external)

set the canContractExceedMaxDelegates flag for an account.



### `delegatesVotesCount(address delegator, address delegatee) → uint256` (public)

Get the amount of votes currently delegated by `delegator` to `delegatee`.




### `delegates(address delegator) → address[]` (public)

Get the list of delegates from `delegator`.




### `delegateCount(address delegator) → uint256` (public)

Get the number of delegates from `delegator`.




### `delegate(address delegatee, uint256 amount)` (public)

Delegate `amount` votes from the sender to `delegatee`.


requires "freeVotes(msg.sender) > amount" and will not exceed max delegates

### `undelegate(address delegatee, uint256 amount)` (public)

Undelegate `amount` votes from the sender from `delegatee`.




### `delegate(address newDelegatee)` (external)

Delegate all votes `newDelegatee`. First undelegates from an existing delegate. If `newDelegatee` is zero, only undelegates.


undefined for `delegateCount(msg.sender) > 1`

### `_delegate(address delegator, address newDelegatee)` (internal)





### `_delegate(address delegator, address delegatee, uint256 amount)` (internal)





### `_undelegate(address delegator, address delegatee, uint256 amount)` (internal)





### `_burn(address from, uint256 amount)` (internal)

NOTE: any "removal" of tokens from a user requires freeVotes(user) < amount.
_decrementVotesUntilFree is called as a greedy algorithm to free up votes.
It may be more gas efficient to free weight before burning or transferring tokens.



### `transfer(address to, uint256 amount) → bool` (public)





### `transferFrom(address from, address to, uint256 amount) → bool` (public)





### `_decrementVotesUntilFree(address user, uint256 votes)` (internal)

a greedy algorithm for freeing votes before a token burn/transfer
frees up entire delegates, so likely will free more than `votes`



### `delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)` (public)






### `MaxDelegatesUpdate(uint256 oldMaxDelegates, uint256 newMaxDelegates)`

emitted when updating the maximum amount of delegates per user



### `CanContractExceedMaxDelegatesUpdate(address account, bool canContractExceedMaxDelegates)`

emitted when updating the canContractExceedMaxDelegates flag for an account



### `Delegation(address delegator, address delegate, uint256 amount)`



Emitted when a `delegator` delegates `amount` votes to `delegate`.

### `Undelegation(address delegator, address delegate, uint256 amount)`



Emitted when a `delegator` undelegates `amount` votes from `delegate`.

### `DelegateVotesChanged(address delegate, uint256 previousBalance, uint256 newBalance)`



Emitted when a token transfer or delegate change results in changes to an account's voting power.


### `Checkpoint`


uint32 fromBlock


uint224 votes



