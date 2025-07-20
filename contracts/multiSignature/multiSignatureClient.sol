// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// interface to
interface IMultiSignature {
    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256);
}

contract multiSignatureClient {
    uint256 private constant multiSignaturePosition = uint256(keccak256("org.multiSignature.storage.position1111"));
    uint256 private constant defaultIndex = 0;

    constructor(address multiSignature) public {
        require(multiSignature != address(0), "multiSignatureClient : Multiple signature contract address is zero!");
        saveValue(multiSignaturePosition, uint256(multiSignature));
    }

    function getMultiSignatureAddress() public view returns (address) {
        return address(getValue(multiSignaturePosition));
    }

    modifier validCall() {
        checkMultiSignature();
        _;
    }

    function checkMultiSignature() internal view {
        uint256 value;
        assembly {
            value := callvalue()
        }
        // user + this client address to calculate the msgHash
        bytes32 msgHash = keccak256(abi.encodePacked(msg.sender, address(this)));

        // get the multi-signature address from storage
        address multiSign = getMultiSignatureAddress();
        uint256 newIndex = IMultiSignature(multiSign).getValidSignature(msgHash, defaultIndex);
        require(newIndex > defaultIndex, "multiSignatureClient : This tx is not aprroved");
    }

    function saveValue(uint256 position, uint256 value) internal {
        assembly {
            sstore(position, value)
        }
    }

    function getValue(uint256 position) internal view returns (uint256 value) {
        assembly {
            value := sload(position)
        }
    }
}
