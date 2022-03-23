// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20MultiVotes, ERC20MultiVotes} from "../mocks/MockERC20MultiVotes.sol";

contract ERC20MultiVotesTest is DSTestPlus {

    MockERC20MultiVotes token;
    address constant delegate1 = address(0xDEAD);
    address constant delegate2 = address(0xBEEF);

    function setUp() public {
        token = new MockERC20MultiVotes(address(this));
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);
    }

    function invariant_userVotes() public {
        require(token.userDelegatedVotes(address(this)) <= token.balanceOf(address(this)));
        require(token.freeVotes(address(this)) == token.balanceOf(address(this)) - token.userDelegatedVotes(address(this)));
        require(token.userDelegateSum(address(this)) == token.userDelegatedVotes(address(this)));
    }

    function invariant_maxDelegates() public {
        require(token.canContractExceedMaxDelegates(address(this)) || token.delegateCount(address(this)) <= token.maxDelegates());
    }
}