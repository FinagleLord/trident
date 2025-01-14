// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

import "./IERC20.sol";
import "./IPool.sol";

interface IConstantProductPool is IPool, IERC20 {
    function getNativeReserves()
        external
        view
        returns (
            uint256 _nativeReserve0,
            uint256 _nativeReserve1,
            uint32
        );
}
