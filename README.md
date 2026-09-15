# aws-rds-rotation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A demo project for automating RDS database recreation from a snapshot.

RDS rotation is a process of replacing a database with a new one from a snapshot. The primary usage is to create a new development database from a production database snapshot with sensitive data masked and scrubbed.

## 👀 How it works

The workflow is as follows:

![Step Functions graph](./docs/stepfunctions-graph.png)

1. On initialization, prepare the environment and necessary configurations, such as preprocessing inputs and template variables injected by Terraform.
1. Restore the RDS database from the snapshot created in the setup project.
1. Once the RDS database is restored and ready, update master credentials and connection settings as needed.
1. Wait once again for the RDS database to become fully available and operational.
1. Sanitize the database by masking and scrubbing sensitive data via CodeBuild.
1. Switch traffic to the new RDS database.
1. Delete the old RDS database.

If any error occurs during the rotation process, incomplete database instance will be deleted automatically, to prevent sensitive data from being served to development environments.

## 🔧 For your own experiment

To use this repository for your own experiment, please refer below.

### 📂 Key directory structure

- `infrastructure/sandbox`: Contains the Terraform project for deploying and interacting with the sandbox environment.
  - `functions`: Lambda functions used in the rotation workflow.
  - `sql`: SQL scripts executed in the CodeBuild pipeline to sanitize the database.
  - `statemachine`: Contains the Step Functions state machine definitions for the rotation workflow.
- `infrastructure/setup`: Contains the Terraform project for creating the RDS snapshot.
  - `scripts`: Contains scripts used in the setup project, such as waiting for the bastion EC2 instance to be ready and seeding the database.
- `scripts/`: Contains general-purpose scripts used in the project, such as connecting to the database via Session Manager.

### ❄️ Development environment

This repository uses [Nix Flakes](https://nix.dev/concepts/flakes.html) to manage tools. The following tools will be automatically installed (you must have `nix` installed):

- `pre-commit`
- `terraform`
- `awscli2` (`aws`)
- `ssm-session-manager-plugin` (`session-manager-plugin`)
- `postgresql_18` (`psql`)
- `uv`

Run `nix develop` to activate the environment. This will automatically install the above tools. Alternatively, you can use the included [Dev Container configuration](./.devcontainer.example/devcontainer.json) which has Nix installed.

### 🧪 Set up and testing

This project contains two main Terraform projects: **setup** and **sandbox**. The former project is responsible for creating an RDS snapshot, while the latter project is for deploying and interacting with the sandbox environment to develop and test the RDS rotation workflow.

1. Go to [setup](./infrastructure/setup/README.md) project first. Create the RDS snapshot there, if you don't already have one.
1. Then go to the [sandbox](./infrastructure/sandbox/README.md) project to provision the sandbox environment and interact with it.

For detailed instructions, please refer to the respective README files in each project directory.

## 📜 License

This project is licensed under the MIT License.
