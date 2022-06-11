// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {VM} from "../utils/VM.sol";
import {console} from "../utils/console.sol";

contract BaseTest is DSTest {
    VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertEqEpsilonBelow(
        uint256 a,
        uint256 b,
        uint256 epsilonInv
    ) internal {
        assertLe(a, b);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqEpsilonAround(
        uint256 a,
        uint256 b,
        uint256 epsilonInv
    ) internal {
        assertLe(a, b + b / epsilonInv);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqDecimalEpsilonBelow(
        uint256 a,
        uint256 b,
        uint256 decimals,
        uint256 epsilonInv
    ) internal {
        assertLeDecimal(a, b, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }

    function assertEqDecimalEpsilonAround(
        uint256 a,
        uint256 b,
        uint256 decimals,
        uint256 epsilonInv
    ) internal {
        if(a == 0) a = 1;
        if(b == 0) b = 1;
        assertLeDecimal(a, b + b / epsilonInv, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }
}
