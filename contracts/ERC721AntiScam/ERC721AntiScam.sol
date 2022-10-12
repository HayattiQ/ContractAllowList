// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "erc721a/contracts/ERC721A.sol";
import './IERC721AntiScam.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "../proxy/interface/IContractAllowListProxy.sol";

/// @title AntiScam機能付きERC721A
/// @dev Readmeを見てください。

abstract contract ERC721AntiScam is ERC721A, IERC721AntiScam, Ownable {

    IContractAllowListProxy CAL;

    /*//////////////////////////////////////////////////////////////
    ロック変数。トークンごとに個別ロック設定を行う
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => LockStatus) internal _lockStatus;
    LockStatus public contractLockStatus = LockStatus.CalLock;
    uint256 public CALLevel = 1;

    /*///////////////////////////////////////////////////////////////
    ロック機能ロジック
    //////////////////////////////////////////////////////////////*/

    function getLockStatus(uint256 tokenId) public virtual view returns (LockStatus) {
        require(_exists(tokenId), "AntiScam: locking query for nonexistent token");
        return _lockStatus[tokenId];
    }

    function lock(LockStatus level, uint256 id) external virtual onlyOwner {
        _lockStatus[id] = level;
    }

    function getLocked(address to, uint256 tokenId) public virtual view returns(bool) {
        LockStatus status = contractLockStatus;
        if (uint(_lockStatus[tokenId]) >= 1) {
            status = _lockStatus[tokenId];
        }

        if (status == LockStatus.UnLock) {
            return false;
        } else if (status == LockStatus.AllLock)  {
            return true;
        } else if (status == LockStatus.CalLock) {
            if (CAL.isAllowed(to, CALLevel)) {
                return false;
            } else {
                return true;
            }
        } else {
            revert("LockStatus is invalid");
        }
    }

    function setContractAllowListLevel(uint256 level) external onlyOwner{
        CALLevel = level;
    }

    function setContractLockStatus(LockStatus _status) external onlyOwner {
       require(_status != LockStatus.UnSet, "AntiScam: contract lock status can not set UNSET");
       contractLockStatus = _status;
    }


    /*///////////////////////////////////////////////////////////////
                              OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function approve(address to, uint256 tokenId) public payable virtual override {
        require (getLocked(to, tokenId) == false, "Can not approve locked token");
        super.approve(to, tokenId);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 /*quantity*/
    ) internal virtual override {
        // if it is a Transfer or Burn, we always deal with one token, that is startTokenId
        if (from != address(0)) {
            // token should not be locked or msg.sender should be unlocker to do that
            require(getLocked(to, startTokenId) == false , "LOCKED");
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721AntiScam).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}