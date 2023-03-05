// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

abstract contract PriceFeed {

    
    function getEthPrice()public view returns(uint){
        (,int price,,,) = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e).latestRoundData();
        return uint(price);
    }

}