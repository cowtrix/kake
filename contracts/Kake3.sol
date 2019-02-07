pragma solidity ^0.5.0;

import "./Kake.sol";

contract Kake3 is Kake 
{
  
  constructor(address user1, address user2, address user3) public 
  {
    RegisterUser(user1);
    RegisterUser(user2);
    RegisterUser(user3);
  }
  
  function tick() internal
  {
	if(_stepCounter == 0)
	{
		address firstUser = _users[0];
		_userState[firstUser].SplitPermissions[0] = 2; // The first user can split the initial balance into 3 pieces
		_userState[firstUser].CreatePermissions[1] = true; // And has permission to put the pieces into the index 1 & 2
		_userState[firstUser].CreatePermissions[2] = true; 
	}
	else if(_stepCounter == 1)
		// The second user can create another segment from all current segments
		address secondUser = _users[1];
		_userState[secondUser].SplitPermissions[0] = 1;
		_userState[secondUser].SplitPermissions[1] = 1;
		_userState[secondUser].SplitPermissions[2] = 1;
		_userState[secondUser].CreatePermissions[3] = true;
	}
	else if(_stepCounter == 2)
	{
		// The third user is then able to pick their favourite from the first 3
		address thirdUser = _users[2];
		_userState[thirdUser].PickPermissions.push(0);  // We now give the second user permission to pick the segment
		_userState[thirdUser].PickPermissions.push(1);  // at indexes 0 - 2
		_userState[thirdUser].PickPermissions.push(2); 
	}
    _stepCounter++;
  }	

  function getUserCount() internal pure returns (uint)
  {
    return 3;
  }
}
