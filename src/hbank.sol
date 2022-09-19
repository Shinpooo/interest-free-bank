// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract HBank is Ownable {

    uint public assetCounter;
    mapping (address => mapping(uint => uint)) public userToSuppliedAmounts;
    mapping (address => mapping(uint => uint)) public userToBorrowedAmounts;


    struct Asset {
        address token;
        uint id;
        address priceFeed;
        uint supplied;
        uint borrowed;
        uint LTV;
        uint liquiditationThreshold;
        uint liquidationPenalty;
    }

    mapping (uint => Asset) public assetIdToAsset;


    constructor() {
    }

    function supply(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        IERC20(asset_data.token).transferFrom(msg.sender, address(this), amount);
        userToSuppliedAmounts[msg.sender][assetId] += amount;
        asset_data.supplied += amount;
    }

    function withdraw(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        uint max_withdraw_usd =  getUserSuppliedUSD(msg.sender) - getUserBorrowedUSD(msg.sender) * 100 /  asset_data.LTV;
        uint max_withdraw_tokens = (max_withdraw_usd ) / getLatestPrice(asset_data.priceFeed);
        require(amount <= max_withdraw_tokens, "LTV withdraw limit.");
        IERC20(asset_data.token).transfer(msg.sender, amount);
        userToSuppliedAmounts[msg.sender][assetId] -= amount; // revert if < 0
        asset_data.supplied -= amount;
    }

    function borrow(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        uint max_borrow_usd = getUserBorrowableUSD(msg.sender);
        uint max_borrow_tokens = max_borrow_usd / getLatestPrice(asset_data.priceFeed);
        require(amount <= max_borrow_tokens, "LTV borrow limit.");  
        IERC20(asset_data.token).transfer(msg.sender, amount);
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
        // USDamount /= 1e18;
    }

    function getUserBorrowableUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += userToSuppliedAmounts[user][i] * asset_price * asset_data.LTV / 100;
        }
        USDamount -= getUserBorrowedUSD(user);
        // USDamount /= 1e18;
    }

    function getUserBorrowedUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += userToBorrowedAmounts[user][i] * asset_price;
        }
        // USDamount /= 1e18;
    }

    function getSuppliedUSD() public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += asset_data.supplied * asset_price;
        }
        // USDamount /= 1e18;
    }

    function getBorrowedUSD() public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += asset_data.borrowed * asset_price;
        }
        // USDamount /= 1e18;
    }

    function getLatestPrice(address priceFeed) internal view returns (uint) {
        (,int price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        return uint(price / 1e8);
    }


    function getUserLiquidationThreshold(address user) public view returns (uint liquidationThreshold) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            liquidationThreshold += userToSuppliedAmounts[user][i] * asset_price * asset_data.LTV / 100;
        }
        liquidationThreshold /= getUserSuppliedUSD(user);
    }

    function getUserLTV(address user) public view returns (uint LTV) {
        uint loan;
        uint value;
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            value += userToSuppliedAmounts[user][i] * asset_price;
            loan += userToBorrowedAmounts[user][i] * asset_price;
        }
        LTV = loan / value;
    }

    function isUnderWater(address user) internal view returns (bool) {
        return getUserLTV(user) >= getUserLiquidationThreshold(user);
    }

    function liquidate(address user, uint collateral_asset_id, uint debt_asset_id, uint debt_amount) external {
        require(isUnderWater(user), "user is not under water.");
        Asset memory collateral_asset = assetIdToAsset[collateral_asset_id];
        Asset memory debt_asset = assetIdToAsset[debt_asset_id];
        require(debt_amount <= userToBorrowedAmounts[user][debt_asset_id]/ 2, "max repay 50% of a debt asset.");
        uint debt_usd_value = debt_amount* getLatestPrice(debt_asset.priceFeed);
        uint collateral_amount = debt_usd_value / getLatestPrice(collateral_asset.priceFeed);
        uint penalty_amount = collateral_amount * collateral_asset.liquidationPenalty / 100;
        IERC20(debt_asset.token).transferFrom(address(this), msg.sender, debt_amount);
        IERC20(collateral_asset.token).transferFrom(msg.sender, address(this), collateral_amount - penalty_amount);
        userToBorrowedAmounts[user][debt_asset_id] -= debt_amount;
        userToSuppliedAmounts[user][collateral_amount] += collateral_amount - penalty_amount;
        collateral_asset.borrowed -= debt_amount;
        collateral_asset.supplied += collateral_amount - penalty_amount; 
    }

    function addAsset(address token, address priceFeed, uint ltv, uint liquidation_treshold, uint liquidation_penalty) public onlyOwner {
        Asset memory asset_data;
        asset_data.id = assetCounter;
        asset_data.token = token;
        asset_data.priceFeed = priceFeed;
        asset_data.LTV = ltv;
        asset_data.liquiditationThreshold = liquidation_treshold;
        asset_data.liquidationPenalty = liquidation_penalty;
        assetIdToAsset[assetCounter] = asset_data;
        assetCounter += 1;
    }
}
