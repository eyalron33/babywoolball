// SPDX-License-Identifier: MIT
// Interface for verifying a claim for an EVM address

pragma solidity >=0.8.25;


interface IVerifyClaim {

    function verifyClaimAddress(
        bytes calldata proof,
        address claimerAddess, 
        uint256 lastCheckedTimestamp,
        bytes32 trustKernelHash,
        uint256 strength,
        uint256 claimType,
        bytes32[] calldata morePublicInputs
    ) external view returns (bool);
}
