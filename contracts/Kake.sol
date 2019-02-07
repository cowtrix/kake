pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";

/********************************************************************************************
 *  Kake is a set of smart contracts for envy-free division of ERC20 and ERC721 tokens.
 *  While dividing a single fungible asset is a simple operation, division of a pool of
 *  fungible and non-fungible assets is a much trickier problem. This project references
 *  this paper (https://arxiv.org/abs/1604.03655) which described an envy-free solution for
 *  [n] participants. While this paper does apply only to heterogeneous divisible goods,
 *  which ERC720 tokens are not, good solutions should still be able to be found if they
 *  exist. How many exist depends entirely on contextual factors.
 *  It should also be noted that the maximum number of steps can be as high
 *  as n^n^n^n^n^n, which is a fantastically bad complexity. However, we can thankfully
 *  rely on the rapidly decreasing value of the remaining portion. At some point, the cost  
 *  of continuing to argue over crumbs will outweigh the return, and the contract can be 
 *  burned with the optimally minimal amount of waste inside. This will usually be zero, as
 *  fungible tokens will be more common in the later segmentations.
 *  At any point before contract finalisation, any participant can refund the contract,
 *  which will pay back all tokens to their original owners. In some cases, a fair split
 *  will not be found and this action is reasonable and necessary. Kake only guarantees
 *  that if the contract is finalised, all participants were treated fairly.
 *******************************************************************************************/
contract Kake is IERC721Receiver
{
  struct ERC20Record      // A record of an ERC20 deposit into this contract, for refunding
  {
    address OwnerAddress;
    address TokenAddress;
    uint Value;
  }
  
  struct ERC721Record     // A record of an ERC721 deposit into this contract, for refunding
  {
    address OwnerAddress;
    address TokenAddress;
    uint256 TokenID;
    bytes Data;
  }

  struct UserState      // Tracking of permissions for user
  {
    bool Locked;        // If locked, a user has finalised their contribution to the payload
    mapping(uint => uint) SplitPermissions; // Maps the index of a segment to a count of how many times the user is allowed to split that segment
    mapping(uint => bool) CreatePermissions;// Indexes that the user is allowed to move a split into
    uint[] PickPermissions;
  }

  struct Balance  // Container of ownerless ERC20 and ERC721 tokens
  {
    mapping(address => uint) ERC20Balance;
    mapping(address => uint256[]) ERC721Balance;
    address Owner;
  }

  enum ESTATE
  {
    DEPOSITING,
    SPLITTING,
    FINALISING,
    ABORTED
  }

  ESTATE State = ESTATE.DEPOSITING;
  uint _stepCounter = 0;

  address[] _users; // All authorised participants
  mapping(address=>UserState) _userState; // State of all participants

  // This is where we store the records of deposits, as well as easy balance lookups
  ERC20Record[] _erc20s;
  mapping(address => uint) _erc20Balance;
  ERC721Record[] _erc721s;
  mapping(address => uint256[]) _erc721Balance;

  // This is the state of the current proposal
  mapping(uint => Balance) _currentDistribution;

  bool Refunded;

  // Users are currently registered in the hardcoded Kake2 and Kake3 constructors
  function RegisterUser(address user) internal
  {
    _users.push(user);
  }

  // Have all user finalized their contributions to the payload?
  function AllLocked() internal view returns (bool)
  {
    uint userCount = _users.length;
    for(uint i = 0; i < userCount; ++i)
    {
      UserState memory state = _userState[_users[i]];
      if(!state.Locked)
      {
        return false;
      }
    }
    return true;
  }

  // Called by a user to signal they are ready to negotiate with the current payload
  function Lock() public
  {
    require(isValidUser(msg.sender));
    _userState[msg.sender].Locked = true;
    if(AllLocked())
    {
      // Now the fun begins
      // Copy the current payload to the distribution proposal
      Balance storage initialBalance = _currentDistribution[0];
      uint erc20Count = _erc20s.length;
      for(uint i = 0; i < erc20Count; ++i)
      {
        ERC20Record memory record = _erc20s[i];
        initialBalance.ERC20Balance[record.TokenAddress] += record.Value;
      }      
      onBalanceFinalized();
      State = ESTATE.SPLITTING;
    }
  }

  function onBalanceFinalized() internal
  {
	tick();
  }

  function isValidUser(address user) internal view returns (bool)
  {
    uint userLength = _users.length;
    for(uint i = 0; i < userLength; ++i)
    {
      if(user == _users[i])
      {
        return true;
      }
    }
    return false;
  }

  function getUserCount() internal pure returns (uint);

  function tick() internal;
  
  function AddERC20Token(address tokenContract, uint value) public payable
  {
    require(!Refunded && isValidUser(msg.sender) && !_userState[msg.sender].Locked);
    require(tokenContract != address(this));
    ERC20 token = ERC20(tokenContract);
    require(token.transferFrom(msg.sender, address(this), value));
    ERC20Record memory record = ERC20Record(msg.sender, tokenContract, value);
    _erc20s.push(record);
    _erc20Balance[tokenContract] += value;
  }

  function AddERC721Token(address tokenContract, uint256 id) public 
  {
    require(!Refunded && isValidUser(msg.sender) && !_userState[msg.sender].Locked);
    require(tokenContract != address(this));
    ERC721 token = ERC721(tokenContract);
    token.safeTransferFrom(msg.sender, address(this), id);
  }

  function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4)
  {
    ERC721Record memory record = ERC721Record(from, operator, tokenId, data);
    _erc721s.push(record);
    _erc721Balance[operator].push(tokenId);
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }

  function Refund () public
  {
    require(!Refunded && isValidUser(msg.sender));
    uint erc20Length = _erc20s.length;
    for(uint i = 0; i < erc20Length; ++i)
    {
      RefundERC20(_erc20s[i]);
    }
    uint erc721Length = _erc721s.length;
    for(uint i = 0; i < erc721Length; ++i)
    {
      RefundERC721(_erc721s[i]);
    }
    Refunded = true;
  }

  function RefundERC20(ERC20Record memory record) private
  {
    ERC20 token = ERC20(record.TokenAddress);
    require(token.transferFrom(address(this), record.OwnerAddress, record.Value));
  }

  function RefundERC721(ERC721Record memory record) private
  {
    ERC721 token = ERC721(record.TokenAddress);
    token.safeTransferFrom(address(this), record.OwnerAddress, record.TokenID);
  }

  function quickDelete(uint256[] memory array, uint index) internal pure returns(uint256[] memory) 
  {
    if (index >= array.length) return array;
    array[index] = array[array.length-1];
    delete array[array.length-1];
    return array;
  }

  function ChooseSegment(uint index) public
  {
    require(isValidUser(msg.sender) && AllLocked() && _currentDistribution[index].Owner == address(0));
    bool hasPermission = false;
    UserState storage state = _userState[msg.sender];
    uint permissionCount = state.PickPermissions.length;
    for(uint i = 0; i < permissionCount; ++i)
    {
      if(index == state.PickPermissions[i] && )
      {
        hasPermission = true;
        break;
      }
    }
    require(hasPermission);
    delete state.PickPermissions;
    _currentDistribution[index].Owner = msg.sender;
  }

  function SplitSegment(uint sourceIndex, uint targetIndex, address[] memory erc20Addresses, uint[] memory erc20Values, 
    address[] memory erc721Addresses, uint256[] memory erc721Ids) public payable
  {
    require(isValidUser(msg.sender) && AllLocked());

    uint erc20Length = erc20Addresses.length;
    require(erc20Length == erc20Values.length);

    uint erc721Length = erc721Addresses.length;
    require(erc721Length == erc721Ids.length);
    
    UserState storage userState = _userState[msg.sender];

    require(userState.SplitPermissions[sourceIndex] > 0);
    require(userState.CreatePermissions[targetIndex]);
    
    userState.SplitPermissions[sourceIndex]--;
    userState.CreatePermissions[targetIndex] = false;

    Balance storage readBalance = _currentDistribution[sourceIndex];
    Balance storage writeBalance = _currentDistribution[targetIndex];

    for(uint i = 0; i < erc20Length; ++i)
    {
      address tokenAddress = erc20Addresses[i];
      uint value = erc20Values[i];
      require(readBalance.ERC20Balance[tokenAddress] >= value);
      readBalance.ERC20Balance[tokenAddress] -= value;
      writeBalance.ERC20Balance[tokenAddress] += value;
    }

    for(uint i = 0; i < erc721Length; ++i)
    {
      address tokenAddress = erc721Addresses[i];
      uint id = erc721Ids[i];
      uint256[] storage ownedTokens = readBalance.ERC721Balance[tokenAddress];
      uint ownedTokenCount = ownedTokens.length;
      bool matchFound = false;
      for(uint j = 0; j < ownedTokenCount; ++j)
      {
        if(id == ownedTokens[j])
        {
          quickDelete(ownedTokens, j);
          writeBalance.ERC721Balance[tokenAddress].push(id);
          matchFound = true;
        }
      }
      require(matchFound);
    }

    tick();
  }
}
