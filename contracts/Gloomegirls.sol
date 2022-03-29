//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@rari-capital/solmate/src/tokens/ERC721.sol";

contract Gloomegirls is ERC721, Ownable {
  using SafeMath for uint256;
  
  uint256 public constant RESERVE = 100;
  uint256 public constant MAX_ELEMENTS = 10000;

  uint256 public PRICE = 60 ether;
  bool public locked = false;

  uint256 private _counter;

  uint256 private startingBlockNumber;
  bool private PAUSE = false;
  bool private hasReserved = false;

  address public constant payoutAddress = 0x974Bb2a200769556e46b18Bbb1aE73af298cB2DF;
  address public constant devAddress = 0x1B930f5F02DBf357A750E951Eb6D8b9d768FB14B;
  
  string public baseTokenURI;

  event PauseEvent(bool pause);
  event WelcomeToGloomeGirl(uint256 indexed id);

  constructor(string memory _defaultBaseURI) ERC721("Gloomegirls", "GEG") {
    setBaseURI(_defaultBaseURI);
    startingBlockNumber = block.number;
  }

  /**
    * @dev Returns whether `tokenId` exists.
    *
    * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
    *
    * Tokens start existing when they are minted (`_mint`),
    * and stop existing when they are burned (`_burn`).
    */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return ownerOf[tokenId] != address(0);
  }

  /**
    * @dev Returns whether `spender` is allowed to manage `tokenId`.
    *
    * Requirements:
    *
    * - `tokenId` must exist.
    */
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    address owner = ownerOf[tokenId];
    return (spender == owner || getApproved[tokenId] == spender || isApprovedForAll[owner][spender]);
  }

  /**
  * @dev Throws if the contract is already locked
  */
  modifier notLocked() {
    require(!locked, "Contract already locked.");
    _;
  }

  modifier saleIsOpen {
    require(_totalSupply() <= MAX_ELEMENTS, "Soldout!");
    require(!PAUSE, "Sales not open");
    _;
  }

  function setBaseURI(string memory _baseTokenURI) public onlyOwner notLocked {
    baseTokenURI = _baseTokenURI;
  }

  function _baseURI() internal view virtual returns (string memory) {
    return baseTokenURI;
  }

  /**
  * @dev Returns the tokenURI if exists
  * See {IERC721Metadata-tokenURI} for more details.
  */
  function tokenURI(uint256 _tokenId) public view virtual override(ERC721) returns (string memory) {
    return getTokenURI(_tokenId);
  }

  function getTokenURI(uint256 _tokenId) public view returns (string memory) {
    require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
    string memory base = baseTokenURI;

    if (_tokenId > _totalSupply()) {
      return bytes(base).length > 0 ? string( abi.encodePacked(base, "0.json") ) : "";
    }

    return bytes(base).length > 0 ? string( abi.encodePacked(base, uintToString(_tokenId), ".json") ) : "";
  }

  function _totalSupply() internal view returns (uint) {
    // return _tokenIds.current();
    return _counter;
  }

  function totalSupply() public view returns (uint256) {
    return _totalSupply();
  }

  /**
   * @dev See {IERC721Enumerable-tokenByIndex
   */
  function tokenByIndex(uint256 index) public view virtual returns (uint256) {
    require(_exists(index), "approved query for nonexistent token");
    return index;
  }

  /**
  * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
  */
  function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256 token) {
      require(index < balanceOf[owner], "owner index out of bounds");
      uint256 count;
      for (uint256 i; i < _counter; i++) {
        if (ownerOf[i] == owner) {
          if (count == index) return i;
          else count++;
        }
      }
      require(false, "owner index out of bounds");
  }

  function mint() public payable saleIsOpen {
    require(_totalSupply() + 1 <= MAX_ELEMENTS - RESERVE, "Max limit reached");
    require(msg.value >= PRICE, "Value below price");

    _safeMint(msg.sender, _counter);

    emit WelcomeToGloomeGirl(_counter);

    _counter++;
  }

  function mintMultiple(uint _count) public payable saleIsOpen {
    require(_totalSupply() + _count <= MAX_ELEMENTS - RESERVE, "Max limit reached");
    require(msg.value >= price(_count), "Value below price");

    for (uint256 i; i < _count; i++) {
      _safeMint(msg.sender, _counter);

      emit WelcomeToGloomeGirl(_counter);

      _counter++;
    }
  }

  function burn(uint256 tokenId) public virtual {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "caller is not owner nor approved");
    _burn(tokenId);
  }

  function price(uint256 _count) public view returns (uint256) {
    return PRICE.mul(_count);
  }

  function setPause(bool _pause) public onlyOwner {
    PAUSE = _pause;
    emit PauseEvent(PAUSE);
  }

  /**
  * Reserve some for future activities and for supporters
  */
  function reserveForOwner() public onlyOwner {
    require(!hasReserved, 'Sorry, reserve already happened.');

    for (uint256 i; i < RESERVE; i++) {
      _safeMint(msg.sender, _counter + i);

      emit WelcomeToGloomeGirl(_counter + i);
    }

    _counter += RESERVE;

    hasReserved = true;
  }

  /**
  * @dev Sets the prices for minting - in case of cataclysmic ETH price movements
  */
  function setPrice(uint256 _price) external onlyOwner notLocked {
    require(_price > 0, "Invalid prices.");
    PRICE = _price;
  }

  function withdrawAll() public onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0);
    _widthdraw(devAddress, balance.mul(12).div(100));
    _widthdraw(payoutAddress, address(this).balance);
  }

  function _widthdraw(address _address, uint256 _amount) private {
    (bool success, ) = _address.call{value: _amount}("");
    require(success, "Transfer failed.");
  }

  /**
  * @dev locks the contract (prevents changing the metadata base uris)
  */
  function lock() public onlyOwner notLocked {
    require(bytes(baseTokenURI).length > 0, "Thou shall not lock prematurely!");
    require(_totalSupply() == MAX_ELEMENTS, "Not all Gloomegirls are minted yet!");
    locked = true;
  }

  function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
    uint8 i = 0;
    while(i < 32 && _bytes32[i] != 0) {
        i++;
    }
    bytes memory bytesArray = new bytes(i);
    for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
        bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }

  function uintToBytes(uint v) pure private returns (bytes32 ret) {
    if (v == 0) {
        ret = '0';
    }
    else {
        while (v > 0) {
            ret = bytes32(uint(ret) / (2 ** 8));
            ret |= bytes32(((v % 10) + 48) * 2 ** (8 * 31));
            v /= 10;
        }
    }
    return ret;
  }

  function uintToString(uint v) pure private returns (string memory ret) {
    return bytes32ToString(uintToBytes(v));
  }

  /**
  * @dev Do not allow renouncing ownership
  */
  function renounceOwnership() public override(Ownable) onlyOwner {}
}