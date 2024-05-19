 // SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./interfaces/ICommanderToken.sol";
import "./interfaces/ILockedToken.sol";
import "./interfaces/ERC721EnumerableURIStorage.sol";

/**
 * @title LCT: Locked Commander Token, a token implementing both Commander and Locked Tokens interface
 * @author Eyal Ron
 */
contract LCT is ICommanderToken, ILockedToken, ERC721EnumerableURIStorage {
    struct ExternalToken {
        address tokensCollection;
        uint256 tokenID;
    }

    struct LCToken {
        bool nontransferable;
        bool nonburnable;

        // The Commander Tokens this CToken struct depends on
        ExternalToken[] dependencies;
        
        // A mapping to manage the indices of "dependencies"
        mapping(address => mapping(uint256 => uint256)) dependenciesIndex;

        // A whitelist of addresses the token can be transferred to regardless of the value of "nontransferable"
        // Note: an address can be whitelisted but the token still won't be transferable to this address
        // if it depends on a nontransferable token
        mapping(address => bool) whitelist;

        ExternalToken[] lockedTokens; // array of tokens locked to this token
        
        // A mapping to manage the indices of "lockedTokens"
        mapping(address => mapping(uint256 => uint256)) lockingsIndex;

        // 0 if this token is unlocked, or otherwise holds the information of the locking token
        ExternalToken locked;
    }

    modifier approvedOrOwner(uint256 tokenID) {
        require(
            _isAuthorized(msg.sender, tokenID),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // verifies that two tokens have the same owner
    modifier sameOwner(
        uint256 token1ID,
        address Token2ContractAddress,
        uint256 Token2ID
    ) {
        require(
            ERC721.ownerOf(token1ID) == ERC721(Token2ContractAddress).ownerOf(Token2ID),
            "Locked Token: the tokens do not have the same owner"
        );
        _;
    }

    modifier onlyContract(address contractAddress) {
        require(
            (  
                contractAddress == msg.sender || 
                contractAddress == address(this) 
            ),
            "Locked Token: transaction is not sent from the correct contract"
        );
        _;
    }

    modifier isApproveOwnerOrLockingContract(uint256 tokenID) {
        (, uint256 lockedCT) = isLocked(tokenID);
        if (lockedCT > 0)
            require(
                (
                    msg.sender == address(_tokens[tokenID].locked.tokensCollection) || 
                    address(this) == address(_tokens[tokenID].locked.tokensCollection) 
                ),
                "Locked Token: tokenID is locked and caller is not the contract holding the locking token"
            );
        else
            require(
                _isAuthorized(_msgSender(), tokenID),
                "ERC721: caller is not token owner or approved"
            );
        _;
    }

    // LCT ID -> token's data
    mapping(uint256 => LCToken) internal _tokens;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}


    /***********************************************
     * Dependency Functions for Commander Token    *
     ***********************************************/
    /**
     * @dev Adds to tokenID dependency on CTID from contract CTContractAddress.
     * @dev A token can be transfered or burned only if all the tokens it depends on are transferable or burnable, correspondingly.
     * @dev The caller must be the owner, opertaor or approved to use tokenID.
     */
    function setDependence(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    )
        public
        virtual
        override
        approvedOrOwner(tokenID)
    {
        _setDependence(tokenID, CTContractAddress, CTID);
    }

    function _setDependence(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    )
        internal
    {
        // checks that tokenID is not dependent already on CTID
        require(
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] == 0,
            "LCT: tokenID already depends on CTid from CTContractAddress"
        );

        // creates ExternalCommanderToken variable to express the new dependency
        ExternalToken memory newDependency;
        newDependency.tokensCollection = CTContractAddress;
        newDependency.tokenID = CTID;

        // saves the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] =
            _tokens[tokenID].dependencies.length+1;

        // adds dependency
        _tokens[tokenID].dependencies.push(newDependency);

        emit NewDependence(tokenID, CTContractAddress, CTID);
    }

    /**
     * @dev Removes from tokenID the dependency on CTID from contract CTContractAddress.
     */
    function removeDependence(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    ) public virtual override {
        // casts CTContractAddress to type ICommanderToken 
        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // checks that tokenID is indeed dependent on CTID
        require(
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] > 0,
            "LCT: tokenID is not dependent on CTid from contract CTContractAddress"
        );

        // CTContractAddress can always remove the dependency, but the owner 
        // of tokenID can remove it only if CTID is transferable & burnable
        require(
            ( _isAuthorized(msg.sender, tokenID) &&
            CTContract.isTransferable(CTID) &&
            CTContract.isBurnable(CTID) ) ||
            ( msg.sender == CTContractAddress ),
            "LCT: sender is not permitted to remove dependency"
        );

        // gets the index of the token we are about to remove from dependencies
        // we remove '1' because we added '1' when saving the index in setDependence, 
        // see the comment in setDependence for an explanation
        uint256 dependencyIndex = _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID]-1;

        // clears dependenciesIndex for this token
        delete _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID];

        // removes dependency: copy the last element of the array to the place of 
        // what was removed, then remove the last element from the array
        uint256 lastDependecyIndex = _tokens[tokenID].dependencies.length - 1;
        _tokens[tokenID].dependencies[dependencyIndex] = _tokens[tokenID]
            .dependencies[lastDependecyIndex];
        _tokens[tokenID].dependencies.pop();

        emit RemovedDependence(tokenID, CTContractAddress, CTID);
    }

    /**
     * @dev Checks if tokenID depends on CTID from CTContractAddress.
     **/
    function isDependent(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    ) public view virtual override returns (bool) {
        return
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] > 0
                ? true
                : false;
    }

    /**
     * @dev Sets the transferable property of tokenID.
     **/
    function setTransferable(
        uint256 tokenID,
        bool transferable
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].nontransferable = !transferable;
    }

    /**
     * @dev Sets the burnable status of tokenID.
     **/
    function setBurnable(
        uint256 tokenID,
        bool burnable
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].nonburnable = !burnable;
    }

    /**
     * @dev Checks the transferable property of tokenID 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return !_tokens[tokenID].nontransferable;
    }

    /**
     * @dev Checks the burnable property of tokenID 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return !_tokens[tokenID].nonburnable;
    }

    /**
     * @dev Checks if all the tokens that tokenID depends on are transferable or not 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken CTContract = ICommanderToken(_tokens[tokenID]
                .dependencies[i]
                .tokensCollection);
            uint256 CTID = _tokens[tokenID].dependencies[i].tokenID;
            if (!CTContract.isTokenTransferable(CTID)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Checks all the tokens that tokenID depends on are burnable 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken CTContract = ICommanderToken(_tokens[tokenID]
                .dependencies[i]
                .tokensCollection);
            uint256 CTID = _tokens[tokenID].dependencies[i].tokenID;
            if (!CTContract.isTokenBurnable(CTID)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Checks if tokenID can be transferred 
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return isTransferable(tokenID) && isDependentTransferable(tokenID);
    }

    /**
     * @dev Checks if tokenID can be burned.
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return isBurnable(tokenID) && isDependentBurnable(tokenID);
    }

    /********************************************
     * Whitelist functions for Commander Token  *
     ********************************************/

     /**
      * @dev Adds or removes an address from the whitelist of tokenID.
      * @dev tokenID can be transferred to whitelisted addresses even when its set to be nontransferable.
      **/
    function setTransferWhitelist(
        uint256 tokenID, 
        address whitelistAddress,
        bool    isWhitelisted
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].whitelist[whitelistAddress] = isWhitelisted;
    }

    /**
     * @dev Checks if an address is whitelisted.
     **/
    function isAddressWhitelisted(
        uint256 tokenID, 
        address whitelistAddress
    ) public view virtual override returns (bool) {
        return _tokens[tokenID].whitelist[whitelistAddress];
    }

    /**
      * @dev Checks if tokenID can be transferred to addressToTransferTo, without taking its dependence into consideration.
      **/
    function isTransferableToAddress(
        uint256 tokenID, 
        address addressToTransferTo
    ) public view virtual override returns (bool) {
        // either token is transferable (to all addresses, and specifically to 'addressToTransferTo') 
        // or otherwise the address is whitelisted
        return (isTransferable(tokenID) || _tokens[tokenID].whitelist[addressToTransferTo]);
    }
    
    /**
      * @dev Checks if all the dependences of tokenID can be transferred to addressToTransferTo,
      * TODO: is STID (Solider Token ID?) is a clear name here?
      **/
    function isDependentTransferableToAddress(
        uint256 tokenID, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken STContract = ICommanderToken(_tokens[tokenID]
                .dependencies[i]
                .tokensCollection);
            uint256 STID = _tokens[tokenID].dependencies[i].tokenID;

            if (!STContract.isTokenTransferableToAddress(STID, transferToAddress)) {
                return false;
            }
        }

        return true;
    }

    /**
      * @dev Checks if tokenID can be transferred to addressToTransferTo.
      **/
    function isTokenTransferableToAddress(
        uint256 tokenID, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        return isTransferableToAddress(tokenID, transferToAddress) && isDependentTransferableToAddress(tokenID, transferToAddress);
    }


    /***********************************************
     * Locked Token functions                      *
     ***********************************************/
    /**
     * @dev Locks tokenID to token LockingID from LockingContract. Both tokens must have the same owner.
     * @dev 
     * @dev With such a lock in place, tokenID transfer and burn functions can't be called by
     * @dev its owner as long as the locking is in place.
     * @dev 
     * @dev If LckingID is transferred or burned, it also transfers or burns tokenID.
     * @dev If tokenID is nontransferable or unburnable, then a call to the transfer or
     * @dev burn function of the LockingID unlocks the tokenID.
     */
    function lock(
        uint256 tokenID,
        address LockingContract,
        uint256 LockingID
    )
        public
        virtual
        override
        approvedOrOwner(tokenID)
        sameOwner(tokenID, LockingContract, LockingID)
    {
        _lock(tokenID, LockingContract, LockingID);
    }


    /**
     * @dev unlocks a a token.
     * @dev This function must be called from the contract that locked tokenID.
     */
    function unlock(
        uint256 tokenID
    )
        public
        virtual
        override
        onlyContract(address(_tokens[tokenID].locked.tokensCollection))
    {
        _unlock(tokenID);
    }

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(
        uint256 tokenID
    ) public view virtual override returns (address, uint256) {
        return (
            _tokens[tokenID].locked.tokensCollection,
            _tokens[tokenID].locked.tokenID
        );
    }

    /**
     * @dev addLockedToken notifies a Token that another token (LockedID), with the same owner, is locked to it.
     */
    function addLockedToken(
        uint256 tokenID,
        address LockedContract,
        uint256 LockedID
    )
        public
        virtual
        override
        sameOwner(tokenID, LockedContract, LockedID)
        onlyContract(LockedContract)
    {
        // check that LockedID from LockedContract is not locked already to tokenID
        require(
            _tokens[tokenID].lockingsIndex[LockedContract][LockedID] == 0,
            "Locked Token: tokenID is already locked to LockedID from contract LockedContract"
        );

        // create ExternalToken variable to express the locking
        ExternalToken memory newLocking;
        newLocking.tokensCollection = LockedContract;
        newLocking.tokenID = LockedID;

        // save the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenID].lockingsIndex[LockedContract][LockedID] = _tokens[tokenID]
            .lockedTokens
            .length+1;

        // add a locked token
        _tokens[tokenID].lockedTokens.push(newLocking);
    }

    /**
     * @dev removeLockedToken removes a token that was locked to the tokenID.
     */
    function removeLockedToken(
        uint256 tokenID,
        address LockedContract,
        uint256 LockedID
    ) public virtual override {
        // check that LockedID from LockedContract is indeed locked to tokenID
        require(
            _tokens[tokenID].lockingsIndex[LockedContract][LockedID] > 0,
            "Locked Token: LockedID in contract LockedContract is not locked to tokenID"
        );

        // get the index of the token we are about to remove from locked tokens
        // we remove '1' because we added '1' when saving the index in addLockedToken, 
        // see the comment in addLockedToken for an explanation
        uint256 lockIndex = _tokens[tokenID].lockingsIndex[LockedContract][LockedID] - 1;

        // clear lockingsIndex for this token
        _tokens[tokenID].lockingsIndex[LockedContract][LockedID] = 0;

        // remove locking: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastLockingsIndex = _tokens[tokenID].lockedTokens.length - 1;
        _tokens[tokenID].lockedTokens[lockIndex] = _tokens[tokenID].lockedTokens[
            lastLockingsIndex
        ];
        _tokens[tokenID].lockedTokens.pop();

        // notify LockedContract that locking was removed
        ILockedToken(LockedContract).unlock(LockedID);
    }

    // internal locking
    function _lock(
        uint256 tokenID,
        address LockingContract,
        uint256 LockingID
    )
        internal
    {
        // check that tokenID is unlocked
        (address LockedContract, uint256 lockedCT) = isLocked(tokenID);
        require(lockedCT == 0, "Locked Token: tokenID is already locked");

        // Check that LockingID is not locked to tokenID, otherwise the locking enters a deadlock.
        // Warning: A deadlock migt still happen if LockingID might is locked to another token 
        // which is locked to tokenID, but we leave this unchecked, so be careful.
        (LockedContract, lockedCT) = ILockedToken(LockingContract).isLocked(LockingID);
        require(LockedContract != address(this) || lockedCT != tokenID, 
            "Locked Token: Deadlock deteceted! LockingID is locked to tokenID");

        // lock token
        _tokens[tokenID].locked.tokensCollection = LockingContract;
        _tokens[tokenID].locked.tokenID = LockingID;

        // nofity LockingID in LockingContract that tokenID is locked to it
        ILockedToken(LockingContract).addLockedToken(LockingID, address(this), tokenID);

        emit NewLocking(tokenID, LockingContract, LockingID);
    }

    // internal unlocking
    function _unlock(
        uint256 tokenID
    )
        internal
    {
        // remove locking
        _tokens[tokenID].locked.tokensCollection = address(0);
        _tokens[tokenID].locked.tokenID = 0;

        emit Unlocked(tokenID);
    }


    /**************************************************************
     * Burn and setTokenURI functions are needed in both ICommanderToken and ILockedToken  *
     **************************************************************/
    /**
     * @dev burns tokenID.
     * @dev isTokenBurnable must return 'true'.
     **/
    function burn(uint256 tokenID) public virtual override(ICommanderToken, ILockedToken) approvedOrOwner(tokenID) {
        require(isTokenBurnable(tokenID), "LCT: the token or one of its Commander Tokens are not burnable");

        // burn each token locked to tokenID 
        // if the token is unburnable, then simply unlock it
        for (uint i; i < _tokens[tokenID].lockedTokens.length; i++) {
            ILockedToken STContract = ILockedToken(_tokens[tokenID]
                .lockedTokens[i]
                .tokensCollection);
            uint256 STID = _tokens[tokenID].lockedTokens[i].tokenID;
            STContract.burn(STID);
        }

        // 'delete' in solidity doesn't work on mappings, so we delete the lockingsIndex mapping items manually
        for (uint i=0; i<_tokens[tokenID].lockedTokens.length; i++) {
            ExternalToken memory CT =  _tokens[tokenID].lockedTokens[i];
            delete _tokens[tokenID].lockingsIndex[address(CT.tokensCollection)][CT.tokenID];
        }


        // 'delete' in solidity doesn't work on mappings, so we delete the dependenciesIndex mapping items manually
        for (uint i=0; i<_tokens[tokenID].dependencies.length; i++) {
            ExternalToken memory CT =  _tokens[tokenID].dependencies[i];
            delete _tokens[tokenID].dependenciesIndex[address(CT.tokensCollection)][CT.tokenID];
        }

        // delete the rest
        delete _tokens[tokenID];

        // TODO: whitelist of Commander Token is NOT deleted since we don't hold the indices of this mapping
        // TODO: consider fixing this in a later version
    }

    /**
     * @dev sets the URI of tokenID.
     * @dev isTokenBurnable must return 'true'.
     **/
     function setTokenURI(uint256 tokenID, string calldata tokenURI) public virtual approvedOrOwner(tokenID) {
        _setTokenURI(tokenID, tokenURI);
     }

    /***********************************************
     * Overrided functions from ERC165 and ERC721  *
     ***********************************************/
     /**
     * @dev we reimplement this function to add the isApproveOwnerOrLockingContract modifier
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenID
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenID) {
        //solhint-disable-next-line max-line-length

        ERC721._transfer(from, to, tokenID);
    }

    /**
     * @dev we reimplement this function to add the isApproveOwnerOrLockingContract modifier
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenID,
        bytes memory data
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenID) {

        _safeTransfer(from, to, tokenID, data);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenID,
        uint256 batchSize
    ) internal virtual override {
        ERC721EnumerableURIStorage._beforeTokenTransfer(from, to, tokenID, batchSize);

        require(
                isTransferableToAddress(tokenID, to),
                "LCT: the token status is set to nontransferable"
            );

        require(
                isDependentTransferableToAddress(tokenID, to),
                "LCT: the token depends on at least one nontransferable token"
            );

        // transfer each token locked to tokenID 
        // if the token is nontransferable, then simply unlock it
        for (uint i; i < _tokens[tokenID].lockedTokens.length; i++) {
            ILockedToken STContract = ILockedToken(_tokens[tokenID]
                .lockedTokens[i]
                .tokensCollection);
            uint256 STID = _tokens[tokenID].lockedTokens[i].tokenID;
            STContract.transferFrom(from, to, STID);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721EnumerableURIStorage, IERC165) returns (bool) {
        return
            interfaceId == type(ICommanderToken).interfaceId ||
            interfaceId == type(ILockedToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
