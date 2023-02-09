// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {ClonesWithImmutableArgs} from "@clones/ClonesWithImmutableArgs.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import {xERC20} from "./xERC20.sol";
import {ERC20StakingPool} from "./ERC20StakingPool.sol";
import {ERC721StakingPool} from "./ERC721StakingPool.sol";

/// @title StakingPoolFactory
/// @author zefram.eth
/// @notice Factory for deploying ERC20StakingPool and ERC721StakingPool contracts cheaply
contract StakingPoolFactory {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event CreateXERC20(xERC20 stakingPool);
    event CreateERC20StakingPool(ERC20StakingPool stakingPool);
    event CreateERC721StakingPool(ERC721StakingPool stakingPool);

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The contract used as the template for all xERC20 contracts created
    xERC20 public immutable xERC20Implementation;

    /// @notice The contract used as the template for all ERC20StakingPool contracts created
    ERC20StakingPool public immutable erc20StakingPoolImplementation;

    /// @notice The contract used as the template for all ERC721StakingPool contracts created
    ERC721StakingPool public immutable erc721StakingPoolImplementation;

    constructor(
        xERC20 xERC20Implementation_,
        ERC20StakingPool erc20StakingPoolImplementation_,
        ERC721StakingPool erc721StakingPoolImplementation_
    ) {
        xERC20Implementation = xERC20Implementation_;
        erc20StakingPoolImplementation = erc20StakingPoolImplementation_;
        erc721StakingPoolImplementation = erc721StakingPoolImplementation_;
    }

    /// @notice Creates an xERC20 contract
    /// @dev Uses a modified minimal proxy contract that stores immutable parameters in code and
    /// passes them in through calldata. See ClonesWithImmutableArgs.
    /// @param name The name of the xERC20 token
    /// @param symbol The symbol of the xERC20 token
    /// @param decimals The decimals of the xERC20 token
    /// @param stakeToken The token being staked in the pool
    /// @param DURATION The length of each reward period, in seconds
    /// @return stakingPool The created xERC20 contract
    function createXERC20(bytes32 name, bytes32 symbol, uint8 decimals, ERC20 stakeToken, uint64 DURATION)
        external
        returns (xERC20 stakingPool)
    {
        bytes memory data = abi.encodePacked(name, symbol, decimals, stakeToken, DURATION);

        stakingPool = xERC20(address(xERC20Implementation).clone(data));
        stakingPool.initialize(msg.sender);

        emit CreateXERC20(stakingPool);
    }

    /// @notice Creates an ERC20StakingPool contract
    /// @dev Uses a modified minimal proxy contract that stores immutable parameters in code and
    /// passes them in through calldata. See ClonesWithImmutableArgs.
    /// @param rewardToken The token being rewarded to stakers
    /// @param stakeToken The token being staked in the pool
    /// @param DURATION The length of each reward period, in seconds
    /// @return stakingPool The created ERC20StakingPool contract
    function createERC20StakingPool(ERC20 rewardToken, ERC20 stakeToken, uint64 DURATION)
        external
        returns (ERC20StakingPool stakingPool)
    {
        bytes memory data = abi.encodePacked(rewardToken, stakeToken, DURATION);

        stakingPool = ERC20StakingPool(address(erc20StakingPoolImplementation).clone(data));
        stakingPool.initialize(msg.sender);

        emit CreateERC20StakingPool(stakingPool);
    }

    /// @notice Creates an ERC721StakingPool contract
    /// @dev Uses a modified minimal proxy contract that stores immutable parameters in code and
    /// passes them in through calldata. See ClonesWithImmutableArgs.
    /// @param rewardToken The token being rewarded to stakers
    /// @param stakeToken The token being staked in the pool
    /// @param DURATION The length of each reward period, in seconds
    /// @return stakingPool The created ERC721StakingPool contract
    function createERC721StakingPool(ERC20 rewardToken, ERC721 stakeToken, uint64 DURATION)
        external
        returns (ERC721StakingPool stakingPool)
    {
        bytes memory data = abi.encodePacked(rewardToken, stakeToken, DURATION);

        stakingPool = ERC721StakingPool(address(erc721StakingPoolImplementation).clone(data));
        stakingPool.initialize(msg.sender);

        emit CreateERC721StakingPool(stakingPool);
    }
}
