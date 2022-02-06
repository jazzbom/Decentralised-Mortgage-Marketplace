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
  const neo = await upgrades.deployProxy(Neo, ["0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0", "NEO", "NEO", "USD",
  100, "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f", 250, "Yearly", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"] );

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
