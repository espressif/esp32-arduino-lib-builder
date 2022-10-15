set -e

SUBMODULE=0

while getopts "s" opt; do
    case ${opt} in
        s)
            SUBMODULE=1
            ;;
    esac
done
shift $((OPTIND-1))

DIR=$1
URL=$2

[ -d "$DIR" ] || git clone $URL "$DIR"
git -C "$DIR" fetch
#pull fails if detached
git -C "$DIR" symbolic-ref -q HEAD && git -C "$DIR" pull --ff-only
[ $SUBMODULE -eq 1 ] && git -C "$DIR" submodule update --init --recursive

exit 0
