# kake
Kake is a set of smart contracts for envy-free division of ERC20 and ERC721 tokens. While dividing a single fungible asset is a simple operation, division of a pool of fungible and non-fungible assets is a much trickier problem. This project references this paper (https://arxiv.org/abs/1604.03655) which described an envy-free solution for [n] participants. While this paper does apply only to heterogeneous divisible goods, which ERC720 tokens are not, good solutions should still be able to be found if they exist. How many exist depends entirely on contextual factors.

It should also be noted that the maximum number of steps can be as high as n^n^n^n^n^n, which is a fantastically bad complexity. However, we can thankfully rely on the rapidly decreasing value of the remaining portion. At some point, the cost of continuing to argue over crumbs will outweigh the return, and the contract can be burned with the optimally minimal amount of waste inside. This will usually be zero, as
fungible tokens will be more common in the later segmentations.

At any point before contract finalisation, any participant can refund the contract, which will pay back all tokens to their original owners. In some cases, a fair split will not be found and this action is reasonable and necessary. Kake only guarantees that if the transaction is finalised, all participants were treated fairly.
