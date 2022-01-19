// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20StakingPool} from "./ERC20StakingPool.sol";
import {ClonesWithCallData} from "./lib/ClonesWithCallData.sol";

/// @title StakingPoolFactory
/// @author zefram.eth
/// @notice Factory for deploying ERC20StakingPool and ERC721StakingPool contracts cheaply
contract StakingPoolFactory {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using ClonesWithCallData for address;

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The contract used as the template for all clones created
    ERC20StakingPool public immutable implementation;

    constructor(ERC20StakingPool implementation_) {
        implementation = implementation_;
    }

    /// @notice Creates an ERC20StakingPool contract
    /// @dev Uses a modified minimal proxy contract that stores immutable parameters in code and
    /// passes them in through calldata. See ClonesWithCallData.
    /// @param rewardToken The token being rewarded to stakers
    /// @param stakeToken The token being staked in the pool
    /// @param DURATION The length of each reward period, in seconds
    /// @return stakingPool The created ERC20StakingPool contract
    function createERC20StakingPool(
        ERC20 rewardToken,
        ERC20 stakeToken,
        uint64 DURATION
    ) external returns (ERC20StakingPool stakingPool) {
        bytes memory ptr;
        ptr = new bytes(48);
        assembly {
            mstore(add(ptr, 0x20), shl(0x60, rewardToken))
            mstore(add(ptr, 0x34), shl(0x60, stakeToken))
            mstore(add(ptr, 0x48), shl(0xc0, DURATION))
        }

        stakingPool = ERC20StakingPool(
            address(implementation).cloneWithCallDataProvision(ptr)
        );
        stakingPool.initialize(msg.sender);
    }
}
