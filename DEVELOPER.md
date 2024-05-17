# Developer's Guide

Welcome to the development reference for Camunda's Terraform Rosa module! This document provides guidance on setting up a testing environment, running tests, and managing releases.

## Setting up Development Environment

To start developing or testing the Rosa module, follow these steps:

1. **Clone the Repository:**
   - Clone the repository from [camunda/camunda-tf-rosa](https://github.com/camunda/camunda-tf-rosa) to your local machine.

2. **Install Dependencies:**
   - Ensure you have Terraform, the AWS CLI, and the ROSA CLI installed on your machine. Refer to their respective documentation for installation instructions.

3. **Configure AWS Credentials:**
   - Configure your AWS CLI with the necessary credentials to interact with your AWS account:
     ```bash
     aws configure
     ```

4. **Initialize Terraform:**
   - Navigate to the module's directory and initialize Terraform:
     ```bash
     cd modules/rosa-hcp
     terraform init
     ```

5. **Run Terraform Plan and Apply:**
   - You can now plan and apply the Terraform configuration to create the ROSA cluster:
     ```bash
     terraform plan -var "cluster_name=your-cluster-name" -var "replicas=2" -var "htpasswd_password=your-password" -var "htpasswd_username=your-username" -var "offline_access_token=your-token" -var "openshift_version=your-openshift-version"
     terraform apply -var "cluster_name=your-cluster-name" -var "replicas=2" -var "htpasswd_password=your-password" -var "htpasswd_username=your-username" -var "offline_access_token=your-token" -var "openshift_version=your-openshift-version"
     ```

## Tests in the CI

The tests in the CI can be triggered automatically by modifying Terraform or test files. It will be labeled either `test` or `terraform` automatically by the labeler.

You can choose to overwrite the name and disable the deletion of the cluster in the workflow dispatch.

## Releasing a New Version

We follow Semantic Versioning (SemVer) guidelines for versioning. Follow these steps to release a new version:

1. **Commit History:**
   - Maintain a clear commit history with explicit messages detailing additions and deletions.

2. **Versioning:**
   - Determine the appropriate version number based on the changes made since the last release.
   - Follow the format `MAJOR.MINOR.PATCH` as per Semantic Versioning guidelines.

3. **GitHub Releases:**
   - Publish the new version on GitHub Releases.
   - Tag the release with the version number and include release notes summarizing changes.

## Adding new GH actions

Please pin GitHub action, if you need you can use [pin-github-action](https://github.com/mheap/pin-github-action) cli tool.

---

By following these guidelines, we ensure smooth development iterations, robust testing practices, and clear version management for the Terraform ROSA module. Happy coding!
