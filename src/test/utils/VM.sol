// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

interface VM {
    // When fuzzing, generate new inputs if conditional not met
    function assume(bool) external;

    // Set block.timestamp (newTimestamp)
    function warp(uint256) external;

    // Set block.height (newHeight)
    function roll(uint256) external;

    // Loads a storage slot from an address (who, slot)
    function load(address, bytes32) external returns (bytes32);

    // Stores a value to an address' storage slot, (who, slot, value)
    function store(
        address,
        bytes32,
        bytes32
    ) external;

    // Signs data, (privateKey, digest) => (r, v, s)
    function sign(uint256, bytes32)
        external
        returns (
            uint8,
            bytes32,
            bytes32
        );

    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);

    // Performs a foreign function call via terminal, (stringInputs) => (result)
    function ffi(string[] calldata) external returns (bytes memory);

    // Performs the next smart contract call with specified `msg.sender`, (newSender)
    function prank(address) external;

    // Performs all the following smart contract calls with specified `msg.sender`, (newSender)
    function startPrank(address) external;

    // Stop smart contract calls using the specified address with prankStart()
    function stopPrank() external;

    // Sets an address' balance, (who, newBalance)
    function deal(address, uint256) external;

    // Sets an address' code, (who, newCode)
    function etch(address, bytes calldata) external;

    // Expects an error on next call
    function expectRevert(bytes calldata) external;

    // Expects the next emitted event. Params check topic 1, topic 2, topic 3 and data are the same.
    function expectEmit(
        bool,
        bool,
        bool,
        bool
    ) external;

    // Mocks a call to an address, returning specified data.
    // Calldata can either be strict or a partial match, e.g. if you only
    // pass a Solidity selector to the expected calldata, then the entire Solidity
    // function will be mocked.
    function mockCall(
        address,
        bytes calldata,
        bytes calldata
    ) external;

    // Clears all mocked calls
    function clearMockedCalls() external;

    // Expect a call to an address with the specified calldata.
    // Calldata can either be strict or a partial match
    function expectCall(address, bytes calldata) external;
}
