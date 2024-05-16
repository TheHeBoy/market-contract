// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct MSC20Order {
    address seller; // signer of the MSC20 token seller
    bytes32 listHash;
    string tick;
    uint256 amount;
    uint256 price;
    uint16 creatorFeeRate;
    bytes signature;
}

library OrderTypes {
    bytes32 internal constant MSC20_ORDER_HASH = keccak256(
        "MSC20Order(address seller,bytes32 listHash,string tick,uint256 amount,uint256 price,uint16 creatorFeeRate)"
    );

    function hash(MSC20Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                MSC20_ORDER_HASH,
                order.seller,
                order.listHash,
                keccak256(bytes(order.tick)),
                order.amount,
                order.price,
                order.creatorFeeRate
            )
        );
    }
}
