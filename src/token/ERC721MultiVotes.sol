// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "../utils/MultiVotes.sol";
import "../../lib/EnumerableSet.sol";
import "../interfaces/Errors.sol";

/**
 @title ERC721 Multi-Delegation Voting contract
 @notice an ERC721 extension which allows delegations to multiple delegatees up to a user's balance on a given block.
 */
abstract contract ERC721MultiVotes is ERC721, MultiVotes {
    /*//////////////////////////////////////////////////////////////
                         VOTE CALCULATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function freeVotes(address account) public view virtual override returns (uint256) {
        return balanceOf(account) - userDelegatedVotes[account];
    }

    /*//////////////////////////////////////////////////////////////
                              ERC-721 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires freeVotes(user) < amount.
    /// _decrementVotesUntilFree is called as a greedy algorithm to free up votes.
    /// It may be more gas efficient to free weight before burning or transferring tokens.

    function _burn(uint256 id) internal virtual override {
        _decrementVotesUntilFree(ownerOf(id), 1);
        super._burn(id);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        _decrementVotesUntilFree(from, 1);
        super.transferFrom(from, to, id);
    }

    /*//////////////////////////////////////////////////////////////
                              EIP-721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view virtual override(MultiVotes) returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}
