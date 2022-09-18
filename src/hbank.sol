// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HBank {
    mapping (address => bool) assetIsSupported;
    mapping (address => uint) suppliedAmount;
    mapping (address => uint) borrowedAmount;

    constructor() {}

    modifier isWhitelisted(address asset) {
      require(assetIsSupported[asset]);
      _;
   }

    function supply(address asset, uint amount) external isWhitelisted(asset) {

    }

    function withraw(address asset, uint amount) external isWhitelisted(asset) {
        
    }

    function borrow(address asset, uint amount) external isWhitelisted(asset) {
        
    }

    function repay(address asset, uint amount) external isWhitelisted(asset) {
        
    }
}
