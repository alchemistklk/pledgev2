// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./multiSignatureClient.sol";

library whiteListAddress {
    // add address to whiteList
    function addWhiteListAddress(address[] storage whiteList, address temp) internal {
        if (!isEligibleAddress(whiteList, temp)) {
            whiteList.push(temp);
        }
    }

    // remove tips: use behind address to replace the previous address, then pop last one
    // if the whiteList doesn't contain many addresses, we can use list to store, otherwise we can use map to store
    function removeWhiteListAddress(address[] storage whiteList, address temp) internal returns (bool) {
        uint256 len = whiteList.length;
        uint256 i = 0;
        for (; i < len; i++) {
            if (whiteList[i] == temp) {
                break;
            }
        }
        if (i < len) {
            if (i != len - 1) {
                whiteList[i] = whiteList[len - 1];
            }
            whiteList.pop();
            return true;
        }
        return false;
    }

    function isEligibleAddress(address[] memory whiteList, address temp) internal pure returns (bool) {
        uint256 len = whiteList.length;
        for (uint256 i = 0; i < len; i++) {
            if (whiteList[i] == temp) {
                return true;
            }
        }
        return false;
    }
}

contract multiSignature is multiSignatureClient {
    uint256 private constant defaultIndex = 0;

    using whiteListAddress for address[];

    // store the owners of the multi-signature, used to check if the caller is in the ownerList
    address[] public signatureOwners;
    uint256 public threshold;

    // struct to store the application info and its signatures
    struct signatureInfo {
        // applicant has the signatures situation
        address applicant;
        address[] signatures;
    }

    // the most important part of multi-signature, store the (user + address) as key to record the right of accessing
    // record the user address + signatures he gain
    mapping(bytes32 => signatureInfo[]) public signatureMap;

    event TransferOwner(address indexed sender, address indexed oldOwner, address indexed newOwner);
    event CreateApplication(address indexed from, address indexed to, bytes32 indexed msgHash);
    event SignApplication(address indexed from, bytes32 indexed msgHash, uint256 index);
    event RevokeApplication(address indexed from, bytes32 indexed msgHash, uint256 index);

    // constructor to initialize the multi-signature contract
    // @param owners: the owners of the multi-signature
    // @param limitedSignNum: the threshold of the multi-signature
    // parent contract: multiSignatureClient establishes the connection between client contract and multi-signature governance system.
    constructor(address[] memory owners, uint256 limitedSignNum) public multiSignatureClient(address(this)) {
        require(
            owners.length >= limitedSignNum, "Multiple Signature : Signature threshold is greater than owners' length!"
        );
        signatureOwners = owners;
        threshold = limitedSignNum;
    }

    // transfer the owner of the multi-signature
    function transferOwner(uint256 index, address newOwner) public onlyOwner validCall {
        require(index < signatureOwners.length, "Multiple Signature : Owner index is overflow!");
        emit TransferOwner(msg.sender, signatureOwners[index], newOwner);
        signatureOwners[index] = newOwner;
    }

    // create a new application
    function createApplication(address to) external returns (uint256) {
        bytes32 msghash = getApplicationHash(msg.sender, to);
        uint256 index = signatureMap[msghash].length;
        signatureMap[msghash].push(signatureInfo(msg.sender, new address[](0)));
        emit CreateApplication(msg.sender, to, msghash);
        return index;
    }

    function signApplication(bytes32 msghash) external onlyOwner validIndex(msghash, defaultIndex) {
        emit SignApplication(msg.sender, msghash, defaultIndex);
        signatureMap[msghash][defaultIndex].signatures.addWhiteListAddress(msg.sender);
    }

    function revokeSignApplication(bytes32 msghash) external onlyOwner validIndex(msghash, defaultIndex) {
        emit RevokeApplication(msg.sender, msghash, defaultIndex);
        signatureMap[msghash][defaultIndex].signatures.removeWhiteListAddress(msg.sender);
    }

    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256) {
        // get the current signature situation
        signatureInfo[] storage info = signatureMap[msghash];
        // once the signature is enough, return the index + 1
        for (uint256 i = lastIndex; i < info.length; i++) {
            if (info[i].signatures.length >= threshold) {
                return i + 1;
            }
        }
        return 0;
    }

    function getApplicationInfo(bytes32 msghash, uint256 index)
        public
        view
        validIndex(msghash, index)
        returns (address, address[] memory)
    {
        signatureInfo memory info = signatureMap[msghash][index];
        return (info.applicant, info.signatures);
    }

    function getApplicationCount(bytes32 msghash) public view returns (uint256) {
        return signatureMap[msghash].length;
    }

    function getApplicationHash(address from, address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to));
    }

    modifier onlyOwner() {
        require(signatureOwners.isEligibleAddress(msg.sender), "Multiple Signature : caller is not in the ownerList!");
        _;
    }

    modifier validIndex(bytes32 msghash, uint256 index) {
        require(index < signatureMap[msghash].length, "Multiple Signature : Message index is overflow!");
        _;
    }
}
