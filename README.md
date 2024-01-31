# Maia V2 Contracts

<!--
Badges provide a quick visual way to convey various information about your project. Below are several common types of badges. Feel free to uncomment, remove, or add new badges as needed for your project. Make sure to update the links so they point to the correct sources relevant to your project.

- Version: Shows the current version of your project based on the latest release.
- Test CI: Displays the status of your continuous integration testing.
- Lint: Shows the status of your code linting process.
- Code Coverage: Indicates the percentage of your code covered by tests.
- License: Shows the type of license your project is under.
- Docs: Links to your project's documentation.
- Discord: Provides a quick link to join your Discord server.
- Discussions: (Optional) If you use GitHub Discussions, this badge links to that section.
- JS Library: (Optional) If your project includes a JavaScript library, use this badge to link to it.

Remember to replace 'Maia-DAO/maia-v2' with your repository's path and update other relevant links to reflect your project's resources.
-->

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Lint][lint-badge]][lint-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![Solidity][solidity-shield]][ci-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discord][discord-badge]][discord-link]
<!-- [![Discussions][discussions-badge]][discussions-link] -->
<!-- [![JS Library][js-library-badge]][js-library-link] -->

In this repository, you will find the contracts for the Maia V2 BurntHermes aggregation logic.

## Contributing

If you’re interested in contributing please see our [contribution guidelines](./CONTRIBUTING.md)! This includes instructions on how to compile and run tests locally.

## Documentation

A more detailed description of the project can be found in the [documentation](https://v2-docs.maiadao.io/).

## Architecture

The system is composed of VoteMaia, an example of a Partner contract, that allows the partner to manage underlying BurntHermes utility tokens, like allowing users to claim their share of utility tokens from the bHERMES held in the contract. Also includes PartnerManagerFactory, to be used by governance to acknowledge new partners on-chain.

## Repository Structure 

All contracts are held within the `./src` folder.

Note that helper contracts used by tests are held in the `./test/utils` subfolder within the contracts folder. Any new test helper contracts should be added there and all foundry tests are in the `./test` folder.

```ml
src
├── src
│   ├── factories
│   │   └── PartnerManagerFactory.sol - "Factory for managing PartnerManagers"
│   ├── interfaces
│   │   ├── IBaseVault.sol - "BaseVault interface"
│   │   ├── IERC4626PartnerManager.sol - "ERC4626PartnerManager interface"
│   │   ├── IPartnerManagerFactory.sol - "PartnerManagerFactory interface"
│   │   └── IPartnerUtilityManager.sol - "PartnerUtilityManager interface"
│   ├── libraries
│   │   └── DateTimeLib.sol - "Library to check if it is the first Tuesday of a month"
│   ├── PartnerUtilityManager.sol - "Partner Utility Tokens Manager Contract"
│   ├── tokens
│   │   ├── ERC4626PartnerManager.sol - "Yield bearing, boosting, voting, and gauge enabled Partner Token"
│   │   └── Maia.sol - "Maia ERC20 token - Native token for the Maia ecosystem"
│   └── VoteMaia.sol - "VoteMaia: Yield bearing, boosting, voting, and gauge enabled MAIA"
└── test
    ├── mock
    │   ├── MockERC4626PartnerManager.t.sol
    │   └── MockVault.t.sol
    ├── tokens
    │   └── ERC4626PartnerManagerTest.t.sol
    └── VoteMaiaTest.t.sol
```

## Local deployment and Usage

To utilize the contracts and deploy to a local testnet, you can install the code in your repo with forge:

```markdown
forge install https://github.com/Maia-DAO/maia-v2
```

## License

[MIT](LICENSE) Copyright <YEAR> <COPYRIGHT HOLDER>

<!-- 
Update the following badge links for your repository:
- Replace 'Maia-DAO/maia-v2' with your repository path.
- Replace Maia DAO Discord link with your Discord server invite link.
-->

[version-badge]: https://img.shields.io/github/v/release/Maia-DAO/maia-v2
[version-link]: https://github.com/Maia-DAO/maia-v2/releases
[ci-badge]: https://github.com/Maia-DAO/maia-v2/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/Maia-DAO/maia-v2/actions/workflows/test.yml
[lint-badge]: https://github.com/Maia-DAO/maia-v2/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/Maia-DAO/maia-v2/actions/workflows/lint.yml
[coverage-badge]: .github/coverage-badge.svg
[coverage-link]: .github/coverage-badge.svg
[solidity-shield]: https://img.shields.io/badge/solidity-%5E0.8.0-aa6746
[license-badge]: https://img.shields.io/github/license/Maia-DAO/maia-v2
[license-link]: https://github.com/Maia-DAO/maia-v2/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/Ecosystem-documentation-informational
[docs-link]: https://v2-docs.maiadao.io/
[discussions-badge]: https://img.shields.io/badge/maia-v2-discussions-blueviolet
[discussions-link]: https://github.com/Maia-DAO/maia-v2/discussions
[js-library-badge]: https://img.shields.io/badge/maia-v2.js-library-red
[js-library-link]: https://github.com/Maia-DAO/maia-v2-js
[discord-badge]: https://img.shields.io/static/v1?logo=discord&label=discord&message=Join&color=blue
[discord-link]: https://discord.gg/maiadao
