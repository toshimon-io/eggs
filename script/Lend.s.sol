// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EGGS} from "../src/Eggs.sol";

contract CounterScript is Script {
    function getRandomNumber(uint256 seed) public view returns (uint) {
        // Using block.timestamp and block.difficulty for randomness.
        // Note: This method isn't cryptographically secure but is simple for demonstration.
        uint randomNumber = (uint(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty, seed))
        ) % 10) + 1;
        return randomNumber;
    }

    EGGS public eggs =
        EGGS(payable(0x9A940EF65F8bF33332aA4fAEa921454828F0C80a));
    //0x5Eb9cC76c3506942c1c0Ead70e877dD5e4f00cb0

    function setUp() public {}
    uint256 blokc = block.number;
    function run() public {
        vm.startBroadcast();

        //uint256 eggtotal = 1 * 10 ** 17;
        (
            uint256 collateral2,
            uint256 borrowed2,
            uint256 collateralcov2,
            uint256 daysmount
        ) = eggs.Loans(msg.sender);

        //eggs.sell(eggs.balanceOf(msg.sender));
        uint256 bal = eggs.balanceOf(msg.sender);
        uint256 bal2 = eggs.balanceOf(
            0x8AAFD3ede9AdB0Ff97C7AEbCe82a919AFb1C8764
        );

        uint256 amt = eggs.getTotalCollateral();
        uint256 last = eggs.getTotalBorrowed();
        uint256 tim = eggs.getMidnightTimestamp(block.timestamp);
        (uint256 cday1, uint day1) = eggs.getLoansExpiringByDate(
            block.timestamp
        );
        (uint256 cday2, uint day2) = eggs.getLoansExpiringByDate(
            block.timestamp + 1 days
        );
        (uint256 cday3, uint day3) = eggs.getLoansExpiringByDate(
            block.timestamp + 2 days
        );
        (uint256 cday4, uint day4) = eggs.getLoansExpiringByDate(
            block.timestamp + 3 days
        );

        uint256 newcat = eggs.totalSupply();
        uint256 newBorrowed = eggs.getBacking() - borrowed2;
        uint256 priceAfterBomb = (newBorrowed * 1 ether) / newcat;

        console.log(borrowed2, collateral2);
        console.log(cday1, day1);
        console.log(cday2, day2);
        console.log(cday3, day3);
        console.log(cday4, day4);
        uint256 borrowed3 = eggs.SONICtoEGGSNoTrade(borrowed2);
        uint256 collateral3 = (eggs.EGGStoSONIC(collateral2) * 99) / 100;
        console.log(borrowed2);
        console.log(collateral3);

        //console.log((priceAfterBomb * 100) / amt2);
        //eggs.setFeeAddress(0x04fE38cbE12227a4AB51B78b6F801F1C4C7c3E58);
        if (bal > 10000) {
            // eggs.sell(eggs.balanceOf(msg.sender));
        }
        eggs.buy{value: 10000000000000000}(msg.sender);
        //}

        //eggs.setFeeAddress(msg.sender);

        /*
        uint256 ETHC = 10 * 10 ** 18;
        (uint256 collateral, uint256 borrowed, uint256 collateralcov) = eggs
            .getLoanByAddress(addy);

        uint256 val2 = eggs.leverageFeePlusReserve(eggtotal * 1000000, 1);

        address addy2 = eggs.leverage{value: val2}(eggtotal, 1);
        console.log(addy2);
        (uint256 collateral2, uint256 borrowed2, uint256 collateralcov2) = eggs
            .getLoanByAddress(addy);

        vm.prank(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        uint256 amount = eggs.flashClosePosition();
        vm.deal(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 1000000 ether);
        vm.stopBroadcast();
        vm.startBroadcast();
        */

        uint256 q = eggs.balanceOf(msg.sender);
        uint256 q2 = eggs.getTotalCollateral();

        uint256 _bal = collateral2;
        console.log(collateral2, q);
        uint256 conv = eggs.SONICtoEGGSNoTrade(borrowed2);
        uint256 val = eggs.EGGStoSONIC(q); // - borrowed2;

        uint256 vall = eggs.EGGStoSONIC(((collateral2) * 99) / 100 - conv);
        uint256 valll = eggs.SONICtoEGGSNoTrade(val);

        console.log(q);
        console.log(q2);
        console.log(vall);
        console.log(val);
        //eggs.borrow(val, 0);
        //eggs.borrowMore(vall + val);
        // eggs.flashClosePosition();
        //eggs.flashClosePosition();
        // uint256 tob = eggs.getTotalBorrowed();
        //console.log(tob);
        //eggs.flashClosePosition();

        /* uint256 _totalColateral = eggs.balanceOf(
            0x5FbDB2315678afecb367f032d93F642f64180aa3
        );

        uint256 _totalBorrowed = eggs.getTotalCollateral();
        console.log(_totalBorrowed);

        eggs.liquidate();
        //  eggs.leverage{value: val2}(eggsTotal, 0);

        /*
        uint256 userWalletBalance = address(msg.sender).balance;
        console.log(userWalletBalance);
        (uint256 collateral, uint256 borrowed, uint256 endDate) = eggs
            .getLoanByAddress(msg.sender);
        // eggs.closePosition{value: borrowed}();
        uint256 aaaa = eggs.EGGStoSONIC(collateral);

        uint256 _fee = eggs.getInterestFeeInEggs(borrowed, 1);
        // uint256 __fee = eggs.extendLoan{value: _fee}(1);
        console.log(_fee);
        //  console.log(__fee);
        uint256 rng1 = getRandomNumber(block.timestamp);

        if (rng1 == 3) {
            if (borrowed > 0) eggs.flashClosePosition();
            if (getRandomNumber(rng1) == 3) {
                uint256 val = eggs.leverageFee(eggtotal * 10000, 0);
                (uint256 v5, uint256 v6, uint256 v7) = eggs.leverage{value: val}(
                    eggtotal * 100,
                    0
                );
            }
        }
        uint256 emm = eggs.lastLiquidationDate();
        uint256 emm2 = eggs.lastLiquidationDate() - block.timestamp;
        console.log(emm, endDate, emm2);

         uint256 val = eggs.leverageFee(eggtotal * 100, 0);
        console.log(val);

        //uint256 v4 = eggs.EGGStoSONIC(eggtotal * 100);

        //console.log(v4);

        (uint256 v5, uint256 v6, uint256 v7) = eggs.leverage{value: val}(
            eggtotal * 100,
            0
        );
        console.log(v5);
        console.log(v6);
        console.log(v7);*/
        /*
        uint256 balEggs = eggs.balanceOf(msg.sender);

        uint256 balSonic = eggs.EGGStoSONIC(balEggs);

        uint256 fees = eggs.getInterestFeeInEggs(balSonic, 0);

        uint256 total = (balSonic * 99) / 100 - fees;
        console.log(total);
        console.log(balSonic);
        userWalletBalance = address(msg.sender).balance;
        console.log(total + userWalletBalance);
        uint256 rng2 = getRandomNumber(rng1);
        if (borrowed == 0 && balEggs > 0 && rng2 == 6) eggs.borrow(balSonic, 0);

        (collateral, borrowed, endDate) = eggs.getLoanByAddress(msg.sender);
        uint256 colinegg = eggs.EGGStoSONIC(collateral);
        uint256 cc = (colinegg * 99) / 100;
        console.log(borrowed, colinegg, cc);

        userWalletBalance = address(msg.sender).balance;
        console.log(userWalletBalance);
        balEggs = eggs.balanceOf(msg.sender);
        console.log(balEggs);
        console.log("---");
        uint256 totalb = eggs.balanceOf(
            0x5FbDB2315678afecb367f032d93F642f64180aa3
        );

        uint256 totalc = eggs.getTotalCollateral();
        console.log(totalb);
        console.log(totalc);
        bool hey2 = totalb >= totalc;
        console.log(totalb, totalc);
        console.log(hey2);
        require(hey2, "dude");*/

        vm.stopBroadcast();
    }
}
//while sleep 5; do forge script script/Eggs.s.sol -vvvv  --rpc-url 127.0.0.1:8545 --broadcast --sender 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 --private-key 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356; done;
