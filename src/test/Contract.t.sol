// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

contract ContractTest is BaseTest {
    function setUp() public {}

    function testExample() public {
        console.log("Hello world!");
        assertTrue(true);
    }
}
