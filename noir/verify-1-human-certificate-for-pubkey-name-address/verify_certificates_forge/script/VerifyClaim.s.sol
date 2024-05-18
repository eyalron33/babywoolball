// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/VerifyClaim.sol";
import "../src/plonk_vk.sol";

contract VerifyClaimScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        address verifier = address(new UltraVerifier());

        new VerifyClaim(verifier);

        vm.stopBroadcast();
    }
}
