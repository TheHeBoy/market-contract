// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MSC20Order} from "../lib/OrderTypes.sol";

interface IMSC20Market {
    error IMSC20Market__MsgValueInvalid();
    error IMSC20Market__ETHTransferFailed();
    error IMSC20Market__Cancelled();
    error IMSC20Market__SignerInvalid();
    error IMSC20Market__SignatureInvalid();
    error IMSC20Market__NoOrdersMatched();

    event NewTrustedVerifier(address trustedVerifier);
    event AllowBatchOrdersUpdate(bool allowBatchOrders);

    event scriptions_protocol_TransferMSC20Token(
        address indexed from, address indexed to, string indexed tick, uint256 amount
    );
    event scriptions_protocol_TransferMSC20TokenForListing(address indexed from, address indexed to, bytes32 listHash);
    event MSC20OrderExecuted(
        address seller,
        address recipient,
        bytes32 indexed listHash,
        string tick,
        uint256 amount,
        uint256 price,
        uint16 feeRate
    );
    event MSC20OrderCanceled(address seller, bytes32 indexed listHash);

    function executeOrder(MSC20Order calldata order, address recipient) external payable;
    function executeOrders(MSC20Order[] calldata orders, address recipient) external payable;

    function cancelOrder(MSC20Order calldata order) external;
    function cancelOrders(MSC20Order[] calldata orders) external;
}
