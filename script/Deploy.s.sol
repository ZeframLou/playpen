// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import "../src/StakingPoolFactory.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (StakingPoolFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        xERC20 xerc20Template = new xERC20();
        ERC20StakingPool erc20Template = new ERC20StakingPool();
        ERC721StakingPool erc721Template = new ERC721StakingPool();
        factory = StakingPoolFactory(
            create3.deploy(
                getCreate3ContractSalt("StakingPoolFactory"),
                bytes.concat(
                    type(StakingPoolFactory).creationCode, abi.encode(xerc20Template, erc20Template, erc721Template)
                )
            )
        );

        vm.stopBroadcast();
    }
}
