pragma solidity ^0.8.25;

import "./plonk_vk.sol";
import "./IVerifyClaim.sol";


contract VerifyClaim is IVerifyClaim {
	UltraVerifier verifierContract;

	constructor(
        address _verifierContract
    )  {
		verifierContract = UltraVerifier(_verifierContract);
    }

	function verifyClaimAddress(
        bytes calldata proof,
        address claimerAddess,
        uint256 lastCheckedTimestamp,
        bytes32 trustKernelHash,
        uint256 strength,
        uint256 claimType,
        bytes32[] calldata morePublicInputs
  ) external view returns (bool) {
    bool returnValue = false;

		if (strength == 2 && claimType == 2) {
			bytes32[] memory publicInputs = new bytes32[](3);

      bytes32 claimerAddessBytes = bytes32(uint256(uint160(claimerAddess)) << 96);

			publicInputs[0] = bytes32(claimerAddessBytes);
			publicInputs[1] = trustKernelHash;
			publicInputs[2] = bytes32(lastCheckedTimestamp);

      returnValue = verifierContract.verify(proof, publicInputs);
		}

    return returnValue;
  }
}
