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
/**
 * @title DSCEngine
 * @author Fatma
 * @dev This system is designed to be as minimal as possible with 1token == $1 peg.
 *This stablecoin has the following properties:
 *-Exogenous
 *-Dollar Pegged
 *-Algorithmically stable
 * This system should have more collateral > than the $pegged DSC.
 * @notice This system is the core of the DSC system it handles all the logic 
 for mining and redeeming DCS as well as depositing & withdrawing collateral
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine{
   /////////////////
    //Errors
    ////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__tokenAddressesAndPriceFeedAddressMustBeSame();
   /////////////////
    //State Variables
    ////////////////
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed

    /////////////////
    //Modifiers
    ////////////////
    modifier moreThanZero(uint256 amount){
        if(amount==0){
            revert DSCEngine__NeedsMoreThanZero();
        }
            _;
    }

    modifier isAllowedToken(address Token){
        _;
    }

    /////////////////
    //Functions
    ////////////////
    constructor(address [] memory tokenAddresses, address[] memory priceFeedAddress){
        if(tokenAddresses.length != priceFeedAddress.length){
            revert DSCEngine__tokenAddressesAndPriceFeedAddressMustBeSame();
        }
    }

    /////////////////
    //External Functions
    ////////////
    function depositCollateralAndMintDSC() external{}
    /*
    *@param tokenCollateralAddress The address of the Token to deposit as collateral
    *@param amountCollateral The amount of collateral to deposit
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral){}
    function redeemCollateralForDsc() external{}
    function redeemCollateral() external{}
    function mintDsc() external{}
    function burnDsc() external{}
    function liquidate() external{}
    function getHealthFactor() external view {}

}