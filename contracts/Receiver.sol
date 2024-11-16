// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IEthay} from "./interfaces/IEthay.sol";
 

 
contract Receiver is CCIPReceiver {
    address public dataTest;
    IERC20 public usdtToken;
    IEthay public ethay;
    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string text // The text that was received.
    );

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    string private s_lastReceivedText; // Store the last received text.

    /// @notice Constructor initializes the contract with the router address.
    /// @param router The address of the router contract.
    constructor(address router,address _usdtToken,address _ethay) CCIPReceiver(router) {
        usdtToken = IERC20(_usdtToken);
        ethay = IEthay(_ethay);
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        // s_lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        // s_lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text
        bytes memory payload = abi.decode(any2EvmMessage.data, (bytes)); // abi-decoding of the sent text
        (address _buyer, uint256 _id, uint256 _quantity, address _referrer,uint256 _price) = abi.decode(payload, (address, uint256, uint256, address,uint256)); // abi-decoding of the sent text
        dataTest = _buyer;
        uint256 totalPrice = _price * _quantity;
        usdtToken.mint(address(this), totalPrice);
        usdtToken.approve(address(ethay), totalPrice);     


        try ethay.buyProduct(_buyer, _id, _quantity, _referrer) {
        } catch {
           usdtToken.transfer(_buyer, totalPrice);
        }
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            abi.decode(any2EvmMessage.data, (string))
        );
    }


}
