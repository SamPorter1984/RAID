pragma solidity >=0.8.4 <0.9.0;
// a child or a separate contract will have support for stable coin based grants
// i am thinking of moving all beneficiary logic out of treasury in next implementation
interface I{function transfer(address to, uint value) external returns(bool);}
contract Treasury {
	address private _governance;
	uint8 private _governanceSet;
	bool private _init;
	address private _jobMarket;
	address private _oracleMain;// oracle registry contract

	struct Beneficiary {bool solid; uint88 amount; uint32 lastClaim; uint16 emission;}
	mapping (address => Beneficiary) public bens;

	function init() public {
		require(_init == false && msg.sender == 0x2D9F853F1a71D0635E64FcC4779269A05BccE2E2);
		_init=true;
		_governance = msg.sender;
		setBeneficiary(0x2D9F853F1a71D0635E64FcC4779269A05BccE2E2,true,32857142857e12,12510400,1e4);
		setBeneficiary(0x174F4EbE08a7193833e985d4ef0Ad6ce50F7cBc4,true,28857142857e12,12510400,1e4);
		setBeneficiary(0xFA9675E41a9457E8278B2701C504cf4d132Fe2c2,true,25285714286e12,12510400,1e4);
	}
// so we assume that not only beneficiaries but also the governance is malicious
// the function can overwrite some existing beneficiaries parameters
// or we do it differently: a boolean that makes a grant editable/removable/irremovable, so that governance can express trust,
// because if a malicious beneficiary scams governance, governance can ruin that beneficiary' reputation,
// however if malicious governance scams a beneficiary, beneficiary can't do anything
// best solution is yet to be found, design could change
	function setBeneficiary(address a, bool solid, uint amount, uint lastClaim, uint emission) public {
		require(msg.sender == _governance && bens[a].solid == false && amount<=4e22 && lastClaim < block.number+1e6 && lastClaim >= 12510400 && emission >= 1e2 && emission <=1e4);
		if(lastClaim < block.number) {lastClaim = block.number;}
		if (solid == true) {bens[a].solid = true;}
		uint lc = bens[a].lastClaim;
		if (lc == 0) {bens[a].lastClaim = uint32(lastClaim+129600);} //this delay disallows deployer to be malicious, can be removed after the governance will have control over treasury
		if (bens[a].amount == 0 && lc != 0) {bens[a].lastClaim = uint32(lastClaim);}
		bens[a].amount = uint88(amount);
		bens[a].emission = uint16(emission);
	}

	function getBeneficiaryRewards() external {
		uint lastClaim = bens[msg.sender].lastClaim;
		uint amount = bens[msg.sender].amount;
		uint rate = _getRate();
		uint toClaim = (block.number - lastClaim)*bens[msg.sender].emission*rate;
		require(amount > 0 && block.number > lastClaim);
		if(toClaim > amount) {toClaim = amount;}
		bens[msg.sender].lastClaim = uint32(block.number);
		bens[msg.sender].amount = uint88(amount) - uint88(toClaim);
		I(0x1565616E3994353482Eb032f7583469F5e0bcBEC).transfer(msg.sender, toClaim);
	}

	function getRewards(address a,uint amount) external returns(bool res){ //for posters, providers and oracles
		require(msg.sender == 0x109533F9e10d4AEEf6d74F1e2D59a9ed11266f27 || msg.sender == _jobMarket || msg.sender == _oracleMain);//hardcoded addresses
		I(0x1565616E3994353482Eb032f7583469F5e0bcBEC).transfer(a, amount); return true;
	}

	function _getRate() internal view returns(uint){uint rate = 1e11; uint halver = block.number/1e7;if (halver>1) {for (uint i=1;i<halver;i++) {rate=rate*3/4;}}return rate;}
	function setGovernance(address a) public {require(_governanceSet < 3 && msg.sender == _governance);_governanceSet += 1;_governance = a;}
	function setContracts(address j, address om) public {require(msg.sender == _governance); _jobMarket = j; _oracleMain = om;}// forgot to add a boolean for convenience, it's ok though
}
