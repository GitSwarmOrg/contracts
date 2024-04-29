import {initialDeployGsContracts} from "../test/js_tests/testUtils";

import hre from "hardhat";

const ethers = hre.ethers;
const TOKEN_BUFFER_AMOUNT = 10n ** 20n;
const FM_SUPPLY = 10n ** 20n;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Running deploy script with eth account " + deployer.address)
    await initialDeployGsContracts(
        "GitSwarm",
        "GS",
        FM_SUPPLY,
        TOKEN_BUFFER_AMOUNT,
        deployer
    )
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
