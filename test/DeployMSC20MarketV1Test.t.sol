// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MSC20MarketV1} from "../src/MSC20MarketV1.sol";
import {DeployMSC20MarketV1} from "../script/DeployMSC20MarketV1.s.sol";
import {OrderTypes, MSC20Order} from "../src/lib/OrderTypes.sol";

contract DeployMSC20MarketV1Test is StdCheats, Test {
    using OrderTypes for MSC20Order;

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

    MSC20MarketV1 public msc20MarketV1;
    uint256 public deployerKey;
    Account public seller = makeAccount("seller");
    Account public recipient = makeAccount("recipient");
    MSC20Order public order;

    function setUp() external {
        DeployMSC20MarketV1 deployMSC20MarketV1 = new DeployMSC20MarketV1();
        (msc20MarketV1, deployerKey) = deployMSC20MarketV1.run();
    }

    modifier createOrder(uint256 privateKey) {
        bytes32 listHash = hex"f390cdd44e2c0c71380c9b8252c62a3475ee77b7d5112f98dc5d8950b40542f4";
        string memory tick = "demo";
        // 收取手续费 1000/10000 = 10%
        order = MSC20Order(seller.addr, listHash, tick, 2, 200, 1000, bytes(""));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", msc20MarketV1.getDomainSeparator(), order.hash()));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        order.signature = abi.encodePacked(r, s, v);
        _;
    }

    function test_executeOrder() external createOrder(seller.key) {
        vm.expectEmit(true, true, true, true, address(msc20MarketV1));
        emit scriptions_protocol_TransferMSC20TokenForListing(seller.addr, recipient.addr, order.listHash);
        vm.expectEmit(true, true, true, true, address(msc20MarketV1));
        emit MSC20OrderExecuted(
            seller.addr, recipient.addr, order.listHash, order.tick, order.amount, order.price, order.creatorFeeRate
        );

        hoax(recipient.addr, 100 ether);
        uint256 cost = order.price;
        msc20MarketV1.executeOrder{value: order.price}(order, recipient.addr);

        uint256 protocolFeeAmount = cost * 1000 / 10000;
        uint256 finalSellerAmount = cost - protocolFeeAmount;
        assertEq(address(msc20MarketV1).balance, protocolFeeAmount);
        assertEq(address(seller.addr).balance, finalSellerAmount);
    }

    function test_cancelOrder() external createOrder(seller.key) {
        vm.expectEmit(true, true, true, true, address(msc20MarketV1));
        emit scriptions_protocol_TransferMSC20TokenForListing(seller.addr, seller.addr, order.listHash);
        vm.expectEmit(false, false, false, true, address(msc20MarketV1));
        emit MSC20OrderCanceled(order.seller, order.listHash);

        msc20MarketV1.cancelOrder(order);

        assertEq(msc20MarketV1.isCancelOrder(order.listHash), true);
    }

    // bytes32 private constant EIP712DOMAIN_TYPEHASH =
    //     keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    // bytes32 private constant STORAGE_TYPEHASH = keccak256("MSC20Order(address seller)");

    // function test_sign() external {
    //     MSC20Order memory order1 = MSC20Order(
    //         address(0x67b1d87101671b127f5f8714789C7192f7ad340e),
    //         hex"f0470513d46103383b3e0b96cb7031d6fa811e6db668cf8130de70a1d62aa74a",
    //         "demo",
    //         1,
    //         1,
    //         100,
    //         hex"0x2e6c3675c813a98ea6efb1f40d2856c5e47d64a372c68c1d20f94b854b67c6901de8de7e7fb88b95876b26a948ae8b3e4e019eec64584f4958114dd1a714f0871b"
    //     );

    //     // 获取签名消息hash
    //     bytes32 digest = keccak256(abi.encodePacked("\x19\x01", msc20MarketV1.getDomainSeparator(), order1.hash()));

    //     (uint8 v, bytes32 r, bytes32 s) =
    //         vm.sign(0x26e86e45f6fc45ec6e2ecd128cec80fa1d1505e5507dcd2ae58c3130a7a97b48, digest);
    //     bytes memory sign = abi.encodePacked(r, s, v);

    //     assertEq(order1.signature, sign);
    // }
}
