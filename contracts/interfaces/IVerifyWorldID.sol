//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IVerifyWorldID {
    function verifyHuman(address signal, uint256 root, uint256 nullifierHash, uint256[8] calldata proof) external;

    function isVerifiedHuman(address) external view returns(bool);

}
