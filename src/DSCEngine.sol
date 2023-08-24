//SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Fatma
 * @dev This system is designed to be as minimal as possible with 1token == $1 peg.
 * This stablecoin has the following properties:
 * -Exogenous
 * -Dollar Pegged
 * -Algorithmically stable
 * This system should have more collateral > than the $pegged DSC.
 * @notice This system is the core of the DSC system it handles all the logic
 *  for mining and redeeming DCS as well as depositing & withdrawing collateral
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system.
 */

contract DSCEngine is ReentrancyGuard {
    /////////////////
    //Errors
    ////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__tokenAddressesAndPriceFeedAddressMustBeSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthfactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    /////////////////
    //State Variables
    ////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /////////////////
    //EVents
    ////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event CollateralRedeemed(address indexed user,uint256 indexed amount,address indexed token);

    /////////////////
    //Modifiers
    ////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /////////////////
    //Functions
    ////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__tokenAddressesAndPriceFeedAddressMustBeSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////
    //External Functions
    ////////////

     /*
     *@param tokenCollateralAddress The address of the Token to deposit as collateral
     *@param amountCollateral The amount of collateral to deposit
     *@param amountDscToMint the amount of decentralzed stablecoin to mint
     *@notice this function will deposit your collateral andmint DSC in one transaction
     */
    function depositCollateralAndMintDSC(address tokenCollateralAddress,
        uint256 amountCollateral, uint256 amountDscToMint) external {
            depositCollateral(tokenCollateralAddress, amountCollateral);
            mintDsc(amountDscToMint);

        }

    /*
     *@param tokenCollateralAddress The address of the Token to deposit as collateral
     *@param amountCollateral The amount of collateral to deposit
     */

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralForDsc() external {}
    // In order to redeem collateral:
    //1. health factor must be over 1 After collateral pulled
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
     external moreThanZero(amountCollateral)
      nonReentrant(){
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, amountCollateral, tokenCollateralAddress);

        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);

      }

    /*
    *@notice follows CEI
    *@param amountDscToMint The amount of decentralized stablecoin to mint
    @notice must have collateral value>DSC.This will involve Pricefeeds,Values etc
    */
    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        ///check if the collateral value>DSC.This will involve Pricefeeds,Values etc
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 amount) external moreThanZero(amount){
        //remove the DSC minted
        s_DSCMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        if(!success){
            revert DSCEngine__TransferFailed();

        }
        i_dsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate() external {}

    function getHealthFactor() external view {}

    /////////////////
    //Private & Internal view Functions
    ////////////
    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
     *Returns how close to liquidation a user is
     *if a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        //total DCS minted
        //total collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user); 
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthfactor(userHealthFactor);
        }
    }

    /////////////////
    //Public & External view Functions
    ////////////
    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInusd) {
        //loop through each collateral token and
        //get the amount they have deposited and map it to the price,to get the USD Value
        for(uint256 i; i<s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInusd += getUsdValue(token, amount);
        }
        return totalCollateralValueInusd;

    }
    
    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION;

    }


}
