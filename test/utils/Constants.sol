// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";

contract Constants {
  mapping(string => address) private addressMap;
  mapping(string => bytes32) private pairCodeHash;
  //byteCodeHash for trident pairs

  string[] private addressKeys;

  constructor() {
    // Mainnet
    setAddress("mainnet.weth", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    setAddress("mainnet.sushi", 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    setAddress("mainnet.usdc", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    setAddress("mainnet.dai", 0x6B175474E89094C44Da98b954EedeAC495271d0F);
    setAddress("mainnet.usdt", 0xdAC17F958D2ee523a2206206994597C13D831ec7);

    setAddress("mainnet.routeProcessor", 0x827179dD56d07A7eeA32e3873493835da2866976);
    setAddress("mainnet.v2Factory", 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    setAddress("mainnet.v3Factory", 0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F);
    setAddress("mainnet.nonfungiblePositionManager", 0x2214A42d8e2A1d20635c2cb0664422c528B6A432);
    setAddress("mainnet.quoterV2", 0x64e8802FE490fa7cc61d3463958199161Bb608A7);
  }

  function initAddressLabels(Vm vm) public {
    for (uint256 i = 0; i < addressKeys.length; i++) {
      string memory key = addressKeys[i];
      vm.label(addressMap[key], key);
    }
  }

  function setAddress(string memory key, address value) public {
    require(addressMap[key] == address(0), string(bytes.concat("address already exists: ", bytes(key))));
    addressMap[key] = value;
    addressKeys.push(key);
  }

  function getAddress(string calldata key) public view returns (address) {
    require(addressMap[key] != address(0), string(bytes.concat("address not found: ", bytes(key))));
    return addressMap[key];
  }

  function getPairCodeHash(string calldata key) public view returns (bytes32) {
    require(pairCodeHash[key] != "", string(bytes.concat("pairCodeHash not found: ", bytes(key))));
    return pairCodeHash[key];
  }
}
