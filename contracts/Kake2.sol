pragma solidity ^0.5.0;

import "./Kake.sol";

/********************************************************************************************
 * Kake2 is a smart contract that implements the simplest case. The first user is given
 * permission to split the payload into two segments. The second is then able to choose who
 * receives each segment.
 *******************************************************************************************/
contract Kake2 is Kake 
{
  constructor(address user1, address user2) public 
  {
    RegisterUser(user1);
    RegisterUser(user2);
  }

  function tick() internal
  {
	if(_stepCounter == 0)
	{
		address firstUser = _users[0];
		_userState[firstUser].SplitPermissions[0] = 1; // The first user can split the initial balance into 2 pieces
		_userState[firstUser].CreatePermissions[1] = true; // And has permission to put the piece into the index 1
	}
	else if(_stepCounter == 1)
		address secondUser = _users[1];
		_userState[secondUser].PickPermissions.push(0);  // We now give the second user permission to pick the segment
		_userState[secondUser].PickPermissions.push(1);  // at index 0 or 1
	}
	_stepCounter++;    
  }

  function getUserCount() internal pure returns (uint)
  {
    return 2;
  }
}
