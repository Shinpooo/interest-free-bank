// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract HBank is Ownable {
    mapping (address => bool) assetIsSupported;
    // mapping (address => uint) suppliedAmount;
    // mapping (address => uint) borrowedAmount;

    mapping (address => uint[]) userToSuppliedAmounts;
    mapping (address => uint[]) userToBorrowedAmounts;
    mapping (address => uint) assetToIndex;

    uint assetCounter;

    constructor() {}

    modifier isWhitelisted(address asset) {
      require(assetIsSupported[asset]);
      _;
   }

    function supply(address asset, uint amount) external isWhitelisted(asset) {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        userToSuppliedAmounts[msg.sender][assetToIndex[asset]] += amount;
    }

    function withraw(address asset, uint amount) external isWhitelisted(asset) {
        IERC20(asset).transferFrom(address(this), msg.sender, amount);
        userToSuppliedAmounts[msg.sender][assetToIndex[asset]] -= amount; // revert if < 0
    }
    }

    function borrow(address asset, uint amount) external isWhitelisted(asset) {
        
    }

    function repay(address asset, uint amount) external isWhitelisted(asset) {
        
    }

    function getSuppliedUSD(address user) external view returns (uint USDamount) {
        for (i=0; i<assetCounter; i++){
            USDamount += userToSuppliedAmounts[user][i] * assetPrice;
        }
    }

    function whiteListAsset(address asset) public onlyOwner {
        assetIsSupported[asset] = true;
        assetToIndex[asset] = assetCounter;
        assetCounter += 1;
    }
}
