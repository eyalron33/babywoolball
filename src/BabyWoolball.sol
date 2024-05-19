// contracts/BabyWoolball.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./LCT.sol";
import "./StringUtils.sol";
import "./interfaces/IBabyWoolball.sol";
import "./plonk_vk.sol";

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @dev Baby Woolball Registry contract
 * @dev A name system for humans only
 */
contract BabyWoolball is IBabyWoolball, LCT, Ownable {
    // NONE = uninitiated
    // HUMAN - a human name, e.g., "neiman#"
    // SUBNAME - "car.neiman#"
    enum NameType{ NONE, HUMAN, SUBNAME }

    // The proof of humanity contract
    UltraVerifier verifyHumanContract;

    // The Merkle root of the set of trusted entities for makign proof of humanity
    bytes32 trustKernelHash;

    struct Name {
        string      name;
        NameType    nameType;
        uint256     expirationTimestamp;
        address     creatorWallet;  // Creator's wallet address (i.e., which wallet address created the name?)
        uint256     creatorNameID;  // Creator's Name ID (only for subnames)
        address     data;           // Contract holding the name's data
        uint256[]   subnames;       // Array of subnames
        bool        verified;       // true if name submitted a proof of humanity
        bytes32     pubkeyX;        // X coordinate of the public key of the name holder
        bytes32     pubkeyY;        // Y coordinate of the public key of the name holder
    }

    // A table of nameID -> Name structure
    mapping(uint256 => Name) private _names;

    modifier onlyNameOwner(uint256 nameID) {
        require(ownerOf(nameID) == msg.sender, "Baby  Woolball: sender is not the owner of the name.");
        _;
    }

    modifier nameIDExists(uint256 nameID) {
        require(_names[nameID].expirationTimestamp > block.timestamp, "Baby Woolball: nameID doesn't exist");
        _;
    }

    // More forbidden characters will be add in the future
    modifier validName(string calldata name) {
        // TODO: can this be made one line with regular expressions?
        require( !StringUtils.isCharInString(name, "."), "Baby Woolball: name can't have '.' characters within in"  );
        require( !StringUtils.isCharInString(name, "#"), "Baby Woolball: name can't have '#' characters within in"  );
        require( !StringUtils.isCharInString(name, ":"), "Baby Woolball: name can't have ':' characters within in"  );
        _;
    }

    modifier isSubname(uint256 nameID) {
        require(
            _names[nameID].nameType == NameType.SUBNAME
            , "nameID is not of a subname");
        _;
    }

    modifier isVerified(uint256 nameID) {
        require(
            _names[nameID].verified
            , "nameID is not of verified as human yet");
        _;
    }

    /**
     * @dev Constructs a new Baby Woolball registry.
     */
    constructor(
        string memory name,
        string memory symbol,
        address verifierContract
    ) LCT(name, symbol) {
        verifyHumanContract = UltraVerifier(verifierContract);
    }

    // Create a new human name with suffix "#", e.g. "neiman#"
    function newHumanName(
        string calldata name,
        address creator,
        uint256 expirationTimestamp
    ) public virtual validName(name) onlyOwner() returns (uint256) {
        uint256 nameID = uint256(sha256(abi.encodePacked(name, "#")));

        // Check the name is unregistered
        require( _names[nameID].expirationTimestamp < block.timestamp, "Baby Woolball: name is already registered");

        // Check the expirationTimestamp is not more than 30 days in the future
        // It can only be extended with a proof of humanity
        require( expirationTimestamp < (block.timestamp + 30 days), "Baby Woolball: initial expirationTimestamp can be at most 30 days in the future");

        // Check the creator doesn't have a name already
        require( balanceOf(creator) == 0, "Baby Woolball: the address already has a name, only one name per address is allwed");

        _mint(creator, nameID);

        _names[nameID].name = name;
        _names[nameID].nameType = NameType.HUMAN;
        _names[nameID].expirationTimestamp = expirationTimestamp;
        _names[nameID].creatorWallet = creator;

        emit humanNameCreated(name, creator, expirationTimestamp);

        return nameID;
    }

    function verifyHuman(
        bytes calldata proof,
        uint256 nameID,
        uint256 verifiedForTimestamp
    ) public virtual nameIDExists(nameID) {
        bytes32[] memory publicInputs = new bytes32[](6);

        // Prepare the public data
        publicInputs[0] = _names[nameID].pubkeyX;
        publicInputs[1] = _names[nameID].pubkeyY;
        publicInputs[2] = trustKernelHash;
        publicInputs[3] = bytes32(verifiedForTimestamp);
        publicInputs[4] = bytes32(uint256(uint160(ownerOf(nameID))) << 96);
        publicInputs[5] = bytes32(nameID);

        bool verificationResult = verifyHumanContract.verify(proof, publicInputs);

        require(verificationResult, "Baby Woolball: proof failes");

        // Update name data
        _names[nameID].verified = true;

        if (verifiedForTimestamp < _names[nameID].expirationTimestamp)
            _names[nameID].expirationTimestamp = verifiedForTimestamp;
    }

    // Create a new subname, e.g. "car.neiman#"
    function newSubname(
        uint256 nameID,
        string calldata subname
    ) validName(subname) onlyNameOwner(nameID) isVerified(nameID) public virtual returns (uint256) {
        uint256 subnameID = uint256(sha256(abi.encodePacked(subname, "." , Strings.toString(nameID))));

        // check subname doesn't exist
        require(_names[subnameID].nameType == NameType.NONE, "Baby Woolball: subname exists already");

        _mint(ownerOf(nameID), subnameID);

        _names[subnameID].name = subname;
        _names[subnameID].nameType = NameType.SUBNAME;
        _names[subnameID].expirationTimestamp = _names[nameID].expirationTimestamp;
        _names[subnameID].creatorNameID = nameID;

        // subnames are locked to names so they will be transferred when the name is transferred
        _lock(subnameID, address(this), nameID);

        // update subnames list
        _names[nameID].subnames.push(subnameID);

        // emit new subname
        emit subnameCreated(subname, nameID, subnameID);

        return subnameID;
    }

    // Removes an existing subname
    function removeSubname(
        uint256 subnameID
    ) onlyNameOwner(subnameID) public virtual {
        require(_names[subnameID].expirationTimestamp > 0, "Baby Woolball: Subname is already removed");

        _removeSubname(subnameID);
    }

    // Expired subnames are practically considered not registered, but still occupy
    // blockchains space. This functions lets anyone clear the expired subnames of a name.
    function clearExpiredSubnames(uint256 nameID) public virtual nameIDExists(nameID) {
        for (uint256 i = 0; i < _names[nameID].subnames.length; i++) {
            // handle the case that name.subnames.length decreased during the loop
            // running since a subname was removed
            if (i < _names[nameID].subnames.length)
                break;

            Name memory subname = _names[_names[nameID].subnames[i]];

            // Check if the subname expired
            if (subname.expirationTimestamp > block.timestamp) {
                // Swap with the last element and then pop
                _names[nameID].subnames[i] = _names[nameID].subnames[_names[nameID].subnames.length - 1];
                _names[nameID].subnames.pop();
            }
        }
    }

    // TODO: transfer subnames and names

    /**
     * @dev Sets the data contract address for the specified name.
     * @param nameID The name to update.
     * @param dataContract The address of the data contract.
     */
    function setDataContract(
        uint256 nameID,
        address dataContract
    ) public virtual onlyNameOwner(nameID) isVerified(nameID) {
        _names[nameID].data = dataContract;
    }

    function setPubkey(
        uint256 nameID,
        bytes32 pubkeyX,
        bytes32 pubkeyY
    ) public virtual onlyNameOwner(nameID) {
        _names[nameID].pubkeyX = pubkeyX;
        _names[nameID].pubkeyY = pubkeyY;
    }

    /**
     * @dev Returns the address of the data contract for the specified name.
     * @param nameID The specified name.
     * @return address of the data contract.
     */
    function data(uint256 nameID) public view virtual nameIDExists(nameID) returns (address) {
        return _names[nameID].data;
    }

    function getExpirationTimestamp(uint256 nameID) public view virtual returns (uint256) {
        return _names[nameID].expirationTimestamp;
    }

    // Returns the amount of registered subnames.
    // Remark: the number might also include expired subnames.
    function subnamesAmount(uint256 nameID) public view virtual returns (uint256) {
        return _names[nameID].subnames.length;
    }

    function subnameIndex(uint256 nameID, uint256 index) public view virtual returns (uint256) {
        return _names[nameID].subnames[index];
    }

    function getParentID(uint256 nameID) public view virtual isSubname(nameID)
    returns (uint256)
    {
        return _names[nameID].creatorNameID;
    }

    // uint8 representes ENUM
    function getNameType(uint256 nameID) public view virtual returns (uint8) {
        return uint8(_names[nameID].nameType);
    }

    function getName(uint256 nameID) nameIDExists(nameID) public view returns (string memory) {
        string memory name;

        if (_names[nameID].nameType == NameType.HUMAN)
            name = _names[nameID].name;
        else {
            // name is a Subname
            name = _names[nameID].name;
            uint256 creatorSubnameID = _names[nameID].creatorNameID;

            do {
                name = string.concat(name, ".", _names[creatorSubnameID].name);

                // update creatorSubnameID to the parent of the current part of the name
                creatorSubnameID = _names[creatorSubnameID].creatorNameID;
            } while (creatorSubnameID > 0);
        }

        return name;
    }

    // Removes an existing subname
    function _removeSubname(
        uint256 subnameID
    ) private {
        // remove subname from creatorNameID list
        uint256 parentID = _names[subnameID].creatorNameID;

        for (uint256 i = 0; i < _names[parentID].subnames.length; i++) {
            if (_names[parentID].subnames[i] == subnameID) {
                // Swap with the last element and then pop
                _names[parentID].subnames[i] = _names[parentID].subnames[_names[parentID].subnames.length - 1];
                _names[parentID].subnames.pop();
            }
        }

        // set expiration date of subname to 0
        _names[subnameID].expirationTimestamp = 0;

        // set type of subname to NONE
        _names[subnameID].nameType = NameType.NONE;

        // remove creator nameID
        _names[subnameID].creatorNameID = 0;

        // unlock subname TODO
    }

}
