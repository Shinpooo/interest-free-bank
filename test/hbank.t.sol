// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/hbank.sol";
import "./mocks/MockV3Aggregator.sol";
import "./mocks/MockToken.sol";
import {console} from "forge-std/console.sol";


contract HBankTest is Test {
    
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ANSWER = 1 * 10**18;

    MockV3Aggregator public ethAggregator;
    MockV3Aggregator public btcAggregator;
    MockV3Aggregator public usdcAggregator;

    MockToken public eth;
    MockToken public btc;
    MockToken public usdc;

    address Alice = address(1);

    HBank public bank;


    function setUp() public {
        ethAggregator = new MockV3Aggregator(DECIMALS, 1000 * 10**8);
        btcAggregator = new MockV3Aggregator(DECIMALS, 20000 * 10**8);
        usdcAggregator = new MockV3Aggregator(DECIMALS, 1 * 10**8);
        eth = new MockToken("wETH","Wrapped Ether", Alice, 10 * 10**18);
        btc = new MockToken("wBTC","Wrapped Bitcoin", Alice, 1 * 10**18);
        usdc = new MockToken("USDC","USD COIN", Alice, 10 * 10**18);
        bank = new HBank();
        bank.addAsset(address(eth), address(ethAggregator), 70, 80, 10);
        bank.addAsset(address(btc), address(btcAggregator), 70, 80, 10);
        bank.addAsset(address(usdc), address(usdcAggregator), 70, 80, 10);
    }

    function testAssets() public {
        (address a,,,,,,,) = bank.assetIdToAsset(2);
        console.log(ERC20(a).name());
        // (address a,uint b,address c,uint d,uint e,uint f,uint g, uint h) = bank.assetIdToAsset(1);
        // (address a,uint b,address c,uint d,uint e,uint f,uint g, uint h) = bank.assetIdToAsset(2);
        
    }
    function testSupplyWithdraw() public {
        uint assetId = 0;
        uint amount = 10 * 10**18;
        // vm.assume(assetId < bank.assetCounter());
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        // vm.assume(amount <= IERC20(assetAddress).balanceOf(Alice));
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), amount);
        bank.supply(assetId, amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        bank.withdraw(assetId, amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 0);
        vm.stopPrank();
    }

    function testSupplyWithdrawFuzz(uint assetId, uint amount) public {
        vm.assume(assetId < bank.assetCounter());
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        vm.assume(amount <= IERC20(assetAddress).balanceOf(Alice));
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), amount);
        bank.supply(assetId, amount);
        bank.withdraw(assetId, amount);
        vm.stopPrank();
    }


    function testSupplyBorrow() public {
        uint assetId = 0;
        uint supplied_amount = 10 * 10**18;
        uint borrowed_amount = 5 * 10**18;
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), supplied_amount);
        bank.supply(assetId, supplied_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 7 * 1000 * 10**18);
        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 5 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 2 * 1000 * 10**18);
        vm.stopPrank();
    }

    function testSupplyBorrowFuzz(uint assetId, uint supplied_amout, uint borrowed_amount) public {
        uint assetId = 0;
        uint supplied_amount = 10 * 10**18;
        uint borrowed_amount = 5 * 10**18;
        vm.assume(assetId < bank.assetCounter());
        (address assetAddress,,,,,uint ltv,,) = bank.assetIdToAsset(assetId);
        vm.assume(borrowed_amount < ltv * supplied_amount / 100);
        vm.assume(supplied_amount <= IERC20(assetAddress).balanceOf(Alice));
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), supplied_amount);
        bank.supply(assetId, supplied_amount);
        bank.borrow(assetId, borrowed_amount);
        assertEq(IERC20(assetAddress).balanceOf(Alice), borrowed_amount);
        vm.stopPrank();
    }

    function testSupplyBorrowBorrow() public {
        uint assetId = 0;
        uint supplied_amount = 10 * 10**18;
        uint borrowed_amount = 5 * 10**18;
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), supplied_amount);
        bank.supply(assetId, supplied_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 7 * 1000 * 10**18);

        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 5 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 2 * 1000 * 10**18);

        borrowed_amount = 3 * 10**18;
        vm.expectRevert('LTV borrow limit.');
        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 5 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 2 * 1000 * 10**18);

        borrowed_amount = 2 * 10**18;
        // vm.expectRevert('LTV borrow limit.');
        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 7 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 0 * 1000 * 10**18);

        borrowed_amount = 1;
        vm.expectRevert('LTV borrow limit.');
        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 7 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 0 * 1000 * 10**18);


        vm.stopPrank();
    }

    function testSupplyBorrowRepay() public {
        uint assetId = 0;
        uint supplied_amount = 10 * 10**18;
        uint borrowed_amount = 5 * 10**18;
        uint repay_amount = 3 * 10**18;
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), supplied_amount);
        bank.supply(assetId, supplied_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 7 * 1000 * 10**18);

        bank.borrow(assetId, borrowed_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 5 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 2 * 1000 * 10**18);

        IERC20(assetAddress).approve(address(bank), repay_amount);
        bank.repay(assetId, repay_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 2 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 5 * 1000 * 10**18);

        IERC20(assetAddress).approve(address(bank), repay_amount);
        vm.expectRevert("Can't repay more");
        bank.repay(assetId, repay_amount);
        assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        assertEq(bank.getUserBorrowedUSD(Alice), 2 * 1000 * 10**18);
        assertEq(bank.getUserBorrowableUSD(Alice), 5 * 1000 * 10**18);

        // borrowed_amount = 1;
        // vm.expectRevert('LTV borrow limit.');
        // bank.borrow(assetId, borrowed_amount);
        // assertEq(bank.getUserSuppliedUSD(Alice), 10 * 1000 * 10**18);
        // assertEq(bank.getUserBorrowedUSD(Alice), 7 * 1000 * 10**18);
        // assertEq(bank.getUserBorrowableUSD(Alice), 0 * 1000 * 10**18);


        vm.stopPrank();
    }

}