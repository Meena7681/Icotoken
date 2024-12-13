// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecryptoXICO is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20; 
    uint256 public INITIAL_SUPPLY = 59900000000 * 10**2; // 59.9 Billion (scaled to 2 decimals) 
    uint256 public constant PRE_SALE_PRICE = 12 * 10**3; // Pre-sale price: 0.012 USDT 
    uint256 public ICO_PRICE = 15 * 10**3; // Token price: 0.015 USDT 
    uint256 public LISTING_PRICE = 21 * 10**3; // Token price: 0.021 USDT  

    uint256 public preSaleStartTime;
    uint256 public preSaleEndTime;
    uint256 public icoStartTime;
    uint256 public icoEndTime;
    bool public pausedICO; 
    address public developer;

    string[] private  categories = ["Public Presale", "Development & Innovation", "Marketing & Growth", "Staking", "Community & Partnership", "Reserves", "Listing", "Referral Bonus"];

    // structures
    struct ReferralData {
        address referrer;  // The address of the referrer
        uint256 bonus;     // The bonus earned by the referrer for a specific user
    }

    // Mappings
    mapping(string => address) public priceFeeds;
    mapping(string => address) public supportedTokens;
    mapping(string => uint256) private tokenDistribution;
    mapping(string => uint256) private tokenSold;
    mapping(address => address) private referrer; 
    mapping(address => ReferralData[]) private referralBonuses; 

    // Events
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 price);
    event ICOEnded(uint256 totalTokensSold);
    event PriceUpdated(uint256 newPrice); 
    event ChangeAllocation(string indexed  from, string indexed  to, uint256 tokenAmount, uint256 totalTokenAmount_in_to);
    event CategoryAdded(string categoryName);
    event ReferralBonusPaid(address indexed referrer, address indexed buyer, uint256 bonusAmount, uint256 tokenAmountPaiedByBuyer);
    event TokensBurned(string category, uint256 amount);
    event PresaleDuration(uint256 startTime, uint256 endTime);
    event ICODuration(uint256 startTime, uint256 endTime);
    event PresaleExtended(uint256 newEndTime);
    event ICOExtended(uint256 newStartTime, uint256 newEndTime);


    // Modifier to restrict access to the owner or developer
    modifier onlyOwnerOrDeveloper() {
        require(msg.sender == owner() || msg.sender == developer, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!pausedICO, "Contract is paused");
        _;
    }

    constructor() ERC20("DecryptoX", "DX") Ownable(msg.sender) {
        // Initialize the token
        preSaleStartTime = block.timestamp;
        preSaleEndTime = preSaleStartTime + 60 days; // 2 months pre-sale period
        icoStartTime = preSaleEndTime; 
        icoEndTime = icoStartTime + 124 days; //4 months 
        _mint(address(this), INITIAL_SUPPLY);

        // Initialize categories with new token distribution allocations
        tokenDistribution["Public Presale"] = 14975000000 * 10**18;  // 25% of total supply
        tokenDistribution["Development & Innovation"] = 5990000000 * 10**18;  // 10% of total supply
        tokenDistribution["Marketing & Growth"] = 10183000000 * 10**18;  // 17% of total supply
        tokenDistribution["Staking"] = 8985000000 * 10**18;  // 15% of total supply
        tokenDistribution["Community & Partnership"] = 7188000000 * 10**18;  // 12% of total supply
        tokenDistribution["Reserves"] = 6589000000 * 10**18;  // 11% of total supply
        tokenDistribution["Listing"] = 5391000000 * 10**18;  // 9% of total supply
        tokenDistribution["Referral Bonus"] = 599000000 * 10**18;  // 1% of total supply

        // Ethereum tokens
        supportedTokens["ETH/ETH"] = address(0); // Native ETH
        supportedTokens["USDT/ETH"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        supportedTokens["USDC/ETH"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC  
        supportedTokens["DAI/ETH"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI  

        // Binance tokens
        supportedTokens["BNB/BNB"] = address(0); // Native BNB
        supportedTokens["ETH/BNB"] = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8; // ETH
        supportedTokens["USDT/BNB"] = 0x55d398326f99059fF775485246999027B3197955; // USDT
        supportedTokens["USDC/BNB"] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC
        supportedTokens["DAI/BNB"] = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3; // DAI
        supportedTokens["SOL/BNB"] = 0x570A5D26f7765Ecb712C0924E4De545B89fD43dF; // SOL
        supportedTokens["XRP/BNB"] = 0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE; // XRP
 
        // Ethereum Mainnet price feeds
        priceFeeds["ETH/ETH"] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD
        priceFeeds["USDC/ETH"] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC/USD
        priceFeeds["USDT/ETH"] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D; // USDT/USD
        priceFeeds["DAI/ETH"] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9; // DAI/USD   

        // Binance Mainnet price feeds
        priceFeeds["BNB/BNB"] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // BNB/USD
        priceFeeds["ETH/BNB"] = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e; // ETH/USD
        priceFeeds["USDT/BNB"] = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320; // USDT/USD
        priceFeeds["USDC/BNB"] = 0x51597f405303C4377E36123cBc172b13269EA163; // USDC/USD 
        priceFeeds["SOL/BNB"] = 0x0E8a53DD9c13589df6382F13dA6B3Ec8F919B323; // SOL/USD
        priceFeeds["XRP/BNB"] = 0x93A67D414896A280bF8FFB3b389fE3686E014fda; // XRP/USD
        priceFeeds["DAI/BNB"] = 0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA; // DAI/USD
 
    }
    
    // set developer access to node 
    function setDeveloper(address _developer) external onlyOwner {
        developer = _developer;
    }

    // Paused/Resume the ICO in some emergency
    function togglePause() external onlyOwnerOrDeveloper {
        pausedICO = !pausedICO;
    }

// 1-> Token Distribution Category and Amount management 

    // Function to add category
    function addCategory(string memory name) internal onlyOwnerOrDeveloper{ 
        bool isPresent = false;
         
        for (uint256 i = 0; i < categories.length; i++) {
            if (keccak256(abi.encodePacked(categories[i])) == keccak256(abi.encodePacked(name))) {
                isPresent = true; // Category found
                break;
            }
        }
    
        // If the category does not exist, push it into the array and add its token amount
        if (!isPresent) {
            categories.push(name);
            emit CategoryAdded(name);
        }
    }

//2-> Getters 

    function getCategories() external view onlyOwnerOrDeveloper returns(string[] memory){
        return categories;
    }
 
    function getAllocations(string memory category_name) external view onlyOwnerOrDeveloper returns(uint256){
        return tokenDistribution[category_name];
    }

    function getTokenSold(string memory category_name) external view returns(uint256){
        return tokenSold[category_name];
    }
 

    function getReferralData(address _address)  external view returns(ReferralData[] memory){
        return referralBonuses[_address];
    }

    function getReferrer(address _address) external  view returns (address){
        return referrer[_address];
    }

    // Function to transfer the token from one distribution to another
    function changeAllocation(string memory from, string memory to, uint256 amount) external onlyOwnerOrDeveloper {
        require(amount > 0, "Invalid Token amount.");
        require(tokenDistribution[from] >= tokenSold[from] && tokenDistribution[from] - tokenSold[from] >= amount, "Insufficient tokens in 'from' category.");
        
        tokenDistribution[from] -= amount;
        tokenDistribution[to] += amount;

        addCategory(to);
           

        emit ChangeAllocation(from, to, amount, tokenDistribution[to]);
    }

// 3-> Refer & Earn System

    // calculate referral bonus
    function calculateReferralBonus(uint256 purchaseAmountInUSD) internal pure returns (uint256) {

        uint256 bonusPercentage;

        if (purchaseAmountInUSD >= 100 && purchaseAmountInUSD < 1000) {
            bonusPercentage = 2; // 2% bonus for purchases between $100 and $1000
        } else if (purchaseAmountInUSD >= 1000 && purchaseAmountInUSD < 5000) {
            bonusPercentage = 4; // 4% bonus for purchases between $1000 and $5000
        } else if (purchaseAmountInUSD >= 5000 && purchaseAmountInUSD < 10000) {
            bonusPercentage = 8; // 8% bonus for purchases between $5000 and $10000
        } else if (purchaseAmountInUSD >= 10000) {
            bonusPercentage = 10; // 10% bonus for purchases above $10000
        }

        return bonusPercentage;
    }

// 4-> Manage PriceFeeds

    function addPriceFeed(string memory tokenSymbol, address feedAddress) public onlyOwnerOrDeveloper {
        require(feedAddress != address(0), "Invalid feed address");
        priceFeeds[tokenSymbol] = feedAddress;
    }
    
    function addSupportedToken(string memory tokenSymbol, address tokenAddress) public onlyOwnerOrDeveloper {
        require(tokenAddress != address(0), "Invalid feed address");
        supportedTokens[tokenSymbol] = tokenAddress;
    }

// 5-> Manage ico durations
    
    // Function to set the presale start time and duration
    function setPresaleDuration(uint256 _startTime) external onlyOwnerOrDeveloper {
        require(_startTime > block.timestamp, "Start time must be in the future.");
        
        preSaleStartTime = _startTime;
        preSaleEndTime = preSaleStartTime + 60 days; 
        icoStartTime = preSaleEndTime;
        icoEndTime = icoStartTime + 122 days;

        emit PresaleDuration(preSaleStartTime, preSaleEndTime);
        emit ICODuration(icoStartTime, icoEndTime);
    }

    // Function to extend the presale duration
    function extendPresaleDuration(uint256 _days) external onlyOwnerOrDeveloper {
        require(_days > 0, "Duration must be greater than zero.");

        // Extend the presale by the specified number of days
        preSaleEndTime += _days * 1 days;

        // Adjust ICO start and end times based on the new presale end time
        icoStartTime = preSaleEndTime;
        icoEndTime = icoStartTime + 122 days;

        emit PresaleExtended(preSaleEndTime);
        emit ICOExtended(icoStartTime, icoEndTime);
    }

    // Function to extend the ICO duration
    function extendICODuration(uint256 _days) external onlyOwnerOrDeveloper {
        require(_days > 0, "Duration must be greater than zero.");

        // Extend the ICO by the specified number of days
        icoEndTime += _days * 1 days;

        emit ICOExtended(icoStartTime, icoEndTime);
    }

    // Override decimals to 2 for two decimal places
    function decimals() public view virtual override returns (uint8) {
        return 2;
    }

    /* 
        params: 
            token: tokenName/network eg. ETH/ETH, USDT/BNB
    */
    // Get the latest price of a token in USD (based on the network)
    function getPriceInUSDUtil(string memory token) internal view returns (uint256) { 
        address feedAddress = priceFeeds[token];
        require(feedAddress != address(0), "Token not supported or price feed unavailable");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feedAddress);
        (, int256 price, , , ) = priceFeed.latestRoundData(); 
        require(price > 0, "Invalid price feed");
        return uint256(price);
    }

    function getPriceInUSD(string memory token) public view returns (uint256){
        return getPriceInUSDUtil(token);
    }

    function updateTokenPrice() public onlyOwnerOrDeveloper{
        require(block.timestamp >= icoStartTime, "ICO not started.");
        require(block.timestamp <= icoEndTime, "ICO ended.");
        require(ICO_PRICE <= 21000, "Price has reach his high price."); 
        ICO_PRICE = ICO_PRICE + ((ICO_PRICE * 55)/10000);
        emit PriceUpdated(ICO_PRICE);
    }


    // Abstract function to handle referral logic
    function handleReferralUtil(uint256 TOKEN_PRICE, address _referrer, uint256 totalPaymentInUSD, uint256 usdtPriceInUSD) internal {
        if (_referrer != address(0) && referrer[msg.sender] == address(0) && _referrer != msg.sender) {
            referrer[msg.sender] = _referrer;

            uint256 bonusPercentage = calculateReferralBonus(totalPaymentInUSD / 1e18);
            uint256 referralBonusAmount = (totalPaymentInUSD * bonusPercentage) / 100;
            uint256 referralBonusInUSDT = (referralBonusAmount * 1e8) / usdtPriceInUSD;

            uint256 referralBonus = (referralBonusInUSDT * (10 ** decimals())) / (TOKEN_PRICE * 1e12);

            require(tokenDistribution["Referral Bonus"] - tokenSold["Referral Bonus"] >= referralBonus, "Not enough tokens in the referral pool");

            // Transfer referral bonus to referrer
            _transfer(address(this), _referrer, referralBonus);
            tokenSold["Referral Bonus"] += referralBonus;

            // Update referral bonuses
            referralBonuses[_referrer].push(ReferralData({
                referrer: _referrer,
                bonus: referralBonus      
            }));

            emit ReferralBonusPaid(_referrer, msg.sender, referralBonus, totalPaymentInUSD);
        }
    }

    // Abstract function to hide calculations
    function getTokenReceiveUtil(string memory token, uint256 paymentAmount) internal returns (uint256, uint256, uint256, uint256){
        uint256 TOKEN_PRICE;
        if (block.timestamp < preSaleEndTime) {
            TOKEN_PRICE = PRE_SALE_PRICE;
        } else if(block.timestamp<icoEndTime){
            TOKEN_PRICE = ICO_PRICE;
        }else{
            TOKEN_PRICE = LISTING_PRICE;
        }
        uint256 paymentTokenPriceInUSD = getPriceInUSD(token);

        // Normalize payment amount to 18 decimals
        uint256 paymentAmountIn18Decimals;

        // Handle native ETH & BNB separately
        // Fetch the payment token price in USD (normalized to 18 decimals)
       if (
        keccak256(abi.encodePacked(token)) == keccak256(abi.encodePacked("ETH/ETH")) ||
        keccak256(abi.encodePacked(token)) == keccak256(abi.encodePacked("BNB/BNB"))) {
            require(msg.value == paymentAmount, "ETH value mismatch"); 
            paymentAmountIn18Decimals = msg.value;
        } else {
            address tokenAddress = supportedTokens[token];
            require(tokenAddress != address(0), "Unsupported token");

            IERC20 _token = IERC20(tokenAddress);
            uint8 tokenDecimals = ERC20(address(_token)).decimals();
            paymentAmountIn18Decimals = paymentAmount * (10 ** (18 - tokenDecimals));
        }

         
        // Calculate the total payment amount in USD
        uint256 totalPaymentInUSD = (paymentAmountIn18Decimals * paymentTokenPriceInUSD) / 1e8;

        // Fetch the USDT/USD price from the aggregator
        uint256 usdtPriceInUSD = getPriceInUSD("USDT/ETH");

        // Convert USD amount to USDT
        uint256 totalPaymentInUSDT = (totalPaymentInUSD * 1e8) / usdtPriceInUSD;

        // Calculate the number of tokens to buy
        uint256 tokensToBuy = (totalPaymentInUSDT * (10 ** decimals())) / (TOKEN_PRICE * 1e12);

        return (TOKEN_PRICE, tokensToBuy, totalPaymentInUSD, usdtPriceInUSD);
    }

    /* params:  
        token = tokenName/network eg. ETH/ETH, USDT/ETH, USDT/BNB
        amount = amount * decimals(token)  
        _referrer = if referrer than it's wallet address else 0x0000000000000000000000000000000000000000
   */
    function buyDCRX(string memory token, uint256 paymentAmount, address _referrer) external payable whenNotPaused nonReentrant {
        require(paymentAmount > 0, "Must send a valid payment amount");

        (uint256 TOKEN_PRICE, uint256 tokensToBuy, uint256 totalPaymentInUSD, uint256 usdtPriceInUSD) = getTokenReceiveUtil(token, paymentAmount);

        require(tokenSold["Public Presale"] + tokensToBuy <= tokenDistribution["Public Presale"], "Not enough tokens available.");

        bool transferSuccessful = false;
        address tokenAddress;
        // Transfer amount to owner account
        if (
        keccak256(abi.encodePacked(token)) == keccak256(abi.encodePacked("ETH/ETH")) ||
        keccak256(abi.encodePacked(token)) == keccak256(abi.encodePacked("BNB/BNB"))) { 
            require(msg.value >= paymentAmount, "Insufficient balance for native token payment");
            payable(owner()).transfer(msg.value); 
            transferSuccessful = true;
        } else {
            tokenAddress = supportedTokens[token];
            require(tokenAddress != address(0), "Unsupported token");

            IERC20 tokenContract = IERC20(tokenAddress);
            
            require(tokenContract.balanceOf(msg.sender) >= paymentAmount, "Insufficient balance of the token"); 
            require(tokenContract.allowance(msg.sender, address(this)) >= paymentAmount, "Insufficient allowance for token transfer");

            // Transfer tokens to the contract owner
            transferSuccessful = tokenContract.transferFrom(msg.sender, owner(), paymentAmount);
        }

        // If the transfer was successful, proceed to give DCRX tokens to the user
        if (transferSuccessful) {
            _transfer(address(this), msg.sender, tokensToBuy);
            tokenSold["Public Presale"] += tokensToBuy;
            handleReferralUtil(TOKEN_PRICE, _referrer, totalPaymentInUSD, usdtPriceInUSD);
            emit TokensPurchased(msg.sender, tokensToBuy, TOKEN_PRICE);
        } else {
            // If the transfer fails, refund the tokens to the user
            bool refundSuccessful = tokenAddress != address(0) 
                ? IERC20(tokenAddress).transfer(msg.sender, paymentAmount) 
                : false;  // For ETH or BNB, no need to refund if transfer failed

            require(refundSuccessful, "Refund failed. Tokens could not be returned to the user.");
        }

    }


    // End the ICO and transfer remaining tokens to the owner
    function endICO() external onlyOwnerOrDeveloper {
        uint256 remainingTokens = balanceOf(address(this));
        _transfer(address(this), owner(), remainingTokens);
        tokenSold["Public Presale"] = tokenDistribution["Public Presale"] - tokenSold["Public Presale"];
        emit ICOEnded(tokenSold["Public Presale"]);
    }

    // Abstracted function to check if the category has enough tokens to burn
    function canBurnTokens(string memory category, uint256 amount) internal view returns (bool) {
        return tokenDistribution[category] - tokenSold[category] >= amount;
    }

    // Abstracted function to update category pools and the total supply
    function updateTokenSupplyUtil(string memory category, uint256 amount) internal {
        // Reduce the amount from the category pool
        tokenDistribution[category] -= amount;

        // Update the total supply
        INITIAL_SUPPLY -= amount;
    }

    // Abstracted function to perform the token burn
    function executeBurnUtil(address account, uint256 amount) internal {
        // Transfer the tokens to the burn address (0x0)
        _transfer(account, address(0), amount);
    }

    // Burn Token 
    function burnTokens(string memory category, uint256 amount) external onlyOwnerOrDeveloper {
        require(amount > 0, "Amount must be greater than 0");
        require(canBurnTokens(category, amount), "Insufficient tokens in the category");

        // Update the category and total supply
        updateTokenSupplyUtil(category, amount);

        // Execute the burn
        executeBurnUtil(address(this), amount);

        // Emit burn event
        emit TokensBurned(category, amount);
    }


    // To receive ETH
    receive() external payable {}
}