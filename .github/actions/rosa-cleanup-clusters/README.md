# Delete ROSA Clusters

## Description

This GitHub Action automates the deletion of ROSA (Red Hat OpenShift Service on AWS) clusters using a shell script.


## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `tf-bucket` | <p>Bucket containing the clusters states</p> | `true` | `""` |
| `tf-bucket-region` | <p>Region of the bucket containing the resources states, if not set, will fallback on AWS_REGION</p> | `false` | `""` |
| `max-age-hours-cluster` | <p>Maximum age of clusters in hours</p> | `false` | `20` |


## Runs

This action is a `composite` action.

## Usage

```yaml
- uses: camunda/camunda-tf-rosa/.github/actions/rosa-cleanup-clusters@main
  with:
    tf-bucket:
    # Bucket containing the clusters states
    #
    # Required: true
    # Default: ""

    tf-bucket-region:
    # Region of the bucket containing the resources states, if not set, will fallback on AWS_REGION
    #
    # Required: false
    # Default: ""

    max-age-hours-cluster:
    # Maximum age of clusters in hours
    #
    # Required: false
    # Default: 20
```
