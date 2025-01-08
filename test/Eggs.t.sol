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
        eggs = new EGGS{value: 1000 * 10e18}();
        eggs.setStart();
        eggs.setFeeAddress(msg.sender);
        console.log(address(eggs));
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
