// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract HBank is Ownable {
    // mapping (address => bool) assetIsSupported;
    // mapping (address => uint) suppliedAmount;
    // mapping (address => uint) borrowedAmount;

    mapping (address => uint[]) userToSuppliedAmounts;
    mapping (address => uint[]) userToBorrowedAmounts;
    // mapping (address => uint) assetToIndex;
    // mapping (address => address) assetToPriceFeed;

    struct Asset {
        address token;
        uint id;
        address priceFeed;
        uint supplied;
        uint borrowed;
    }

    mapping (uint => Asset) assetIdToAsset;

    uint assetCounter;

    constructor() {
        addAsset([]);
    }

//     modifier isWhitelisted(address asset) {
//       require(assetIsSupported[asset]);
//       _;
//    }

    function supply(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        IERC20(asset_data.token).transferFrom(msg.sender, address(this), amount);
        userToSuppliedAmounts[msg.sender][assetId] += amount;
        asset_data.supplied += amount;
    }

    function withdraw(uint assetId, uint amount) external {
        uint max_borrow = (getUserSuppliedUSD(msg.sender) - getUserBorrowedUSD(msg.sender)) * 80 /100;
        require(amount <= max_borrow, "already borrewed max");
        Asset storage asset_data = assetIdToAsset[assetId];
        IERC20(asset_data.token).transferFrom(address(this), msg.sender, amount);
        userToSuppliedAmounts[msg.sender][assetId] -= amount; // revert if < 0
        asset_data.supplied -= amount;
    }

    function borrow(uint assetId, uint amount) external {
        uint max_borrow = (getUserSuppliedUSD(msg.sender) - getUserBorrowedUSD(msg.sender)) * 80 /100;
        require(amount <= max_borrow, "already borrowed max");
        Asset storage asset_data = assetIdToAsset[assetId];
        IERC20(asset_data.token).transferFrom(address(this), msg.sender, amount);
        userToBorrowedAmounts[msg.sender][assetId] += amount;
        asset_data.supplied += amount;
    }

    function repay(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        IERC20(asset_data.token).transferFrom(msg.sender, address(this), amount);
        userToBorrowedAmounts[msg.sender][assetId] -= amount;
        asset_data.supplied -= amount; 
    }

    function getUserSuppliedUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += userToSuppliedAmounts[user][i] * asset_price;
        }
    }

    function getUserBorrowedUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += userToBorrowedAmounts[user][i] * asset_price;
        }
    }

    function getSuppliedUSD() public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += asset_data.supplied * asset_price;
        }
    }

    function getBorrowedUSD() public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += asset_data.borrowed * asset_price;
        }
    }

    function getLatestPrice(address priceFeed) internal view returns (uint) {
        (,int price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        return uint(price / 1e8);
    }

    function addAsset(address token, address priceFeed) public onlyOwner {
        // assetIsSupported[asset] = true;
        Asset memory asset_data;
        asset_data.id = assetCounter;
        asset_data.token = token;
        asset_data.priceFeed = priceFeed;
        assetIdToAsset[assetCounter] = asset_data;
        // assetToIndex[asset] = assetCounter;
        // indexToAsset[assetCounter] = asset;
        // assetToPriceFeed[asset] = priceFeed;
        assetCounter += 1;
    }
}
