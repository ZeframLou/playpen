// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.11;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestERC20 is ERC20("", "", 18) {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
