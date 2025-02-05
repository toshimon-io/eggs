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
        eggs = new EGGS{value: 0.01 ether}();
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
            eggs.SONICtoEGGSNoTrade(borrowedRemove);
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
            eggs.SONICtoEGGSNoTrade(borrowedRemove);
        eggs.removeCollateral(removeAmount);

        eggs.flashClosePosition();

        vm.stopPrank();
    }
    function testBorrowFxnsLeverage(uint256 seed) public {
        vm.deal(address(0xBEEF), 1e18);
        eggs.buy{value: 1e18}(address(0xBEF2));
        uint256 x;
        for (uint16 i; i < 10000; i++) {
            vm.startPrank(address(0xBEEF));
            uint256 k = getRandomNumber(seed / (i + x + 2));

            while (k > 10) {
                k = k - 1;
            }
            if (k == x) x = x + 1;
            else x = k;
            console.log("test", x);
            console.log("test", i);
            uint256 eggsBall = eggs.balanceOf(address(0xBEEF));
            (uint256 collateral, uint256 borrowed, uint256 endDate) = eggs
                .getLoanByAddress(address(0xBEEF));
            console.log("Test", x);
            if (x == 0) {
                vm.deal(address(0xBEEF), 1e18);
                eggs.buy{value: 1e18}(address(0xBEEF));
            }
            if (x == 1) {
                uint256 maxSell = eggs.balanceOf(address(0xBEEF));

                if (maxSell > 1e18) {
                    //console.log(maxSell);
                    eggs.sell(maxSell);
                }
            }
            if (x == 2) {
                if (borrowed == 0) {
                    if (eggsBall < 100000000) {
                        vm.deal(address(0xBEEF), 1e18);

                        eggs.buy{value: 1e18}(address(0xBEEF));
                        eggsBall = eggs.balanceOf(address(0xBEEF));
                    }
                    //console.log(eggsBall);
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);

                    //console.log(maxBorrowAmount);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    uint256 conv = eggs.SONICtoEGGSNoTrade(borrowed);
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
                    vm.deal(address(0xBEEF), 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);
                } else {
                    uint256 extendFee = eggs.getInterestFee(borrowed, 5);
                    vm.deal(address(0xBEEF), extendFee);
                    if ((endDate + 5 days - block.timestamp) / 1 days < 365)
                        eggs.extendLoan{value: extendFee}(5);
                }
            }
            if (x == 4) {
                if (borrowed == 0) {
                    /* vm.deal(address(0xBEEF), 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(address(0xBEEF), borrowed / 2);
                    if (borrowed / 2 > 1e10) {
                        eggs.repay{value: borrowed / 2}();
                    }
                }
            }
            if (x == 5) {
                if (borrowed == 0) {
                    /* if (eggsBall < 100000000) {
                        vm.deal(address(0xBEEF), 1e18);

                        eggs.buy{value: 1e18}(address(0xBEEF));
                        eggsBall = eggs.balanceOf(address(0xBEEF));
                    }
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);
                    eggs.borrow(maxBorrowAmount, 0);*/
                } else {
                    uint256 colatInSonic = (eggs.EGGStoSONIC(collateral) * 99) /
                        100;
                    if (colatInSonic > borrowed) {
                        uint256 removeAmount = eggs.SONICtoEGGSNoTradeFloor(
                            ((eggs.EGGStoSONICceil(collateral) * 99) / 100) -
                                borrowed
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
                        vm.deal(address(0xBEEF), 1e18);

                        eggs.buy{value: 1e18}(address(0xBEEF));
                        eggsBall = eggs.balanceOf(address(0xBEEF));
                    }
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    (uint256 collateral, uint256 borrowed, ) = eggs
                        .getLoanByAddress(address(0xBEEF));
                    //console.log(collateral);
                    //console.log(borrowed);
                    //  uint256 collateralInS = eggs.EGGStoSONIC(collateral);
                    //  uint256 borrowedInEggs = eggs.SONICtoEGGSNoTrade(borrowed);
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
                    /* vm.deal(address(0xBEEF), 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(address(0xBEEF), borrowed);
                    eggs.closePosition{value: borrowed}();
                }
            }
            if (x == 8) {
                if (borrowed == 0) {
                    /*vm.deal(address(0xBEEF), 1e18);

                    uint256 fee = eggs.leverageFee(1 ether, 0);
                    eggs.leverage{value: fee + (1 ether / 100)}(1 ether, 0);*/
                } else {
                    vm.deal(address(0xBEEF), borrowed);
                    eggs.closePosition{value: borrowed}();
                }
            }
            if (x == 9) {
                if (borrowed == 0) {
                    if (eggsBall < 1e18) {
                        vm.deal(address(0xBEEF), 1e18);

                        eggs.buy{value: 1e18}(address(0xBEEF));
                        eggsBall = eggs.balanceOf(address(0xBEEF));
                    }
                    //console.log(eggsBall);
                    uint256 maxBorrowAmount = eggs.EGGStoSONIC(eggsBall);
                    //console.log(maxBorrowAmount);
                    eggs.borrow(maxBorrowAmount, 0);
                } else {
                    uint256 conv = eggs.EGGStoSONIC(collateral);
                    uint256 colatMax = ((conv) * 99) / 100;
                    //console.log(eggsBall);
                    //console.log(colatMax);
                    //console.log(borrowed);

                    uint256 borrowMoreAmount = 0;
                    if (borrowed < colatMax)
                        borrowMoreAmount = colatMax - borrowed;

                    uint256 bal = eggs.EGGStoSONIC(
                        eggs.balanceOf(address(0xBEEF))
                    );

                    if (borrowMoreAmount > 1e18) {
                        eggs.borrowMore(borrowMoreAmount + bal);
                    }
                }
            }
            if (x == 1) {
                vm.warp(block.timestamp + 7 days);
            }
            vm.stopPrank();
        }
    }
}
