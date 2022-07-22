    # Create the spaces bucket to hold the bulky bootstrap config
    # Doing it here tests early that the spaces access works before
    # we create other resources.
    aws --endpoint-url $SPACES_ENDPOINT s3 mb $SPACES_BUCKET >/dev/null

    # Create the image, load balancer, firewall, and VPC
    create_image_if_not_exists
    create_vpc; sleep 20
    create_load_balancer; sleep 20
    create_firewall # <<<< - *** -
       # >>>> Error: POST https://api.digitalocean.com/v2/firewalls: 422 (request "b2961cc8-9b9a-4bbb-a088-767322dd9fe1") tag osdo does not exist

    # Generate the ignition configs (places bootstrap config in spaces)
    generate_manifests

    # Create the droplets and wait some time for them to get assigned
    # addresses so that we can create dns records using those addresses
    create_droplets; sleep 20
    # Print IP information to the screen for the logs (informational)
    doctl compute droplet list | colrm 63

    # Create domain and dns records. Do it after droplet creation
    # because some entries are for dynamic addresses
    create_domain_and_dns_records

    # Wait for the bootstrap to complete
    echo -e "\nWaiting for bootstrap to complete.\n"
    openshift-install --dir=generated-files  wait-for bootstrap-complete

    # remove bootstrap node and config space as bootstrap is complete
    echo -e "\nRemoving bootstrap resources.\n"
    doctl compute droplet delete bootstrap --force >/dev/null
    aws --endpoint-url $SPACES_ENDPOINT s3 rb $SPACES_BUCKET --force >/dev/null

    # Set the KUBECONFIG so subsequent oc or kubectl commands can run
    export KUBECONFIG=${PWD}/generated-files/auth/kubeconfig

    # Wait for CSRs to come in and approve them before moving on
    wait_and_approve_CSRs

    # Move the routers to the control plane. This is a hack because
    # currently we only want to run one load balancer.
    move_routers_to_control_plane

    # Wait for the install to complete
    echo -e "\nWaiting for install to complete.\n"
    openshift-install --dir=generated-files  wait-for install-complete

    # Configure DO block storage driver
    # NOTE: this will store your API token in your cluster
    configure_DO_block_storage_driver

    # Configure the registry to use a separate volume created
    # by the DO block storage driver
    fixup_registry_storage
