// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./AggregatorV3Interface.sol";

error InsufficientGasForExternalCall();

contract FallbackPriceFeed  {

    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    uint256 public lastGoodPrice;
    bool public shutdown;

    AggregatorV3Interface public immutable primaryAggregator;
    uint256 public immutable primaryStalenessPeriod;
    uint8 public immutable primaryDecimals;

    AggregatorV3Interface public immutable secondaryAggregator;
    uint256 public immutable secondaryStalenessPeriod;
    uint8 public immutable secondaryDecimals;
    

    constructor(
        address _primaryOracleAddress,
        uint _primaryOracleStalenessThreshold,
        address _secondaryOracleAddress,
        uint _secondaryOracleStalenessThreshold,
        address _deployer
    ) {
        primaryAggregator = AggregatorV3Interface(_primaryOracleAddress);
        primaryStalenessPeriod = _primaryOracleStalenessThreshold;
        primaryDecimals = 8;

        secondaryAggregator = AggregatorV3Interface(_secondaryOracleAddress);
        secondaryStalenessPeriod = _secondaryOracleStalenessThreshold;
        secondaryDecimals = 8;
    }


    function fetchPrice() public returns (uint256, bool) {
        if (!shutdown) {
            (uint primaryPrice, bool isPrimaryOracleDown) = _getOracleAnswer(
                primaryAggregator,
                primaryStalenessPeriod,
                primaryDecimals
            );

            if (!isPrimaryOracleDown) {
                lastGoodPrice = primaryPrice;

                return (primaryPrice, false);
            }

            (uint secondaryPrice, bool isSecondaryOracleDown) = _getOracleAnswer(
                secondaryAggregator,
                secondaryStalenessPeriod,
                secondaryDecimals
            );

            if (!isSecondaryOracleDown) {
                lastGoodPrice = secondaryPrice;

                return (secondaryPrice, false);
            }

            return (lastGoodPrice, true);
        }

        return (lastGoodPrice, false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        return fetchPrice();
    }

    function _getOracleAnswer(
        AggregatorV3Interface _aggregator,
        uint256 _stalenessPeriod,
        uint8 _decimals
    ) internal view returns (uint256, bool) {
        ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(_aggregator);

        uint256 scaledPrice;
        bool oracleIsDown;

        if (!_isValidChainlinkPrice(chainlinkResponse, _stalenessPeriod)) {
            oracleIsDown = true;
        } else {
            scaledPrice = _scaleChainlinkPriceTo18decimals(chainlinkResponse.answer, _decimals);
        }

        return (scaledPrice, oracleIsDown);
    }

    function _getCurrentChainlinkResponse(AggregatorV3Interface _aggregator)
    internal
    view
    returns (ChainlinkResponse memory chainlinkResponse)
    {
        uint256 gasBefore = gasleft();

        // Try to get latest price data:
        try _aggregator.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256, /* startedAt */
            uint256 updatedAt,
            uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = updatedAt;
            chainlinkResponse.success = true;

            return chainlinkResponse;
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the call to Chainlink
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    // False if:
    // - Call to Chainlink aggregator reverts
    // - price is too stale, i.e. older than the oracle's staleness threshold
    // - Price answer is 0 or negative
    function _isValidChainlinkPrice(ChainlinkResponse memory chainlinkResponse, uint256 _stalenessThreshold)
    internal
    view
    returns (bool)
    {
        return chainlinkResponse.success && block.timestamp - chainlinkResponse.timestamp < _stalenessThreshold
            && chainlinkResponse.answer > 0;
    }

    // Trust assumption: Chainlink won't change the decimal precision on any feed used in v2 after deployment
    function _scaleChainlinkPriceTo18decimals(int256 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(_price) * 10 ** (18 - _decimals);
    }
}
