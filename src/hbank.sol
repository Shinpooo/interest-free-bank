// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


// TODO write events
// TODO Find a way to mitigate liquidity risk (interest rate model not allowed)
// Solution 1: If the largest depositor of 1 asset can't withdraw all his supplied amount => do not allow borrow


contract HBank is Ownable {
    using SafeERC20 for IERC20;
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

    

    function supply(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        userToSuppliedAmounts[msg.sender][assetId] += amount;
        asset_data.supplied += amount;
        IERC20(asset_data.token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        uint max_withdraw_usd =  getUserSuppliedUSD(msg.sender) - getUserBorrowedUSD(msg.sender) * 100 /  asset_data.LTV;
        uint max_withdraw_tokens = (max_withdraw_usd ) / getLatestPrice(asset_data.priceFeed);
        require(amount <= max_withdraw_tokens, "LTV withdraw limit.");
        userToSuppliedAmounts[msg.sender][assetId] -= amount; // revert if < 0
        asset_data.supplied -= amount;
        IERC20(asset_data.token).safeTransfer(msg.sender, amount);
    }

    function borrow(uint assetId, uint amount) external {
        Asset storage asset_data = assetIdToAsset[assetId];
        uint max_borrow_usd = getUserBorrowableUSD(msg.sender);
        uint max_borrow_tokens = max_borrow_usd / getLatestPrice(asset_data.priceFeed);
        require(amount <= max_borrow_tokens, "LTV borrow limit.");  
        userToBorrowedAmounts[msg.sender][assetId] += amount;
        asset_data.supplied += amount;
        IERC20(asset_data.token).safeTransfer(msg.sender, amount);
    }

    function repay(uint assetId, uint amount) external {
        require(userToBorrowedAmounts[msg.sender][assetId] >= amount, "Can't repay more"); // Already checked while substracting, find how to optimize
        Asset storage asset_data = assetIdToAsset[assetId];
        userToBorrowedAmounts[msg.sender][assetId] -= amount;
        asset_data.supplied -= amount; 
        IERC20(asset_data.token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function getUserSuppliedUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter;){
                Asset memory asset_data = assetIdToAsset[i];
                uint asset_price = getLatestPrice(asset_data.priceFeed);
                USDamount += userToSuppliedAmounts[user][i] * asset_price;
                unchecked {
                    i++;
                }
        }
        // USDamount /= 1e18;
    }

    function getUserBorrowableUSD(address user) public view returns (uint USDamount) {
        for (uint i=0; i<assetCounter;){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += userToSuppliedAmounts[user][i] * asset_price * asset_data.LTV / 100;
            unchecked {
                i++;
            }
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

    function getSuppliedUSD() external view returns (uint USDamount) {
        for (uint i=0; i<assetCounter; i++){
            Asset memory asset_data = assetIdToAsset[i];
            uint asset_price = getLatestPrice(asset_data.priceFeed);
            USDamount += asset_data.supplied * asset_price;
        }
        // USDamount /= 1e18;
    }

    function getBorrowedUSD() external view returns (uint USDamount) {
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

    function liquidate(address user, uint collateralAssetId, uint debtAssetId, uint debtAmount) external {
        require(isUnderWater(user), "user is not under water.");
        Asset memory collateral_asset = assetIdToAsset[collateralAssetId];
        Asset memory debt_asset = assetIdToAsset[debtAssetId];
        require(debtAmount <= userToBorrowedAmounts[user][debtAssetId]/ 2, "max repay 50% of a debt asset.");
        uint debt_usd_value = debtAmount* getLatestPrice(debt_asset.priceFeed);
        uint collateral_amount = debt_usd_value / getLatestPrice(collateral_asset.priceFeed);
        uint penalty_amount = debt_usd_value * collateral_asset.liquidationPenalty / ( 100 * getLatestPrice(collateral_asset.priceFeed));
        userToBorrowedAmounts[user][debtAssetId] -= debtAmount;
        userToSuppliedAmounts[user][collateral_amount] += collateral_amount - penalty_amount;
        collateral_asset.borrowed -= debtAmount;
        collateral_asset.supplied += collateral_amount - penalty_amount; 
        IERC20(debt_asset.token).safeTransferFrom(address(this), msg.sender, debtAmount);
        IERC20(collateral_asset.token).safeTransferFrom(msg.sender, address(this), collateral_amount - penalty_amount);
        
    }

    function addAsset(address token, address priceFeed, uint ltv, uint liquidationTreshold, uint liquidationPenalty) external onlyOwner {
        Asset storage asset_data = assetIdToAsset[assetCounter];
        asset_data.id = assetCounter;
        asset_data.token = token;
        asset_data.priceFeed = priceFeed;
        asset_data.LTV = ltv;
        asset_data.liquiditationThreshold = liquidationTreshold;
        asset_data.liquidationPenalty = liquidationPenalty;
        assetCounter += 1;
    }
}
