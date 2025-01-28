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
        console.log(nal);
        eggs.setStart();
        eggs.setFeeAddress(msg.sender);

        eggs.buy{value: 0.01 ether}(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        nal = address(eggs).balance;
        console.log(nal);
    }
    function test_BorrowAndRepay() public {
        uint256 val = eggs.EGGStoSONIC(eggs.balanceOf(msg.sender)); // -
        uint256 nal = address(eggs).balance;
        console.log(val);
        console.log(nal);
        eggs.borrow(val, 0);
        (uint256 cday1, uint day1) = eggs.getLoansExpiringByDate(
            block.timestamp
        );
        (
            uint256 collateral,
            uint256 borrowed,
            uint256 end,
            uint256 daysmount
        ) = eggs.Loans(msg.sender);
        assertEq(collateral, cday1);
        assertEq(borrowed, day1);

        eggs.flashClosePosition();

        (uint256 cday2, uint day2) = eggs.getLoansExpiringByDate(
            block.timestamp
        );
        assertEq(cday2, 0);
        assertEq(day2, 0);

        /*eggs.buy{value: 7780962683658298567970046477}(msg.sender);
        assertEq(eggs.totalSupply(), 190000000000000000000000);*/
    }

    function test_Increment() public {
        /*eggs.buy{value: 7780962683658298567970046477}(msg.sender);
        assertEq(eggs.totalSupply(), 190000000000000000000000);*/
    }

    /*  function testFuzz_SetNumber(uint256 x) public {
        if (x > MIN && x < MAX) {
            uint256 total = eggs.getBuyAmount(x);
            eggs.buy{value: x}(0xF58764c35eD1528Ec78DF18BebB24Fa20f6A626F);
            assertEq(
                eggs.balanceOf(0xF58764c35eD1528Ec78DF18BebB24Fa20f6A626F),
                total
            );
        }
    }
    function testFuzz_Borrow(uint256 x) public {
        if (x > MIN && x < MAX) {
            uint256 total = eggs.getBuyAmount(x);
            eggs.buy{value: x}(0xF58764c35eD1528Ec78DF18BebB24Fa20f6A626F);
            assertEq(
                eggs.balanceOf(0xF58764c35eD1528Ec78DF18BebB24Fa20f6A626F),
                total
            );
        }
    }*/
}
