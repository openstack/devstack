=====================
eucarc - EC2 Settings
=====================

``eucarc`` creates EC2 credentials for the current user as defined by
``OS_TENANT_NAME:OS_USERNAME``. ``eucarc`` sources ``openrc`` at the
beginning (which in turn sources ``stackrc`` and ``localrc``) in order
to set credentials to create EC2 credentials in Keystone.

EC2\_URL
    Set the EC2 url for euca2ools. The endpoint is extracted from the
    service catalog for ``OS_TENANT_NAME:OS_USERNAME``.

    ::

        EC2_URL=$(keystone catalog --service ec2 | awk '/ publicURL / { print $4 }')

S3\_URL
    Set the S3 endpoint for euca2ools. The endpoint is extracted from
    the service catalog for ``OS_TENANT_NAME:OS_USERNAME``.

    ::

        export S3_URL=$(keystone catalog --service s3 | awk '/ publicURL / { print $4 }')

EC2\_ACCESS\_KEY, EC2\_SECRET\_KEY
    Create EC2 credentials for the current tenant:user in Keystone.

    ::

        CREDS=$(keystone ec2-credentials-create)
        export EC2_ACCESS_KEY=$(echo "$CREDS" | awk '/ access / { print $4 }')
        export EC2_SECRET_KEY=$(echo "$CREDS" | awk '/ secret / { print $4 }')

Certificates for Bundling
    Euca2ools requires certificate files to enable bundle uploading. The
    exercise script ``exercises/bundle.sh`` demonstrated retrieving
    certificates using the Nova CLI.

    ::

        EC2_PRIVATE_KEY=pk.pem
        EC2_CERT=cert.pem
        NOVA_CERT=cacert.pem
        EUCALYPTUS_CERT=${NOVA_CERT}
