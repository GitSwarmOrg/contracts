Solidity contracts used on the [GitSwarm.com](https://gitswarm.com/) platform

Tested using Hardhat 2.15.0 and pytest 7.4.0.

## Notes
The `requirements.txt` file lists all the Python dependencies. Install them by running:

```pip install -r requirements.txt```

The tests are compatible with [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started#installation).
For the tests to run successfully, you need the following changes in hardhat.config.js:

```javascript
module.exports = {
  solidity: "0.8.18",
  networks: {
    hardhat: {
      accounts: [
        {
          privateKey: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          balance: "10000000000000000000000000000000000000000000000000000000"
        }
      ]
    }
  }
};
```