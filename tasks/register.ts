import { task } from "hardhat/config";
import * as config from './config';

//function register(address referrer) external

//npx hardhat --network rinkeby  register --referrer "0x123"
task("register", "register")
  .addOptionalParam("referrer", "referrer")
  .setAction(async (taskArgs, hre) => {
    const platform = await hre.ethers.getContractAt("ACDMPlatform", config.Platform);

    let referrer = "0x0000000000000000000000000000000000000000";
    if (taskArgs.referrer) {
      referrer = taskArgs.referrer;
    }

    let res = await platform.register(referrer);
    console.log('register: ', res);
  });

