// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {EGGS} from "../src/eggs.sol";

contract EggsTest is Test {
    EGGS public eggs;

    function setUp() public {
        counter = new eggs({value: 10 * 10e18});
        counter.setStart();
        counter.setFeeAddress(msg.sender);
    }

    function test_Increment() public {
        counter.buy{value: 10 * 10e18}(msg.sender);
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
