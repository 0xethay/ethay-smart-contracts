//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IEthay {
	function buyProduct(address _buyer, uint256 _id, uint256 _quantity, address _referrer) external;
 	function products(uint256) external view returns (uint256,string memory,uint256,uint256,bool,address,uint256,string memory,string memory);
}
