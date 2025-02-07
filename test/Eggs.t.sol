// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {EGGS} from "../src/eggs.sol";

contract EggsTest is Test {
    EGGS public eggs;
    uint16 public constant FEE_BASE_1000 = 1000;
    uint256 public constant MIN = 1000;
    uint256 public MAX = 1 * 10 ** 28;
    struct Loan {
        uint256 collateral; // shares of token staked
        uint256 borrowed; // user reward per token paid
        uint256 endDate;
    }
    function getRandomNumber(uint256 seed) public view returns (uint) {
        // Using block.timestamp and block.difficulty for randomness.
        // Note: This method isn't cryptographically secure but is simple for demonstration.
        uint randomNumber = (uint(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty, seed))
        ) % 10) + 1;
        return randomNumber;
    }
    function setUp() public {
        eggs = new EGGS{value: 10000 ether}();
        uint256 nal = address(eggs).balance;
        //console.log(nal);
        eggs.setFeeAddress(0xcE6ad0CA1C0a661c06098298B0e166a2b0DC38f7);

        eggs.setStart();
    }
    function testBorrowAndFlashClose() public {
        vm.deal(address(0xBEEF), 1e18);
        vm.startPrank(address(0xBEEF));

        eggs.buy{value: 1e18}(address(0xBEEF));

        uint256 maxBorrowAmount = eggs.EGGStoSONIC(
            eggs.balanceOf(address(0xBEEF))
        );
        eggs.borrow(maxBorrowAmount, 0);

        eggs.flashClosePosition();

        vm.stopPrank();
    }
    function testLeverageAndFlashClose() public {
        vm.deal(address(0xBEEF), 1e18);
        vm.startPrank(address(0xBEEF));
        uint256 fee = eggs.leverageFee(1 ether, 0);
        eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);

        eggs.flashClosePosition();

        vm.stopPrank();
    }
    function testBuySell() public {
        vm.deal(address(0xBEEF), 1e18);
        vm.startPrank(address(0xBEEF));
        eggs.buy{value: 1e18}(address(0xBEEF));

        uint256 maxSell = eggs.balanceOf(address(0xBEEF));
        eggs.sell(maxSell);

        vm.stopPrank();
    }
    function testBorrowFxnsLeverage() public {
        vm.deal(address(0xBEEF), 1e18);
        vm.startPrank(address(0xBEEF));

        eggs.buy{value: 1e18}(address(0xBEEF));

        uint256 maxBorrowAmount = eggs.EGGStoSONIC(
            eggs.balanceOf(address(0xBEEF))
        );
        eggs.borrow(maxBorrowAmount, 0);

        (, uint256 borrowed, ) = eggs.getLoanByAddress(address(0xBEEF));

        // extendLoan
        uint256 extendFee = eggs.getInterestFee(borrowed, 5);
        vm.deal(address(0xBEEF), extendFee);
        eggs.extendLoan{value: extendFee}(5);

        // partial repay
        vm.deal(address(0xBEEF), borrowed / 2);
        eggs.repay{value: borrowed / 2}();

        // borrowMore
        eggs.borrowMore(borrowed / 2);

        eggs.repay{value: borrowed / 4}();

        // remove
        (uint256 collateral, uint256 borrowedRemove, ) = eggs.getLoanByAddress(
            address(0xBEEF)
        );

        uint256 removeAmount = (collateral * 99) /
            100 -
            eggs.SONICtoEGGSNoTradeCeil(borrowedRemove);
        eggs.removeCollateral(removeAmount);

        eggs.flashClosePosition();

        vm.stopPrank();
    }
    function testBorrowFxns() public {
        vm.deal(address(0xBEEF), 1e18);
        vm.startPrank(address(0xBEEF));

        uint256 fee = eggs.leverageFee(1 ether, 0);
        eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);

        (, uint256 borrowed, ) = eggs.getLoanByAddress(address(0xBEEF));

        // extendLoan
        uint256 extendFee = eggs.getInterestFee(borrowed, 5);
        vm.deal(address(0xBEEF), extendFee);
        eggs.extendLoan{value: extendFee}(5);

        // partial repay
        vm.deal(address(0xBEEF), borrowed / 2);
        eggs.repay{value: borrowed / 2}();

        // borrowMore
        eggs.borrowMore(borrowed / 2);

        eggs.repay{value: borrowed / 4}();

        // remove
        (uint256 collateral, uint256 borrowedRemove, ) = eggs.getLoanByAddress(
            address(0xBEEF)
        );

        uint256 removeAmount = (collateral * 99) /
            100 -
            eggs.SONICtoEGGSNoTradeCeil(borrowedRemove);
        eggs.removeCollateral(removeAmount);

        eggs.flashClosePosition();

        vm.stopPrank();
    }
    uint128 private constant SONICinWEI = 1 * 10 ** 18;
    uint128 public constant maxSupply = 50 ** 11 * SONICinWEI;

    function testBorrowFxnsLeverage(uint256 seed) public {
        vm.deal(address(0xBEEF), 1e18);
        address[10] memory addresses = [
            address(0xBEF2),
            address(0xBEF1),
            address(0xBEF3),
            address(0xBEF4),
            address(0xBEF5),
            address(0xBEF6),
            address(0xBEF7),
            address(0xBEF8),
            address(0xBEF9),
            address(0xBEE3)
        ];
        eggs.buy{value: 1e18}(address(0xBEF2));
        uint256 x;
        for (uint256 i; i < 1000000; i++) {
            uint256 _seed;
            if (seed > i + x + 2) {
                _seed = seed - i;
            } else seed = seed + i;
            uint256 add = getRandomNumber(_seed);
            if (add > 9) add = 0;
            address addy = addresses[add];
            vm.startPrank(addy);
            vm.pauseGasMetering();

            uint256 k = getRandomNumber(_seed / 2 + i);

            while (k > 10) {
                k = k - 1;
            }
            if (k == x) x = x + 1;
            else x = k;
            console.log("addy", add);
            console.log("test Total", i);
            uint256 eggsBall = eggs.balanceOf(addy);
            uint256 remaining = maxSupply - eggs.totalMinted();
            (uint256 collateral, uint256 borrowed, uint256 endDate) = eggs
                .getLoanByAddress(addy);
            console.log("Test #", x);
            uint256 price = eggs.lastPrice();
            console.log("price", price);
            console.log("price", remaining);

            if (x == 0) {
                vm.deal(addy, 50000e18);
                eggs.buy{value: 50000e18}(addy);
            }
            if (x == 1) {
                uint256 maxSell = eggs.balanceOf(addy);

                if (maxSell > 1e18) {
                    //console.log(maxSell);
                    console.log("Sell");
                    eggs.sell(maxSell);
                    console.log("Sold");
                }
            }
            if (x == 2) {
                if (borrowed == 0) {
                    if (eggsBall < 1e18) {
                        vm.deal(addy, 50000e18);

                        eggs.buy{value: 50000e18}(addy);
                        eggsBall = eggs.balanceOf(addy);
                    }
                    //console.log(eggsBall);
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);

                    //console.log(maxBorrowAmount);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    uint256 conv = eggs.SONICtoEGGSNoTradeCeil(borrowed);
                    uint256 colatMax = ((collateral) * 99) / 100;
                    //console.log(conv);
                    //console.log(colatMax);
                    if (colatMax > conv) {
                        uint256 _borrowMoreAmount = colatMax - conv;
                        uint256 borrowMoreAmount = eggs.EGGStoSONIC(
                            _borrowMoreAmount
                        );
                        if (borrowMoreAmount > 1e18) {
                            eggs.borrowMore(borrowMoreAmount);
                        }
                    }
                }
            }
            if (x == 3) {
                if (borrowed == 0) {
                    vm.deal(addy, 50000e18);

                    uint256 fee = eggs.leverageFee(10000 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);
                } else {
                    uint256 extendFee = eggs.getInterestFee(borrowed, 5);
                    vm.deal(addy, extendFee);
                    if ((endDate + 5 days - block.timestamp) / 1 days < 365)
                        eggs.extendLoan{value: extendFee}(5);
                }
            }
            if (x == 4) {
                if (borrowed == 0) {
                    /* vm.deal(addy, 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(addy, borrowed / 2);
                    if (borrowed / 2 > 1e10) {
                        console.log("repay");
                        eggs.repay{value: borrowed / 2}();
                        console.log("repayaid");
                    }
                }
            }
            if (x == 5) {
                if (borrowed == 0) {
                    /* if (eggsBall < 100000000) {
                        vm.deal(addy, 1e18);

                        eggs.buy{value: 1e18}(addy);
                        eggsBall = eggs.balanceOf(addy);
                    }
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);
                    eggs.borrow(maxBorrowAmount, 0);*/
                } else {
                    uint256 colatInSonic = (eggs.EGGStoSONIC(collateral) * 99) /
                        100;
                    if (colatInSonic > borrowed) {
                        uint256 removeAmount = eggs.SONICtoEGGSNoTrade(
                            colatInSonic - borrowed
                        );
                        if (removeAmount > 10000000000) {
                            eggs.removeCollateral(removeAmount);
                        }
                    }
                }
            }
            if (x == 6) {
                if (borrowed == 0) {
                    if (eggsBall < 1e18) {
                        vm.deal(addy, 100e18);

                        eggs.buy{value: 100e18}(addy);
                        eggsBall = eggs.balanceOf(addy);
                    }
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    (uint256 collateral, uint256 borrowed, ) = eggs
                        .getLoanByAddress(addy);
                    //console.log(collateral);
                    //console.log(borrowed);
                    //  uint256 collateralInS = eggs.EGGStoSONIC(collateral);
                    //  uint256 borrowedInEggs = eggs.SONICtoEGGSNoTradeCeil(borrowed);
                    // uint256 collateralInSCeil = eggs.EGGStoSONICceil(
                    //      collateral
                    //    );
                    //console.log("c", (collateralInS * 99) / 100);
                    //console.log("cc", (collateralInSCeil * 99) / 100);

                    //console.log("bc", borrowed);
                    //console.log("b", borrowedInEggs);
                    //console.log("cb", (collateral * 99) / 100);
                    //console.log(i);

                    eggs.flashClosePosition();
                }
            }
            if (x == 7) {
                if (borrowed == 0) {
                    /* vm.deal(addy, 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(addy, borrowed);
                    eggs.closePosition{value: borrowed}();
                }
            }
            if (x == 8) {
                if (borrowed == 0) {
                    /*vm.deal(addy, 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(addy, borrowed);
                    uint256 bal = addy.balance;
                    console.log(borrowed);
                    console.log(bal);
                    console.log(collateral);
                    uint256 eggsAddy = eggs.balanceOf(address(eggs));
                    console.log(eggsAddy);
                    eggs.closePosition{value: borrowed}();
                }
            }
            if (x == 9) {
                if (borrowed == 0) {
                    if (eggsBall < 1e18) {
                        vm.deal(addy, 50000e18);

                        eggs.buy{value: 50000e18}(addy);
                        eggsBall = eggs.balanceOf(addy);
                    }
                    console.log("borrow");
                    //console.log(eggsBall);
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);

                    console.log("borrowCov");
                    console.log(maxBorrowAmount);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    uint256 conv = eggs.SONICtoEGGSNoTradeCeil(borrowed) +
                        ((eggs.balanceOf(addy) * 99) / 100);
                    uint256 colatMax = ((collateral) * 99) / 100;
                    //console.log(conv);
                    //console.log(colatMax);
                    if (colatMax > conv) {
                        uint256 _borrowMoreAmount = colatMax - conv;
                        uint256 borrowMoreAmount = eggs.EGGStoSONIC(
                            _borrowMoreAmount
                        );
                        if (borrowMoreAmount > 1e18) {
                            eggs.borrowMore(borrowMoreAmount);
                        }
                    }
                }
            }
            if (x == 10) {
                vm.warp(block.timestamp + 1 days);
            }
            uint256 breakIt = 9999998 - i;
            vm.stopPrank();
        }
    }
}
