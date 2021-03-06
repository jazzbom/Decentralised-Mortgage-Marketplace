// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, upgrades } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Neo = await ethers.getContractFactory("Ne0779");
  const neo = await upgrades.deployProxy(Neo, ["0xE938730a87C510C52e6180779F7253abd3986415", "NEO", "NEO", "USD",
  10, "0x03CfA08668fC63493595F4846Fb3aD1458C7C576", 1100, "FIXED", "0x03CfA08668fC63493595F4846Fb3aD1458C7C576"] );

  await neo.deployed();

  console.log("Ne0779 deployed to:", neo.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
