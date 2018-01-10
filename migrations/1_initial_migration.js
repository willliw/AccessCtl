var Migrations = artifacts.require("./Migrations.sol");
var AccessCtl = artifacts.require("./AccessCtl.sol")

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(AccessCtl);
};
