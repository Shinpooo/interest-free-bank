// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/hbank.sol";
import "./mocks/MockV3Aggregator.sol";
import "./mocks/MockToken.sol";
import {console} from "forge-std/console.sol";


contract HBankTest is Test {
    
    uint8 public constant DECIMALS = 18;
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
        btcAggregator = new MockV3Aggregator(DECIMALS, 20000 * 10**18);
        usdcAggregator = new MockV3Aggregator(DECIMALS, 1 * 10**18);
        eth = new MockToken("wETH","Wrapped Ether", Alice, 10 * 10**18);
        btc = new MockToken("wBTC","Wrapped Bitcoin", Alice, 1 * 10**18);
        usdc = new MockToken("USDC","USD COIN", Alice, 10 * 10**18);
        bank = new HBank();
        bank.addAsset(address(eth), address(ethAggregator), 70, 80, 10);
        bank.addAsset(address(btc), address(btcAggregator), 70, 80, 10);
        bank.addAsset(address(usdc), address(usdcAggregator), 70, 80, 10);
    }

    function testAssets() public {
        (address a,uint b,address c,uint d,uint e,uint f,uint g, uint h) = bank.assetIdToAsset(2);
        console.log(ERC20(a).name());
        // (address a,uint b,address c,uint d,uint e,uint f,uint g, uint h) = bank.assetIdToAsset(1);
        // (address a,uint b,address c,uint d,uint e,uint f,uint g, uint h) = bank.assetIdToAsset(2);
        
    }
    function testSupply() public {
        uint assetId = 0;
        uint amount = 10 * 10**18;
        vm.assume(assetId < bank.assetCounter());
        (address assetAddress,,,,,,,) = bank.assetIdToAsset(assetId);
        vm.assume(amount <= IERC20(assetAddress).balanceOf(Alice));
        vm.startPrank(Alice);
        IERC20(assetAddress).approve(address(bank), amount);
        bank.supply(assetId, amount);

        console.log(ERC20(assetAddress).name());
        console.log(amount);
        uint usd = bank.getSuppliedUSD();
        console.log(usd);
    }

    // function testCreateRaffle() public {
    //     uint raffle1_price = 1000 * 10**18;
    //     uint raffle2_price = 1000 * 10**18;


    //     // Random dude mint a knife and deposit it in the staking contract
    //     vm.startPrank(RandomDude);
    //     knife.mint(1);
    //     knife.setApprovalForAll(address(stakedKnife), true);
    //     uint256[] memory tokenIds = knife.tokenIdsOfUser(RandomDude);
    //     stakedKnife.depositSelected(tokenIds);
    //     // wait 1 day for the knife to earn some SUPPLY tokens
    //     vm.warp(block.timestamp + 20 weeks);
    //     // Claim them
    //     stakedKnife.claim(RandomDude, tokenIds[0]);
    //     vm.stopPrank();


    //     // Create raffle as owner()
    //     raffleTicket.createRaffle("Project1", "test1.png", "Whitelist", raffle1_price, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);

    //     vm.prank(Ororys);
    //     // create raffle as admin
    //     raffleTicket.createRaffle("Project2", "test2.png", "Whitelist", raffle2_price, 10**16, 500, 5, 20, block.timestamp, block.timestamp + 100);
    //     vm.prank(RandomDude);
        

    //     // create raffle as random -> should fail
    //     vm.expectRevert(bytes("caller is not authorized"));
    //     raffleTicket.createRaffle("Project3", "test3", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);

    //     raffleTicket.createRaffle("Project4", "test4", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 3 weeks, block.timestamp + 4 weeks);

    //     raffleTicket.createRaffle("Project5", "test5", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 4 weeks, block.timestamp + 5 weeks);

    //     raffleTicket.createRaffle("Project6", "test6", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 5 weeks, block.timestamp - 4 weeks);

    //     raffleTicket.createRaffle("Project7", "test7", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 4 weeks, block.timestamp - 3 weeks);

    //     raffleTicket.createRaffle("Project8", "test8", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 4 weeks, block.timestamp + 3 weeks);

        

    //     // Check raffle open condition with respect to timestamp
    //     assertFalse(raffleTicket.isRaffleOpen(1));
    //     assertTrue(raffleTicket.isRaffleOpen(2));

    //     vm.warp(block.timestamp + 50);

    //     // Check raffle open condition with respect to timestamp
    //     assertTrue(raffleTicket.isRaffleOpen(1));
    //     assertTrue(raffleTicket.isRaffleOpen(2));

    //     // Random dude buy its ticket with paying the AVAX fee + SUPPLY fee
    //     vm.startPrank(RandomDude);
    //     // check random dude has claimed 1000 tokens (THE CAP) after 5days and more
    //     assertEq(token.balanceOf(RandomDude), 1000 * 10**18);
    //     // Set random dude to 1 ether
    //     vm.deal(RandomDude, 1 ether);
    //     token.approve(address(raffleTicket), 1000 * 10**18);
    //     raffleTicket.safeMint{value: 10**16}(1, 1);
    //     // Mint should burn 1000 tokens from random dude
    //     assertEq(token.balanceOf(RandomDude), 0 * 10**18);
    //     // Mint should send 0.01 AVAX to the contract
    //     assertEq(RandomDude.balance, 1 ether - 10 ** 16);
    //     assertEq(address(raffleTicket).balance, 10 ** 16);

    //     vm.stopPrank();

    //     // Check raffle open condition with respect to timestamp
    //     vm.warp(block.timestamp + 60);
        
    //     assertFalse(raffleTicket.isRaffleOpen(1));
    //     assertFalse(raffleTicket.isRaffleOpen(2));


    //     // Displayed : 1 2 4 5 7 8
    //     // Closed : 1 2 6 7
    //     // open : 8
    //     // Coming : 4 5

    //     // Raffle[] memory displayed_raffles = raffleTicket.getDisplayedRaffleIds();
    //     // Raffle[] memory closed_raffles = raffleTicket.getClosedRaffleIds();
    //     // Raffle[] memory open_raffles = raffleTicket.getOpenRaffleIds();
    //     // Raffle[] memory coming_raffles = raffleTicket.getComingRaffleIds();
    //     // console.log(displayed_raffles.length);
    //     // console.log(closed_raffles.length);
    //     // console.log(open_raffles.length);
    //     // console.log(coming_raffles.length);
    //     // console.log(raffleTicket.getClosedRaffleIds());
    //     // console.log(raffleTicket.getOpenRaffleIds());
    //     // console.log(raffleTicket.getComingRaffleIds());

    //     // raffleTicket.requestRandomWords(1);
    // }
}