// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/**
 * @title Locked Token Reference Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @dev Locked Tokens enable the automatic transfer of tokens.
 * @dev If token A is locked to B, then:
 * @dev 1. A cannot be transferred or burned unless B is transferred or burned, and,
 * @dev 2. every transfer of B, also transfers A.
 * @dev Locking is possible if and only if both tokens have the same owner.
 */
interface ILockedToken is IERC721 {
    /**
     * @dev Emitted when tokenId is locked to LockingId from LockingContract.
     */
    event NewLocking(uint256 tokenId, address LockingContract, uint256 LockingId);

    /**
     * @dev Emitted when a locking tokenId to LockingId from LockingContract is removed.
     */
    event Unlocked(uint256 tokenId);

    
    /**
     * @dev Locks tokenId CTId from contract CTContract. Both tokens must have the same owner.
     * @dev 
     * @dev With such a lock in place, tokenId transfer and burn functions can't be called by
     * @dev its owner as long as the locking is in place.
     * @dev 
     * @dev If LckingId is transferred or burned, it also transfers or burns tokenId.
     * @dev If tokenId is nontransferable or unburnable, then a call to the transfer or
     * @dev burn function of the LockingId unlocks the tokenId.
     */
    function lock(uint256 tokenId, address LockingContract, uint256 LockingId) external;

    /**
     * @dev unlocks a a token.
     * @dev This function must be called from the contract that locked tokenId.
     */
    function unlock(uint256 tokenId) external;

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(uint256 tokenId) external view returns (address, uint256);

    /**
     * @dev addLockedToken notifies a Token that another token (LockedId), with the same owner, is locked to it.
     */ 
    function addLockedToken(uint256 tokenId, address LockedContract, uint256 LockedId) external;

    /**
     * @dev removeLockedToken removes a token that was locked to the tokenId.
     */
    function removeLockedToken(uint256 tokenId, address LockedContract, uint256 LockedId) external;

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any 
     * rules for how they're done (or if they're done at all). However, we add a burn function to
     * ILockedToken, since its implementation depends on the locking system.
     */

    /**
     * @dev Burns the tokenId and all the tokens locked to it.
     * @dev If a locked token is unburnable, it unlocks it.
     **/
    function burn(uint256 tokenId) external;
}
