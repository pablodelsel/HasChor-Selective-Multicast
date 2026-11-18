# HasChor Selective Multicast

This repository contains an extension of [HasChor](https://github.com/gshen42/HasChor), a Haskell library for functional choreographic programming. The extension was developed as part of a thesis in Computer Science and introduces restricted choreographies and selective multicast for conditional decision propagation.

## Extension

The extension adds:

- **`RestrictedChoreo`**: a choreography parameterized by a type-level census of locations.
- **`locallyR`, `commR`, and `condR`**: restricted counterparts of HasChor operations. Their type constraints check that the locations used by these operations belong to the census.
- **`condSelective`**: a conditional construct that specifies the census of locations to which the decision is propagated.

The extension reuses HasChor's choreography infrastructure and adds the restricted-choreography and selective conditional functionality alongside the original API.

## Relationship with HasChor

This project is based on the original [HasChor repository](https://github.com/gshen42/HasChor) and retains substantial portions of its source code. The underlying library is described in:

> Gan Shen, Shun Kashiwa, and Lindsey Kuper. 2023. *HasChor: Functional Choreographic Programming for All (Functional Pearl).* Proceedings of the ACM on Programming Languages 7 (ICFP), Article 207. <https://doi.org/10.1145/3607849>.

See the original repository and paper for the design and API of HasChor itself.

## Requirements and build

The project is built with GHC and Cabal. The development environment used for this project included **GHC 9.6.3** and **cabal-install 3.16.1.0**.

From the repository root, build the library and available examples with:

```bash
cabal build all
```

To build the restricted-choreography examples explicitly:

```bash
cabal build exe:r-test exe:r-benchmark
```

Cabal resolves the package dependencies declared in `HasChor.cabal`.

## Examples

The `examples/` directory contains the examples distributed with HasChor and the examples added for this extension. In particular:

- **`r-test`** exercises the restricted-choreography API.
- **`r-benchmark`** runs benchmark scenarios designed to compare the original and selective decision-propagation approaches.

The executables can be launched with `cabal run`. The command-line arguments are defined by each example's `Main.hs`; for `r-test`, consult that file for the expected arguments.

The benchmark executable takes a mode (`original` or `selective`), the number of rounds, the number of locations, and the location for the process being started:

```bash
cabal run r-benchmark -- original <rounds> <num-locations> <location>
cabal run r-benchmark -- selective <rounds> <num-locations> <location>
```

Either run one process for each participating location (using the same mode and benchmark parameters for all processes) or run `run-r-benchmark.sh`, that automatizes it as a batch process.

## Evaluation

The benchmark compares the `original` and `selective` modes under the same number of rounds and locations. To make the comparison reproducible, keep the workload and deployment configuration identical between runs and start all participating location processes for each mode.

The instrumented HTTP backend (`Choreography.Network.HttpInstrumented`) reports the number of successfully sent HTTP messages for each location. Each process prints a line of the form:

```text
[Network] <location>: <count> messages sent
```

These are per-process counts. To obtain the total number of messages sent by a run, sum the counts reported by all participating locations. The benchmark runner, when used, stores the individual process logs under its configured log directory. The evaluation programs and runner scripts are the reference for the exact parameters and execution procedure used in the thesis.

## License and citation

This project is distributed under the **BSD 3-Clause License**. It is derived from HasChor; the original copyright notice is retained in [`LICENSE`](LICENSE).

If you use this extension, please cite the software using the metadata in [`CITATION.cff`](CITATION.cff). Please also cite the original HasChor paper when referring to the underlying library or its programming model.
