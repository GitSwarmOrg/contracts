Solidity contracts used on the [GitSwarm.com](https://gitswarm.com/) platform

Tested using Hardhat 2.21.0 and pytest 7.4.0.

## Notes
The `requirements.txt` file lists all the Python dependencies. Install them by running:

```pip install -r requirements.txt```

To install [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started#installation), run

```bash 
npm i
```

Before running the tests, you need to compile the contracts using 
```bash
npx hardhat compile
```
and run the hardhat node using 
```bash
npx hardhat node
```

The python tests can be run using
```bash
pytest test/py_tests/
```
