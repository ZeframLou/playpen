// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

contract BaseTest is Test {
    function assertEqEpsilonBelow(uint256 a, uint256 b, uint256 epsilonInv) internal {
        assertLe(a, b);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqEpsilonAround(uint256 a, uint256 b, uint256 epsilonInv) internal {
        assertLe(a, b + b / epsilonInv);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqDecimalEpsilonBelow(uint256 a, uint256 b, uint256 decimals, uint256 epsilonInv) internal {
        assertLeDecimal(a, b, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }

    function assertEqDecimalEpsilonAround(uint256 a, uint256 b, uint256 decimals, uint256 epsilonInv) internal {
        if (a == 0) a = 1;
        if (b == 0) b = 1;
        assertLeDecimal(a, b + b / epsilonInv, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }
}
