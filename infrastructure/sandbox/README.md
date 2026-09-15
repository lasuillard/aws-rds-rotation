# Sandbox

This directory contains the Terraform configuration files for deploying the AWS RDS Rotation sandbox.

## How to use this sandbox

1. `terraform apply` to deploy the sandbox environment.

2. Interact with the resources as needed, for example, start a new SFN execution.

    ![Start new SFN execution](./docs/start-new-sfn-execution.png)

3. `terraform destroy` to clean up the resources. Remember to manually delete any resources not tracked by Terraform as mentioned above.

Test commands are exposed as output for convenience. For example, you can run `sh -c "$(tf output -raw psql_command)"` to connect to the test database.

## Cleanup

Some resources aren't tracked by Terraform and need to be deleted manually to avoid unnecessary costs and resource clutter:

- Databases created by SFN workflow. You will be blocked when destroying the stack because of its dependencies, for example, DB subnet group:

  ```plaintext
  │ Error: deleting RDS Subnet Group (aws-rds-rotation-db-subnet-group-27111fb6aa1f6256c63472ce35): operation error RDS: DeleteDBSubnetGroup, https response error StatusCode: 400, RequestID: 5b3d6f5a-ec8d-4a9c-9320-b5aeb9176446, InvalidDBSubnetGroupStateFault: Cannot delete the subnet group 'aws-rds-rotation-db-subnet-group-27111fb6aa1f6256c63472ce35' because at least one database instance: aws-rds-rotation-db-20260908t190752 is still using it.
  ```

- The final database snapshot if you created one during the sandbox setup (if you no longer need it).
