// SPDX-License-Identifier: MIT
// Interface for Woolball contract

pragma solidity >=0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/**
 * @title Commander Token Simple Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @notice This is the simplest implementation of Commander Token, you should inherent in order to extend it for complex use cases 
 * @dev Commander Tokens is an extenntion to ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause we add a new mechniasm enabling a token to depend on another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev if token B depedns on token A, we again call A a Commander Token (CT).
 */
interface IBabyWoolball is IERC721 {

    /**
     * @dev Emitted when a new human name is created by a wallet.
     */
    event humanNameCreated(string name, address creator, uint256 expiration, address dataContractAddress);

    /**
     * @dev Emitted when a subname is created
     */
    event subnameCreated(string subname, uint256 creatorNameID, uint256 subnameID);

    function newHumanName(string calldata name, address creator, uint256 expiration, address resolverAddress) external returns (uint256);
}
