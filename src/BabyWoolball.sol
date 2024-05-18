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
contract BabyWoolball is IWoolball, LCT, Ownable {
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
            names[nameID].nameType == NameType.SUBNAME
            , "nameID is not of a subname");
        _;
    }

    modifier isVerified(uint256 nameID) {
        require(
            names[nameID].verified
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
        verifyHuman = UltraVerifier(verifierContract);
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

        emit NewHumanName(name, nameID, creator);

        return nameID;
    }

    function verifyHuman(
        bytes calldata proof,
        uint256 nameID,
        uint256 verifiedForTimestamp
    ) {
        bytes32[] memory publicInputs = new bytes32[](6);

        // Prepare the public data
        publicInputs[0] = _names[nameID].pubkeyX;
        publicInputs[1] = _names[nameID].pubkeyY;
        publicInputs[2] = trustKernelHash;
        publicInputs[3] = bytes32(verifiedForDate);
        publicInputs[4] = bytes32(uint256(uint160(ownerOf(nameID))) << 96);
        publicInputs[5] = bytes32(nameID);

        verificationResult = verifyHuman(proof, publicInputs);

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

        // update subdomains list
        _names[nameID].subdomains.push(subnameID);

        // emit new subname
        emit NewSubname(subname, nameID, subnameID);

        return subnameID;
    }

    // Removes an existing subname
    function removeSubname(
        uint256 subnameID,
    ) onlyNameOwner(subnameID) public virtual {
        require(_names[nameID].expirationTimestamp > 0, "Baby Woolball: Subname is already removed");

        _removeSubname(subnameID);
    }

    // Expired subdomains are practically considered not registered, but still occupy
    // blockchains space. This functions lets anyone clear the expired subdomains of a name.
    function clearExpiredSubnames(uint256 nameID) {
        Name name = _names[nameID];

        for (uint256 i = 0; i < name.subnames.length; i++) {
            // handle the case that name.subnames.length decreased during the loop
            // running since a subdomain was removed
            if (i < name.subnames.length)
                break;

            Name subdomain = _names[name.subnames[i]];

            // Check if the subdomain expired
            if (subdomain..expirationTimestamp > block.timestamp) {
                // Swap with the last element and then pop
                parentName.subnames[i] = parentName.subnames[subnames.length - 1];
                parentName.subnames.pop();
            }
        }
    }

    // TODO: transfer subdomains and names

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

        // emit NewdataContract(nameID, dataContract);
    }

    function setPubkey(
        uint256 nameID,
        byes32 pubkeyX,
        byes32 pubkeyY
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

    function expirationTimestamp(uint256 nameID) public view virtual returns (uint256) {
        return _names[nameID].expirationTimestamp;
    }

    // Returns the amount of registered subnames.
    // Remark: the number might also include expired subnames.
    function subnamesAmount(uint256 nameID) public view virtual returns (uint256) {
        return _names[nameID].subdomains.length;
    }

    function subnameIndex(uint256 nameID, uint256 index) public view virtual returns (uint256) {
        return _names[nameID].subnames[index];
    }

    function parentID(uint256 nameID) public view virtual isSubname(nameID)
    returns (uint256)
    {
        return _names[nameID].creatorNameID;
    }

    // uint8 representes ENUM
    function getNameType(uint256 nameID) public view virtual returns (uint8) {
        return uint8(_names[nameID].nameType);
    }

    function getName(uint256 nameID) nameIDExists(nameID) public view returns (string memory) {
        if (_names[nameID].nameType == NameType.HUMAN)
            return _names[nameID].name;
        else {
            // name is a Subname
            string subname = _names[nameID].name;
            uint256 creatorSubnameID = _names[nameID].creatorNameID;

            do {
                subname.concat(subname, ".", _names[creatorSubnameID].name);

                // update creatorSubnameID to the parent of the current part of the name
                creatorSubnameID = _names[creatorSubnameID].creatorNameID;
            } while (creatorSubnameID > 0);
        }
    }

    // Removes an existing subname
    function _removeSubname(
        uint256 subnameID,
    ) private {
        // remove subdomain from creatorNameID list
        uint256 parentID = _names[subnameID].creatorNameID;
        Name parentName = _names[parentID];

        for (uint256 i = 0; i < parentName.subnames.length; i++) {
            if (parentName.subnames[i] == subnameID) {
                // Swap with the last element and then pop
                parentName.subnames[i] = parentName.subnames[subnames.length - 1];
                parentName.subnames.pop();
            }
        }

        // set expiration date of subdomain to 0
        _names[subnameID].expirationTimestamp = 0

        // set type of subdomain to NONE
        _names[subnameID].nameType = NameType.NONE

        // remove creator nameID
        names[subnameID].creatorNameID = 0;

        _mint(ownerOf(nameID), subnameID);

        // unlock subdomain TODO
        _lock(subnameID, address(this), nameID);

        // emit new subname TODO: add to events list
        emit RemovedSubname(subname, nameID, subnameID);
    }

}
