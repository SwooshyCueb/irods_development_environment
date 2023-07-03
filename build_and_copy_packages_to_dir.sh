#! /bin/bash -e

set -x

usage() {
cat <<_EOF_
Builds iRODS repository, installs the dev/runtime packages, and then builds iCommands

Available options:

    --core-only             Only builds the core
    -C, --ccache            Enables ccache for rapid subsequent builds
    -d, --debug             Build with symbols for debugging
    -j, --jobs              Number of jobs for make tool
    -N, --ninja             Use ninja builder as the make tool
    --exclude-unit-tests    Indicates that iRODS unit tests should not be built
    --exclude-microservice-tests
                            Indicates that iRODS tests implemented as microservices
                            should not be built
    --custom-externals      Path to custom externals packages received via volume mount
    -h, --help              This message
_EOF_
    exit
}

if [[ -z ${package_manager} ]] ; then
    echo "\$package_manager not defined"
    exit 1
fi

if [[ -z ${file_extension} ]] ; then
    echo "\$file_extension not defined"
    exit 1
fi

supported_package_manager_frontends=(
    "apt-get"
    "yum"
    "dnf"
)

if [[ ! " ${supported_package_manager_frontends[*]} " =~ " ${package_manager} " ]]; then
    echo "unsupported platform or package manager"
    exit 1
fi

install_packages() {
    if [ "${package_manager}" == "apt-get" ] ; then
        apt-get update
        dpkg -i "$@" || true
        apt-get install -fy --allow-downgrades
        for pkg_file in "$@" ; do
            pkg_name="$(dpkg-deb --field "${pkg_file}" Package)"
            pkg_arch="$(dpkg-deb --field "${pkg_file}" Architecture)"
            pkg_vers="$(dpkg-deb --field "${pkg_file}" Version)"

            pkg_vers_inst="$(dpkg-query  --showformat='${Version}' --show "${pkg_name}:${pkg_arch}")" ||
                (echo "could not verify installation of ${pkg_file}" && exit 1)
            if [ "${pkg_vers}" == "${pkg_vers_inst}" ] ; then
                echo "installed version of ${pkg_name}:${pkg_arch} does not match ${pkg_file}"
            fi
        done
    elif [ "${package_manager}" == "yum" ] ; then
        yum install -y "$@"
    elif [ "${package_manager}" == "dnf" ] ; then
        dnf install -y "$@"
    fi
}

core_only=0
make_program="make"
make_program_config=""
build_jobs=0
debug_config="-DCMAKE_BUILD_TYPE=Release"
unit_test_config="-DIRODS_UNIT_TESTS_BUILD=YES"
msi_test_config="-DIRODS_MICROSERVICE_TEST_PLUGINS_BUILD=YES"
custom_externals=""

common_cmake_args=(
    -DCMAKE_COLOR_MAKEFILE=ON
    -DCMAKE_VERBOSE_MAKEFILE=ON
    -DIRODS_BUILD_WITH_WERROR=OFF
)

while [ -n "$1" ] ; do
    case "$1" in
        --core-only)                  core_only=1;;
        -N|--ninja)                   make_program_config="-GNinja";
                                      make_program="ninja";;
        -j|--jobs)                    shift; build_jobs=$(($1 + 0));;
        -d|--debug)                   debug_config="-DCMAKE_BUILD_TYPE=Debug -DCPACK_DEBIAN_COMPRESSION_TYPE=none";;
        -C|--ccache)                  common_cmake_args+=(-DCMAKE_CXX_COMPILER_LAUNCHER=ccache);;
        --exclude-unit-tests)         unit_test_config="-DIRODS_UNIT_TESTS_BUILD=NO";;
        --exclude-microservice-tests) msi_test_config="-DIRODS_MICROSERVICE_TEST_PLUGINS_BUILD=NO";;
        --custom-externals)           shift; custom_externals=$1;;
        -h|--help)                    usage;;
    esac
    shift
done

if [[ ! -z ${custom_externals} ]] ; then
    install_packages "${custom_externals}"/irods-externals-*."${file_extension}"
fi

build_jobs=$(( !build_jobs ? $(nproc) - 1 : build_jobs )) #prevent maxing out CPUs

echo "========================================="
echo "beginning build of iRODS server"
echo "========================================="

# Build iRODS
mkdir -p /irods_build && cd /irods_build
cmake ${make_program_config} ${debug_config} "${common_cmake_args[@]}" ${unit_test_config} ${msi_test_config} /irods_source
if [[ -z ${build_jobs} ]] ; then
    ${make_program} package
else
    echo "using [${build_jobs}] threads"
    ${make_program} -j ${build_jobs} package
fi

# Copy packages to mounts
cp -r /irods_build/*."${file_extension}" /irods_packages/

# stop if --core-only option was used
if [[ ${core_only} -gt 0 ]] ; then
    exit
fi

# Install packages for building other components
if [ "${file_extension}" == "rpm" ] ; then
    install_packages /irods_build/irods-{runtime,devel}*."${file_extension}"
else
    install_packages /irods_build/irods-{runtime,dev}*."${file_extension}"
fi

irods_components=(
    "icommands"
    #"auth_kerberos"
    #"cap_indexing"
    #"cap_publishing"
    #"cap_storage_tiering"
    #"client_rest_cpp"
    #"msi_curl"
    #"rs_s3"
    #"re_audit_amqp"
    #"re_hard_links"
    #"re_logical_quotas"
    #"re_metadata_guard"
    "re_python"
    # 4.3 only
    #"client_cli"
)

declare -A irods_components_opts
irods_components_opts=(
    ["icommands"]=""
    ["re_python"]=""
    ["re_hard_links"]=""
    ["re_logical_quotas"]=""
    ["re_audit_amqp"]=""
    ["re_metadata_guard"]=""
    ["rs_s3"]=""
    ["auth_kerberos"]=
    ["cap_indexing"]=""
    ["cap_publishing"]=""
    ["cap_storage_tiering"]=""
    ["msi_curl"]=""
    ["client_rest_cpp"]=""
    # 4.3 only
    ["client_cli"]="nopackage"
)

invalid_component_opt()
{
    echo "Invalid component option $@"
    echo "Valid options are:"
    echo "    nopackage : use 'all' as default make target intstead of 'package'"
    exit 65
} >&2

for icomponent in "${irods_components[@]}"; do

    echo "========================================="
    echo "beginning build of ${icomponent}"
    echo "========================================="

    make_targets="package"
    nopkgs=""

    if [ -n "${irods_components_opts[$icomponent]}" ] ; then
        for copt in "${irods_components_opts[$icomponent]}" ; do
            case "$copt" in
                nopackage)               make_targets="all"; nopkgs=y;;
                *)                       invalid_component_opt "$copt";;
            esac
        done
    fi

    mkdir -p "/${icomponent}_build" && cd "/${icomponent}_build"
    cmake ${make_program_config} ${debug_config} "${common_cmake_args[@]}" "/${icomponent}_source"

    # Build component
    if [[ -z ${build_jobs} ]]; then
        ${make_program} ${make_targets}
    else
        echo "using [${build_jobs}] threads"
        ${make_program} -j ${build_jobs} ${make_targets}
    fi

    if [ -z "${nopkgs}" ] ; then

        # Copy packages to mounts
        cp -r "/${icomponent}_build/"*."${file_extension}" /irods_packages/

        # Test install packages
        #install_packages "/${icomponent}_build/"*."${file_extension}"
    fi

done
