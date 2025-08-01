// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Get funds from users
// Withdraw funds
//

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PriceConverter} from "./PriceConverter.sol";

error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    address[] public funders;

    mapping(address funder => uint256 amountFunded)
        public addressToAmountFunded;

    // constants are set once outside of a function
    uint256 public constant MINIMUM_USD = 5e18;
    // immutables are set once in a function, or set once outside of their declaration
    address public immutable i_owner;

    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        // 1. How do we send ETH to this contract
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Not enough ETH sent"
        );
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] = msg.value;
    }

    function withdraw() public only_Owner {
        require(msg.sender == i_owner, "Must be i_owner to withdraw");
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
        // Send with transfer
        payable(msg.sender).transfer(address(this).balance);
        // Send with send
        bool sendSuccess = payable(msg.sender).send(address(this).balance);
        require(sendSuccess, "Send Failed");
        // Send with call
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function getVersion() public view returns (uint256) {
        return PriceConverter.getVersion(s_priceFeed);
    }

    modifier only_Owner() {
        // require(msg.sender == i_owner, "Senter is not i_owner");
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }
        _;
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
