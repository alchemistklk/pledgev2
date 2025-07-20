// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./SafeErc20.sol";

contract SafeTransfer {
    using SafeERC20 for IERC20;

    event Redeem(address indexed recieptor, address indexed token, uint256 amount);

    /**
     * @notice  transfers money to the pool
     * @dev function to transfer
     * @param token of address
     * @param amount of amount
     * @return return amount
     */
    function getPayableAmount(address token, uint256 amount) internal returns (uint256) {
        if (token == address(0)) {
            amount = msg.value;
        } else if (amount > 0) {
            IERC20 oToken = IERC20(token);
            oToken.safeTransferFrom(msg.sender, address(this), amount);
        }
        return amount;
    }

    /**
     * @dev An auxiliary foundation which transfer amount stake coins to receiptor.
     * @param receiptor account.
     * @param token address
     * @param amount redeem amount.
     */
    function _redeem(address payable receiptor, address token, uint256 amount) internal {
        if (token == address(0)) {
            receiptor.transfer(amount);
        } else {
            IERC20 oToken = IERC20(token);
            oToken.safeTransfer(receiptor, amount);
        }
        emit Redeem(receiptor, token, amount);
    }
}
