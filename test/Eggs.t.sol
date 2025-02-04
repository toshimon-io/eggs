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
}
