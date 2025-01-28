// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EGGS} from "../src/Eggs.sol";

contract CounterScript is Script {
    EGGS public eggs;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        eggs = new EGGS{value: 0.01 ether}();
        eggs.setFeeAddress(0x38818e389773445Cd73aDBAA37B8B169F458c6e1);
        eggs.setStart();

        uint256 eggtotal = 1000 * 10 ** 18;

        /* vm.prank(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        address addy = eggs.leverage{value: val}(eggtotal, 1);

        uint256 ETHC = 10 * 10 ** 18;
        (uint256 collateral, uint256 borrowed, uint256 collateralcov) = eggs
            .getLoanByAddress(addy);

        uint256 val2 = eggs.leverageFeePlusReserve(eggtotal * 1000000, 1);

        address addy2 = eggs.leverage{value: val2}(eggtotal, 1);
        console.log(addy2);
        (uint256 collateral2, uint256 borrowed2, uint256 collateralcov2) = eggs
            .getLoanByAddress(addy);

        vm.prank(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        uint256 amount = eggs.flashClosePosition();*/
        vm.stopBroadcast();
    }
}
