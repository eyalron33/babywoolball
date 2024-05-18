// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

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
interface ICommanderToken is IERC721 {

    /**
     * @dev Emitted when a dependency on CTId from CTContractAddress is added to `tokenId`.
     */
    event NewDependence(uint256 tokenId, address CTContractAddress, uint256 CTId);

    /**
     * @dev Emitted when a dependency on CTId from CTContractAddress is removed to `tokenId`.
     */
    event RemovedDependence(uint256 tokenId, address CTContractAddress, uint256 CTId);

    /**
     * @dev Adds to tokenId dependency on CTId from contract CTContractAddress.
     * @dev A token can be transfered or burned only if all the tokens it depends on are transferable or burnable, correspondingly.
     * @dev The caller must be the owner, opertaor or approved to use tokenId.
     */
    function setDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    /**
     * @dev Removes from tokenId the dependency on CTId from contract CTContractAddress.
     */
    function removeDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    /**
     * @dev Checks if tokenId depends on CTId from CTContractAddress.
     **/
    function isDependent(uint256 tokenId, address CTContractAddress, uint256 CTId) external view returns (bool);

    /**
     * These functions are for managing the effect of dependence of tokens.
     * If a token is untransferable, then all the tokens depending on it are untransferable as well.
     * If a token is unburnable, then all the tokens depending on it are unburnable as well.
     */

     /**
     * @dev Sets the transferable property of tokenId.
     **/
    function setTransferable(uint256 tokenId, bool transferable) external;

    /**
     * @dev Sets the burnable status of tokenId.
     **/    
    function setBurnable(uint256 tokenId, bool burnable) external;

    /**
     * @dev Checks the transferable property of tokenId 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isTransferable(uint256 tokenId) external view returns (bool);
    
    /**
     * @dev Checks the burnable property of tokenId 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isBurnable(uint256 tokenId) external view returns (bool);

    /**
     * @dev Checks if all the tokens that tokenId depends on are transferable or not 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentTransferable(uint256 tokenId) external view returns (bool);
    
    /**
     * @dev Checks all the tokens that tokenId depends on are burnable 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentBurnable(uint256 tokenId) external view returns (bool);

    /**
     * @dev Checks if tokenId can be transferred 
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenTransferable(uint256 tokenID) external view returns (bool);
    
    /**
     * @dev Checks if tokenId can be burned.
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenBurnable(uint256 tokenID) external view returns (bool);

    /** 
     * A whitelist mechanism. If an address is whitelisted it means the token can be transferred
     * to it, regardless of the value of 'isTokenTransferable'.
     */

    /**
      * @dev Adds or removes an address from the whitelist of tokenId.
      * @dev tokenId can be transferred to whitelisted addresses even when its set to be nontransferable.
      **/ 
    function setTransferWhitelist(uint256 tokenId, address whitelistAddress, bool isWhitelisted) external;
    
    /**
     * @dev Checks if an address is whitelisted.
     **/
    function isAddressWhitelisted(uint256 tokenId, address whitelistAddress) external view returns (bool);
    
    /**
      * @dev Checks if tokenId can be transferred to addressToTransferTo, without taking its dependence into consideration.
      **/
    function isTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    
    /**
      * @dev Checks if all the dependences of tokenId can be transferred to addressToTransferTo,
      **/
    function isDependentTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    
    /**
      * @dev Checks if tokenId can be transferred to addressToTransferTo.
      **/
    function isTokenTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any 
     * rules for how they're done (or if they're done at all). However, we add a burn function to
     * ICommanderToken, since its implementation depends on the dependence system.
     */

     /**
     * @dev burns tokenId.
     * @dev isTokenBurnable must return 'true'.
     **/
    function burn(uint256 tokenId) external;
}
