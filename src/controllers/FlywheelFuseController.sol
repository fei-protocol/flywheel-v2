// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {IFlywheelController} from "../interfaces/IFlywheelController.sol";

interface Comptroller {
    function markets(CToken cToken) external view returns(bool, uint);

    function getRewardsDistributors() external view returns(address[] memory);
}

interface CToken {
    function comptroller() external view returns (Comptroller);
}

contract FlywheelFuseController is IFlywheelController, Auth {

    mapping (ERC20 => bool) public override checkMarket;

    address public immutable flywheel;

    constructor(address _flywheel, address _owner, Authority _authority) Auth(_owner, _authority) {
        flywheel = _flywheel;
    }

    function setMarket(ERC20 market) external requiresAuth {
        CToken cToken = CToken(address(market));
        // Make sure cToken is listed
        Comptroller comptroller = Comptroller(address(cToken.comptroller()));
        (bool isListed, ) = comptroller.markets(cToken);
        require(isListed == true, "comp market is not listed");

        // Make sure distributor is added
        bool distributorAdded = false;
        address[] memory distributors = comptroller.getRewardsDistributors();
        for (uint256 i = 0; i < distributors.length; i++) if (distributors[i] == flywheel) distributorAdded = true; 
        require(distributorAdded == true, "distributor not added");

        checkMarket[market] = true;
    }
}
