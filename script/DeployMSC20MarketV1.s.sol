// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MSC20MarketV1} from "../src/MSC20MarketV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMSC20MarketV1 is Script {
    function run() external returns (MSC20MarketV1, uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 deployerKey) = helperConfig.activeNetworkConfig();
        vm.startBroadcast(deployerKey);
        MSC20MarketV1 msc20MarketV1 = new MSC20MarketV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(msc20MarketV1), "");
        address payable proxyAddress = payable(address(proxy));

        MSC20MarketV1(proxyAddress).initialize();
        vm.stopBroadcast();
        return (MSC20MarketV1(proxyAddress), deployerKey);
    }
}
