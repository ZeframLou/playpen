# Playpen

Playpen is a set of modern, gas optimized staking pool contracts.

## Features

-   Support for both ERC20 staking and ERC721 staking
-   Can start new reward period after the current one is over
-   Gas optimized (see [gas snapshot](.gas-snapshot))
-   Minimized error in reward computation (<10^-8) by using higher precision
-   Well commented with NatSpec comments
-   Fuzz tests powered by [Foundry](https://github.com/gakonst/foundry)
-   Cheap deployment using `ClonesWithCallData` (~81.7k gas)

## Installation

To install with [DappTools](https://github.com/dapphub/dapptools):

```
dapp install zeframlou/playpen
```

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install zeframlou/playpen
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
make update
```

### Compilation

```
make build
```

### Testing

```
make test
```

## Why is it called Playpen?

So that whenever someone mentions it they have to say "Playpen is..."

![](meme.png)
