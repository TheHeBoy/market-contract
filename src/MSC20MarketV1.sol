// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IMSC20Market} from "./interfaces/IMSC20Market.sol";
import {OrderTypes, MSC20Order} from "./lib/OrderTypes.sol";

contract MSC20MarketV1 is
    IMSC20Market,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable
{
    using OrderTypes for MSC20Order;
    using ECDSA for bytes32;

    mapping(bytes32 => bool) private cancelled;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __EIP712_init("MSC20Market", "1");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    fallback() external payable {}

    receive() external payable {}

    function executeOrder(MSC20Order calldata order, address recipient)
        public
        payable
        override
        nonReentrant
        whenNotPaused
    {
        _verifyOrder(order);
        _executeOrder(order, recipient, msg.value);
    }

    function executeOrders(MSC20Order[] calldata orders, address recipient) public payable nonReentrant whenNotPaused {
        require(orders.length <= 20, "Too much orders");
        uint256 userBalance = msg.value;
        uint256 i = 0;
        for (; i < orders.length; i++) {
            MSC20Order calldata order = orders[i];

            if (cancelled[order.listHash]) {
                continue;
            }

            require(userBalance >= order.price, "Insufficient balance");
            userBalance -= order.price;

            _verifyOrder(order);
            _executeOrder(order, recipient, order.price);
        }

        if (i == 0) {
            revert IMSC20Market__NoOrdersMatched();
        }

        if (userBalance > 0) {
            _transferETHWithGasLimit(payable(msg.sender), userBalance);
        }
    }

    function cancelOrder(MSC20Order calldata order) public override nonReentrant whenNotPaused {
        // Check the maker ask order
        _verifyOrder(order);

        // Execute the transaction
        _cancelOrder(order);
    }

    /**
     * @dev Cancel multiple orders
     * @param orders Orders to cancel
     */
    function cancelOrders(MSC20Order[] calldata orders) external override nonReentrant whenNotPaused {
        for (uint256 i = 0; i < orders.length; i++) {
            _verifyOrder(orders[i]);
            _cancelOrder(orders[i]);
        }
    }

    /**
     * @notice Verify the validity of the MSC20 token order
     * @param order maker MSC20 token order
     */
    function _verifyOrder(MSC20Order calldata order) internal view {
        if (cancelled[order.listHash]) {
            revert IMSC20Market__Cancelled();
        }

        // Verify the signer is not address(0)
        if (order.seller == address(0)) {
            revert IMSC20Market__SignerInvalid();
        }
        // Verify the validity of the signature
        bytes32 orderHash = order.hash();
        bool isValid = _verify(orderHash, order.seller, order.signature);

        if (!isValid) {
            revert IMSC20Market__SignatureInvalid();
        }
    }

    function _executeOrder(MSC20Order calldata order, address recipient, uint256 userBalance) internal {
        if (order.price != userBalance) {
            revert IMSC20Market__MsgValueInvalid();
        }

        // Verify the recipient is not address(0)
        require(recipient != address(0), "invalid recipient");

        // Update order status to true (prevents replay)
        cancelled[order.listHash] = true;

        // Pay eths
        _transferEths(order);

        emit scriptions_protocol_TransferMSC20TokenForListing(order.seller, recipient, order.listHash);

        emit MSC20OrderExecuted(
            order.seller, recipient, order.listHash, order.tick, order.amount, order.price, order.creatorFeeRate
        );
    }

    function _cancelOrder(MSC20Order calldata order) internal {
        // Update order status to true (prevents replay)
        cancelled[order.listHash] = true;

        emit scriptions_protocol_TransferMSC20TokenForListing(order.seller, order.seller, order.listHash);

        emit MSC20OrderCanceled(order.seller, order.listHash);
    }

    function _transferEths(MSC20Order calldata order) internal {
        uint256 finalSellerAmount = order.price;

        // Pay protocol fee
        if (order.creatorFeeRate > 0) {
            uint256 protocolFeeAmount = finalSellerAmount * order.creatorFeeRate / 10000;
            finalSellerAmount -= protocolFeeAmount;
            _transferETHWithGasLimit(payable(this), protocolFeeAmount);
        }

        _transferETHWithGasLimit(payable(order.seller), finalSellerAmount);
    }

    /**
     * @notice It transfers ETH to a recipient with a specified send method 2300 gas limit.
     */
    function _transferETHWithGasLimit(address payable to, uint256 amount) internal {
        bool success = to.send(amount);
        if (!success) {
            revert IMSC20Market__ETHTransferFailed();
        }
    }

    function _verify(bytes32 orderHash, address signer, bytes memory signature) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), orderHash));
        return digest.recover(signature) == signer;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success,) = to.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function withdrawUnexpectedERC20(address token, address to, uint256 amount) external onlyOwner {
        ERC20Upgradeable(token).transfer(to, amount);
    }

    function pause() external onlyOwner {
        PausableUpgradeable._pause();
    }

    function unpause() external onlyOwner {
        PausableUpgradeable._unpause();
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function isCancelOrder(bytes32 listHash) external view returns (bool) {
        return cancelled[listHash];
    }
}
