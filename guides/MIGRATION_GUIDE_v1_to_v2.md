# Migration Guide for ROSA Module

## Key Changes

In the latest update to the ROSA module, there are significant modifications affecting how the module integrates with Red Hat's infrastructure and manages its resources.

### Removed variables

- **offline_access_token**: This variable has been removed.
- **url**: This variable, which previously defined the Red Hat Console URI, has also been removed.

### New Variables

The functionality provided by the removed parameters has been replaced by:
- **RHCS_TOKEN**: Used to provide authentication for Red Hat Cloud Services.
- **RHCS_URL**: Specifies the URL for Red Hat Cloud Services.

### Provider Management

- The ROSA module no longer includes an embedded provider configuration.
- Users must now explicitly define the provider.
- An example provider configuration can be found in `modules/fixtures/backend.tf`.

### Migration Path

To upgrade to the latest version of the ROSA module:
1. **Update Your Variables**:
   - Replace `offline_access_token` with `RHCS_TOKEN`.
   - Replace `url` with `RHCS_URL`.

2. **Define the Provider**: Add the provider configuration explicitly in your Terraform code by referencing the example in `modules/fixtures/backend.tf`.

3. **Verify Integration**: Ensure the new variables are properly set and verify that the ROSA module is correctly communicating with Red Hat Cloud Services.
