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
    }

    /*///////////////////////////////////////////////////////////////
                        TEST ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testSetMaxDelegates(uint256 max) public {
        token.setMaxDelegates(max);
        assertTrue(token.maxDelegates() == max);
    }

    function testSetMaxDelegatesNonOwnerFails() public {
        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        token.setMaxDelegates(7);
    }

    function testCanContractExceedMax() public {
        token.setContractExceedMaxDelegates(address(this), true);
        assertTrue(token.canContractExceedMaxDelegates(address(this)));
    }

    function testCanContractExceedMaxNonOwnerFails() public {
        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        token.setContractExceedMaxDelegates(address(this), true);
    }

    function testCanContractExceedMaxNonContractFails() public {
        hevm.expectRevert(abi.encodeWithSignature("NonContractError()"));
        token.setContractExceedMaxDelegates(address(1), true);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST USER DELEGATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice test delegating different delegatees 8 times by multiple users and amounts
    function testDelegate(
        address[8] memory from,
        address[8] memory delegates,
        uint224[8] memory amounts
    ) public {
        token.setMaxDelegates(8);

        unchecked {
            uint224 sum;
            for (uint256 i = 0; i < 8; i++) {
                hevm.assume(sum + amounts[i] >= sum && from[i] != address(0) && delegates[i] != address(0));
                sum += amounts[i];

                token.mint(from[i], amounts[i]);

                uint256 userDelegatedBefore = token.userDelegatedVotes(from[i]);
                uint256 delegateVotesBefore = token.delegatesVotesCount(from[i], delegates[i]);
                uint256 votesBefore = token.getVotes(delegates[i]);

                hevm.prank(from[i]);
                token.incrementDelegation(delegates[i], amounts[i]);
                assertTrue(token.delegatesVotesCount(from[i], delegates[i]) == delegateVotesBefore + amounts[i]);
                assertTrue(token.userDelegatedVotes(from[i]) == userDelegatedBefore + amounts[i]);
                assertTrue(token.getVotes(delegates[i]) == votesBefore + amounts[i]);
            }
        }
    }

    function testDelegateToAddressZeroFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(address(0), 50e18);
    }

    function testDelegateOverVotesFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(delegate2, 51e18);
    }

    function testDelegateOverMaxDelegatesFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        token.incrementDelegation(delegate2, 1e18);
        hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(address(this), 1e18);
    }

    function testDelegateOverMaxDelegatesApproved() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.setContractExceedMaxDelegates(address(this), true);
        token.incrementDelegation(delegate1, 50e18);
        token.incrementDelegation(delegate2, 1e18);
        token.incrementDelegation(address(this), 1e18);

        assertTrue(token.delegateCount(address(this)) == 3);
        assertTrue(token.delegateCount(address(this)) > token.maxDelegates());
        assertTrue(token.userDelegatedVotes(address(this)) == 52e18);
    }

    /// @notice test undelegate twice, 2 tokens each after delegating by 4.
    function testUndelegate() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 4e18);

        token.undelegate(delegate1, 2e18);
        assertTrue(token.delegatesVotesCount(address(this), delegate1) == 2e18);
        assertTrue(token.userDelegatedVotes(address(this)) == 2e18);
        assertTrue(token.getVotes(delegate1) == 2e18);
        assertTrue(token.freeVotes(address(this)) == 98e18);

        token.undelegate(delegate1, 2e18);
        assertTrue(token.delegatesVotesCount(address(this), delegate1) == 0);
        assertTrue(token.userDelegatedVotes(address(this)) == 0);
        assertTrue(token.getVotes(delegate1) == 0);
        assertTrue(token.freeVotes(address(this)) == 100e18);
    }

    function testDecrementOverWeightFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
        token.undelegate(delegate1, 51e18);
    }

    function testBackwardCompatibleDelegate(
        address oldDelegatee,
        uint112 beforeDelegateAmount,
        address newDelegatee,
        uint112 mintAmount
    ) public {
        hevm.assume(mintAmount >= beforeDelegateAmount);
        token.mint(address(this), mintAmount);
        token.setMaxDelegates(2);

        if (oldDelegatee == address(0)) {
            hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        token.incrementDelegation(oldDelegatee, beforeDelegateAmount);

        token.delegate(newDelegatee);

        uint256 expected = newDelegatee == address(0) ? 0 : mintAmount;
        uint256 expectedFree = newDelegatee == address(0) ? mintAmount : 0;

        assertTrue(oldDelegatee == newDelegatee || token.delegatesVotesCount(address(this), oldDelegatee) == 0);
        assertTrue(token.delegatesVotesCount(address(this), newDelegatee) == expected);
        assertTrue(token.userDelegatedVotes(address(this)) == expected);
        assertTrue(token.getVotes(newDelegatee) == expected);
        assertTrue(token.freeVotes(address(this)) == expectedFree);
    }

    function testBackwardCompatibleDelegateBySig(
        uint128 delegatorPk,
        address oldDelegatee,
        uint112 beforeDelegateAmount,
        address newDelegatee,
        uint112 mintAmount
    ) public {
        hevm.assume(delegatorPk != 0);
        address owner = hevm.addr(delegatorPk);

        hevm.assume(mintAmount >= beforeDelegateAmount);
        token.mint(owner, mintAmount);
        token.setMaxDelegates(2);

        if (oldDelegatee == address(0)) {
            hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        hevm.prank(owner);
        token.incrementDelegation(oldDelegatee, beforeDelegateAmount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            delegatorPk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(token.DELEGATION_TYPEHASH(), newDelegatee, 0, block.timestamp))
                )
            )
        );

        uint256 expected = newDelegatee == address(0) ? 0 : mintAmount;
        uint256 expectedFree = newDelegatee == address(0) ? mintAmount : 0;

        token.delegateBySig(newDelegatee, 0, block.timestamp, v, r, s);
        assertTrue(oldDelegatee == newDelegatee || token.delegatesVotesCount(owner, oldDelegatee) == 0);
        assertTrue(token.delegatesVotesCount(owner, newDelegatee) == expected);
        assertTrue(token.userDelegatedVotes(owner) == expected);
        assertTrue(token.getVotes(newDelegatee) == expected);
        assertTrue(token.freeVotes(owner) == expectedFree);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST PAST VOTES
    //////////////////////////////////////////////////////////////*/

    function testPastVotes() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 4e18);

        hevm.roll(1);
        uint256 block1 = block.number;
        assertTrue(token.numCheckpoints(delegate1) == 1);
        ERC20MultiVotes.Checkpoint memory checkpoint1 = token.checkpoints(delegate1, 0);
        assertTrue(checkpoint1.fromBlock == block1);
        assertTrue(checkpoint1.votes == 4e18);

        // Same block increase voting power
        token.incrementDelegation(delegate1, 4e18);

        assertTrue(token.numCheckpoints(delegate1) == 1);
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertTrue(checkpoint1.fromBlock == block1);
        assertTrue(checkpoint1.votes == 8e18);

        hevm.roll(2);
        uint256 block2 = block.number;
        assertEq(block2, block1 + 1);

        // Next block decrease voting power
        token.undelegate(delegate1, 2e18);

        assertTrue(token.numCheckpoints(delegate1) == 2); // new checkpint

        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertTrue(checkpoint1.fromBlock == block1);
        assertTrue(checkpoint1.votes == 8e18);

        // new checkpoint 2
        ERC20MultiVotes.Checkpoint memory checkpoint2 = token.checkpoints(delegate1, 1);
        assertTrue(checkpoint2.fromBlock == block2);
        assertTrue(checkpoint2.votes == 6e18);

        hevm.roll(10);
        uint256 block3 = block.number;
        assertTrue(block3 == block2 + 8);

        // 10 blocks later increase voting power
        token.incrementDelegation(delegate1, 4e18);

        assertTrue(token.numCheckpoints(delegate1) == 3); // new checkpint

        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertTrue(checkpoint1.fromBlock == block1);
        assertTrue(checkpoint1.votes == 8e18);

        // checkpoint 2 stays same
        checkpoint2 = token.checkpoints(delegate1, 1);
        assertTrue(checkpoint2.fromBlock == block2);
        assertTrue(checkpoint2.votes == 6e18);

        // new checkpoint 3
        ERC20MultiVotes.Checkpoint memory checkpoint3 = token.checkpoints(delegate1, 2);
        assertTrue(checkpoint3.fromBlock == block3);
        assertTrue(checkpoint3.votes == 10e18);

        // finally, test getPastVotes between checkpoints
        assertTrue(token.getPastVotes(delegate1, block1) == 8e18);
        assertTrue(token.getPastVotes(delegate1, block2) == 6e18);
        assertTrue(token.getPastVotes(delegate1, block2 + 4) == 6e18);
        assertTrue(token.getPastVotes(delegate1, block3 - 1) == 6e18);

        hevm.expectRevert(abi.encodeWithSignature("BlockError()"));
        token.getPastVotes(delegate1, block3); // revert same block

        hevm.roll(11);
        assertTrue(token.getPastVotes(delegate1, block3) == 10e18);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDecrementUntilFreeWhenFree() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        assertTrue(token.freeVotes(address(this)) == 70e18);

        token.burn(address(this), 50e18);
        assertTrue(token.freeVotes(address(this)) == 20e18);

        assertTrue(token.delegatesVotesCount(address(this), delegate1) == 10e18);
        assertTrue(token.userDelegatedVotes(address(this)) == 30e18);
        assertTrue(token.getVotes(delegate1) == 10e18);
        assertTrue(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        assertTrue(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeSingle() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        assertTrue(token.freeVotes(address(this)) == 70e18);

        token.transfer(address(1), 80e18);
        assertTrue(token.freeVotes(address(this)) == 0);

        assertTrue(token.delegatesVotesCount(address(this), delegate1) == 0);
        assertTrue(token.userDelegatedVotes(address(this)) == 20e18);
        assertTrue(token.getVotes(delegate1) == 0);
        assertTrue(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        assertTrue(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeDouble() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        assertTrue(token.freeVotes(address(this)) == 70e18);

        token.approve(address(1), 100e18);
        hevm.prank(address(1));
        token.transferFrom(address(this), address(1), 90e18);

        assertTrue(token.freeVotes(address(this)) == 10e18);

        assertTrue(token.delegatesVotesCount(address(this), delegate1) == 0);
        assertTrue(token.userDelegatedVotes(address(this)) == 0);
        assertTrue(token.getVotes(delegate1) == 0);
        assertTrue(token.delegatesVotesCount(address(this), delegate2) == 0);
        assertTrue(token.getVotes(delegate2) == 0);
    }
}
