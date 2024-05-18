// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

library StringUtils {
    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    /**
     * @dev Checks whether a character is in a string.
     * @param str The input string to check.
     * @param ch The character to search for in the string.
     * @return A boolean value indicating whether the character is in the string or not.
     */
    function isCharInString(string memory str, bytes1 ch) public pure returns(bool) {
        bytes memory byteStr = bytes(str);
        for(uint i = 0; i < byteStr.length; i++) {
            if (byteStr[i] == ch) {
                return true;
            }
        }
        return false;
    }
}
