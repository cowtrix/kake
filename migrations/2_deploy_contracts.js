const Kake2 = artifacts.require("Kake2");
const Kake3 = artifacts.require("Kake3");

module.exports = function(deployer) {
    var addr1 = "0x3dCD7faecD0FC34d2aD171Da01796A2dFD45DF52";
    var addr2 = "0xFf745f1A7259a4160635ac697944D077C0D0EE63";
    var addr3 = "0x21caBd7F5aa6Ad763685157386709449bF09ce99";
    deployer.deploy(Kake2, addr1, addr2);
    deployer.deploy(Kake3, addr1, addr2, addr3);
};
