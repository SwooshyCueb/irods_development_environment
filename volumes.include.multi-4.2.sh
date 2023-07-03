# --- use '-V' option from run_debugger.sh to source this file ---

if [ -d "${DEVROOT:=.}" ] ; then
    DEVROOT=$(realpath "${DEVROOT}")
    exit_code=''
else
    echo Please set DEVROOT to something reasonable
    echo '(For example the parent of the source code'
    echo ' and binary and package output directories)'
    exit_code=126
fi >&2

build_subdir="${OS_NAME}-4.2.x"

declare -A repo_names

repo_names=(
    ["irods"]="irods"
    ["icommands"]="irods_client_icommands"
    ["re_python"]="irods_rule_engine_plugin_python"
    ["re_hard_links"]="irods_rule_engine_plugin_hard_links"
    ["re_logical_quotas"]="irods_rule_engine_plugin_logical_quotas"
    ["re_audit_amqp"]="irods_rule_engine_plugin_audit_amqp"
    ["re_metadata_guard"]="irods_rule_engine_plugin_metadata_guard"
    ["rs_s3"]="irods_resource_plugin_s3"
    ["auth_kerberos"]="irods_auth_plugin_kerberos"
    ["cap_indexing"]="irods_capability_indexing"
    ["cap_publishing"]="irods_capability_publishing"
    ["cap_storage_tiering"]="irods_capability_storage_tiering"
    #["client_gloubs_connector"]="irods_client_gloubs_connector"
    ["client_rest_cpp"]="irods_client_rest_cpp"
    #["client_cli"]="irods_client_cli"
    ["msi_curl"]="irods_microservice_plugins_curl"
)

volumes_rw=(
    ["/irods_packages"]="${DEVROOT}/builds/${build_subdir}/packages"
    ["/irods_build_cache"]="${DEVROOT}/builds/${build_subdir}/ccache"
)

volumes_ro=(
    ["/externals"]="${DEVROOT}/externals"
)

for repo_short in "${!repo_names[@]}"; do
    repo_long="${repo_names[$repo_short]}"
    volumes_ro["/${repo_short}_source"]="${DEVROOT}/${repo_long}"
    volumes_rw["/${repo_short}_build"]="${DEVROOT}/builds/${build_subdir}/${repo_short}"
done

for d in "${!volumes_rw[@]}"; do
    volpath="${volumes_rw[$d]}"
    if [ ! -e "${volpath}" ]; then
        mkdir -p "${volpath}"
    fi
done
for d in "${!volumes_ro[@]}"; do
    volpath="${volumes_ro[$d]}"
    if [ ! -e "${volpath}" ]; then
        echo "path '${volpath}' for read-only volume ${d} does not exist" >&2
        exit_code=126
    fi
done