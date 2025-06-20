# Contributing to NeuralTrust Helm Charts

First off, thank you for considering contributing to the NeuralTrust Helm Charts project! We welcome any and all contributions. Every little bit helps, and we appreciate your effort.

This document provides some guidelines for contributing to this project. Please feel free to propose changes to this document in a pull request.

## How Can I Contribute?

There are many ways to contribute, from writing tutorials or blog posts, improving the documentation, submitting bug reports and feature requests or writing code which can be incorporated into the project.

### Reporting Bugs

If you find a bug, please open an issue on our GitHub issues page.

Please include as much detail as possible in your bug report:
- A clear and descriptive title.
- A description of the steps to reproduce the bug.
- The version of the chart you're using.
- Any relevant logs or error messages.

### Suggesting Enhancements

If you have an idea for a new feature or an enhancement to an existing one, please open an issue on our GitHub issues page.

Please provide a clear and detailed explanation of the feature you're proposing, why it's needed, and how it would work.

## Your First Code Contribution

Unsure where to begin contributing to the project? You can start by looking through `good-first-issue` and `help-wanted` issues.

### Contribution Workflow

We follow the standard GitHub fork and pull request workflow.

1.  **Fork** the repository on GitHub.
2.  **Clone** your fork to your local machine:
    ```bash
    git clone https://github.com/YOUR_USERNAME/neuraltrust-helm-charts.git
    cd neuraltrust-helm-charts
    ```
3.  Create a **new branch** for your changes:
    ```bash
    git checkout -b my-awesome-feature
    ```
4.  Make your changes.
5.  **Commit** your changes. Please write a clear and concise commit message.
6.  **Sign** your commits. We use the Developer Certificate of Origin (DCO), which requires all commits to be signed off. You can sign your commits by using the `--signoff` or `-s` flag with `git commit`.
    ```bash
    git commit -s -m "feat: Add my awesome feature"
    ```
7.  **Push** your changes to your fork on GitHub:
    ```bash
    git push origin my-awesome-feature
    ```
8.  Open a **Pull Request** to the `main` branch of the `neuraltrust/neuraltrust-helm-charts` repository.

### Developer Certificate of Origin (DCO)

We require that all contributors sign off on their commits. This certifies that you have the right to contribute the code and that you agree to the DCO. The DCO is a lightweight way for contributors to confirm that they are the source of their contributions.

You can read the full text of the DCO [here](https://developercertificate.org/).

To sign off on a commit, use the `-s` or `--signoff` flag with `git commit`:

```bash
git commit -s -m "This is my commit message"
```

Git will then add a `Signed-off-by` line to your commit message, which will look something like this:

```
Signed-off-by: Your Name <your.email@example.com>
```

We require that your commits are signed off to be able to merge your contribution.

## Code of Conduct

This project and everyone participating in it is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior.

## Licensing

By contributing to this project, you agree that your contributions will be licensed under the Apache License 2.0. You can find the full license text in the [LICENSE](LICENSE) file.
