Solidity contracts used on the [GitSwarm.com](https://gitswarm.com/) platform

Tested using Hardhat 2.22.12 and solidity-coverage 0.8.13.

## Notes

To install [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started#installation) and other requirements, run

```bash 
npm i
```

Before running the tests, you need to compile the contracts using 
```bash
npx hardhat compile
```

Run the coverage tests by using
```bash
npx hardhat coverage
```

## Deploy
Deploy script can be found in the `scripts` folder.

Rename `./.env.example` to `./.env` in the project root.
To add the private key of a deployer account, assign the following variables
```
PRIVATE_KEY=...
```
To deploy, run 
```bash
$ npm run deploy -- <<network>>
```

For example, you can connect to a node on localhost using:  
```bash
$ npm run deploy -- localhost
```

For other networks they must be listed in hardhat.config.ts under networks.


