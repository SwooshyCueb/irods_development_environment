#! /bin/bash -e

set -x

usage() {
cat <<_EOF_
Builds iRODS repository, installs the dev/runtime packages, and then builds iCommands

Available options:

    --core-only             Only builds the iRODS packages
    --icommands-only        Only builds the iCommands packages
    --irods-repo-url        Git URL to remote iRODS repository to clone and build
    --irods-commitish       Commit-ish (sha, branch, tag, etc.) to checkout in iRODS
    --icommands-repo-url    Git URL to remote iCommands repository to clone and build
    --icommands-commitish   Commit-ish (sha, branch, tag, etc.) to checkout in iCommands
    -C, --ccache            Enables ccache for rapid subsequent builds
    -d, --debug             Build with symbols for debugging
    -j, --jobs              Number of jobs for make tool
    -N, --ninja             Use ninja builder as the make tool
    --exclude-unit-tests    Indicates that iRODS unit tests should not be built. Not
                            compatible with --enable-all-tests.
    --exclude-microservice-tests
                            Indicates that iRODS tests implemented as microservices
                            should not be built. Not compatible with --enable-all-tests.
    --enable-all-tests      Indicates that IRODS_ENABLE_ALL_TESTS CMake option should be
                            enabled. If specified, all targets used only in testing will
                            built.
    --enable-address-sanitizer
                            Indicates that Address Sanitizer should be enabled
    --enable-undefined-behavior-sanitizer
                            Indicates that Undefined Behavior Sanitizer should be enabled
    --enable-undefined-behavior-sanitizer-implicit-conversion
                            Indicates that the implicit conversion check of Undefined
                            Behavior Sanitizer should be enabled
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
        pkg_files=()
        for pkg_file in "$@"; do
            pkg_files+=("$(realpath "${pkg_file}")")
        done
        apt-get update
        apt-get install -y --allow-downgrades "${pkg_files[@]}"
    elif [ "${package_manager}" == "yum" ] ; then
        yum install -y "$@"
    elif [ "${package_manager}" == "dnf" ] ; then
        dnf install -y "$@"
    fi
}

core_only=0
icommands_only=0
irods_repo_url="https://github.com/irods/irods"
irods_commitish="main"
icommands_repo_url="https://github.com/irods/irods_client_icommands"
icommands_commitish="main"
make_program="make"
make_program_config=""
build_jobs=0
debug_config="-DCMAKE_BUILD_TYPE=Release"
enable_asan="-DIRODS_ENABLE_ADDRESS_SANITIZER=NO"
custom_externals=""
include_unit_tests=1
unit_test_config="-DIRODS_UNIT_TESTS_BUILD=YES -DIRODS_UNIT_TESTS_ENABLE_ALL=YES -DIRODS_ENABLE_ALL_TESTS=YES"
include_microservice_tests=1
msi_test_config="-DIRODS_MICROSERVICE_TEST_PLUGINS_BUILD=YES"
enable_all_tests=0
all_tests_config=""

common_cmake_args=(
    -DCMAKE_COLOR_MAKEFILE=ON
    -DCMAKE_VERBOSE_MAKEFILE=ON
    -DIRODS_BUILD_WITH_WERROR=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

while [ -n "$1" ] ; do
    case "$1" in
        --core-only)                  core_only=1;;
        --icommands-only)             icommands_only=1;;
        --irods-repo-url)             shift; irods_repo_url="$1";;
        --irods-commitish)            shift; irods_commitish="$1";;
        --icommands-repo-url)         shift; icommands_repo_url="$1";;
        --icommands-commitish)        shift; icommands_commitish="$1";;
        -N|--ninja)                   make_program_config="-GNinja";
                                      make_program="ninja";;
        -j|--jobs)                    shift; build_jobs=$(($1 + 0));;
        -d|--debug)                   debug_config="-DCMAKE_BUILD_TYPE=Debug -DCPACK_DEBIAN_COMPRESSION_TYPE=none";;
        -C|--ccache)                  common_cmake_args+=(-DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER_LAUNCHER=ccache);;
        --exclude-unit-tests)         include_unit_tests=0;;
        --exclude-microservice-tests) include_microservice_tests=0;;
        --enable-all-tests)           enable_all_tests=1;;
        --enable-address-sanitizer)   enable_asan="-DIRODS_ENABLE_ADDRESS_SANITIZER=YES";;
        --enable-undefined-behavior-sanitizer)   enable_ubsan="-DIRODS_ENABLE_UNDEFINED_BEHAVIOR_SANITIZER=YES";;
        --enable-undefined-behavior-sanitizer-implicit-conversion)    enable_ubsan_implicit_conversion="-DIRODS_ENABLE_UNDEFINED_BEHAVIOR_SANITIZER_IMPLICIT_CONVERSION_CHECK=YES";;
        --custom-externals)           shift; custom_externals=$1;;
        -h|--help)                    usage;;
    esac
    shift
done

# Interpret options regarding building and enabling (or not) unit tests, microservice tests, and all the other tests.
if [[ ${enable_all_tests} -eq 1 ]] ; then
    if [[ ${include_unit_tests} -eq 0 || ${include_microservice_tests} -eq 0 ]] ; then
        echo "--exclude-unit-tests and --exclude-microservice-tests are incompatible with --enable-all-tests"
        exit 1
    fi
    # This config must be explicitly set to YES/ON in order to be enabled.
    all_tests_config="-DIRODS_ENABLE_ALL_TESTS=YES -DIRODS_UNIT_TESTS_ENABLE_ALL=YES -DIRODS_TEST_EXECUTABLES_BUILD=YES"
else
    if [[ ${include_unit_tests} -eq 0 ]] ; then
        unit_test_config="-DIRODS_UNIT_TESTS_BUILD=NO -DIRODS_UNIT_TESTS_ENABLE_ALL=NO"
    fi
    if [[ ${include_microservice_tests} -eq 0 ]] ; then
        msi_test_config="-DIRODS_MICROSERVICE_TEST_PLUGINS_BUILD=NO"
    fi
fi

if [[ ! -z ${custom_externals} ]] ; then
    install_packages "${custom_externals}"/irods-externals-*."${file_extension}"
fi

build_jobs=$(( !build_jobs ? $(nproc) - 1 : build_jobs )) #prevent maxing out CPUs

irods_components=(
    "icommands"
    #"auth_kerberos"
    "auth_pam_interactive"
    "cap_indexing"
    #"cap_publishing"
    "cap_storage_tiering"
    #"client_cli"
    #"client_globus"
    "client_http_api"
    "client_s3_cpp"
    "msi_curl"
    #"suite_netcdf"
    #"fw_policy_comp"
    "rs_s3"
    "re_audit_amqp"
    "re_logical_quotas"
    "re_metadata_guard"
    "re_python"
    #"re_policy"
)

declare -A irods_components_opts
irods_components_opts=(
    ["icommands"]=""
    ["auth_kerberos"]=""
    ["auth_pam_interactive"]=""
    ["cap_indexing"]=""
    ["cap_publishing"]=""
    ["cap_storage_tiering"]=""
    ["client_cli"]="nopackage"
    ["client_http_api"]=""
    ["client_s3_cpp"]=""
    ["msi_curl"]=""
    ["suite_netcdf"]=""
    ["fw_policy_comp"]=""
    ["rs_s3"]=""
    ["re_audit_amqp"]=""
    ["re_logical_quotas"]=""
    ["re_metadata_guard"]=""
    ["re_python"]=""
    ["re_policy"]=""
)

invalid_component_opt()
{
    echo "Invalid component option $@"
    echo "Valid options are:"
    echo "    nopackage : use 'all' as default make target intstead of 'package'"
    exit 65
} >&2

# skip building iRODS packages if --icommands-only was used
if [[ ${icommands_only} -eq 0 ]] ; then
    echo "========================================="
    echo "beginning build of iRODS server"
    echo "========================================="

    # Build iRODS
    mkdir -p /irods_build && cd /irods_build
    cmake ${make_program_config} ${debug_config} "${common_cmake_args[@]}" ${unit_test_config} ${msi_test_config} ${all_tests_config} ${enable_asan} ${enable_ubsan} ${enable_ubsan_implicit_conversion} /irods_source
    if [[ -z ${build_jobs} ]] ; then
        ${make_program} package
    else
        echo "using [${build_jobs}] threads"
        ${make_program} -j ${build_jobs} package
    fi

    # Copy packages to mounts
    cp -r /irods_build/*."${file_extension}" /irods_packages/

fi

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
    cmake ${make_program_config} ${debug_config} "${common_cmake_args[@]}" ${enable_asan} ${enable_ubsan} ${enable_ubsan_implicit_conversion} "/${icomponent}_source"

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
