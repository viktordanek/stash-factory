{
    inputs =
        {
            flake-utils.url = "github:numtide/flake-utils" ;
            nixpkgs.url = "github:Nixos/nixpkgs/nixos-23.11" ;
        } ;
    outputs = { flake-utils , nixpkgs , self } :
        let
            fun =
                system :
                    let
                        pkgs = import nixpkgs { inherit system ; } ;
                        in
                            {
                                lib.generator =
                                    {
                                        hash-length ? 128 ,
                                        generator ,
                                        generator-name ,
                                        generation-parameters ,
                                        name ,
                                        stash-directory ,
                                        time-mask
                                    } :
                                        pkgs.writeShellApplication
                                            {
                                                name = name ;
                                                runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.flock ] ;
                                                text =
                                                    let
                                                        input-hash = builtins.hashString "sha512" ( builtins.toJSON object ) ;
                                                        object =
                                                            {
                                                                hash-length = hash-length ;
                                                                generated = builtins.toString ( generator generation-parameters ) ;
                                                                stash-directory = stash-directory ;
                                                                time-mask = time-mask ;
                                                            } ;
                                                        in
                                                            ''
                                                                set -e
                                                                TIMESTAMP="$( date "+${ time-mask }" )"
                                                                STANDARD_INPUT="$( mktemp )"
                                                                if [ -f /proc/self/fd/0 ] || [ -p /proc/self/fd/0 ]
                                                                then
                                                                    HAS_STANDARD_INPUT=true
                                                                    tee > "$STANDARD_INPUT"
                                                                else
                                                                    HAS_STANDARD_INPUT=false
                                                                fi
                                                                HASH="$( printf "%s%s" "${ input-hash }" "$TIMESTAMP" "$@" "$HAS_STANDARD_INPUT" "$( cat "$STANDARD_INPUT" )" | sha512sum | cut -c1-${ builtins.toString hash-length } )"
                                                                MOUNT="${ stash-directory }/$HASH"
                                                                mkdir --parents "${ stash-directory }"
                                                                LOCK="$MOUNT.lock"
                                                                exec 201> "$LOCK"
                                                                flock -x 201
                                                                # shellcheck disable=SC2317
                                                                cleanup ( ) {
                                                                    flock -u 201
                                                                    rm --force "$LOCK"
                                                                    rm --force "$STANDARD_INPUT"
                                                                }
                                                                trap cleanup EXIT
                                                                TARGET="$MOUNT/target"
                                                                if [ -d "$MOUNT" ]
                                                                then
                                                                    printf '%s\n' "$TARGET"
                                                                    exit 0
                                                                else
                                                                    if [ -e "$MOUNT" ]
                                                                    then
                                                                        mv "$MOUNT" "$MOUNT.trash.$( date +%s )"
                                                                    fi
                                                                    mkdir --parents "$MOUNT"
                                                                    printf '%s' "$@" > "$MOUNT/arguments"
                                                                    printf '%s' "$STANDARD_INPUT" > "$MOUNT/standard-input"
                                                                    printf '%s' "$HAS_STANDARD_INPUT" > "$MOUNT/has-standard-input"
                                                                    if $HAS_STANDARD_INPUT
                                                                    then
                                                                        if cat $STANDARD_INPUT | ${ generator generation-parameters }/bin/${ generator-name } "$TARGET" "$@" > "$MOUNT/standard-output" 2> "$MOUNT/standard-error"
                                                                        then
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$MOUNT/status"
                                                                            printf '%s\n' "$TARGET"
                                                                            exit 0
                                                                        else
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$MOUNT/status"
                                                                            mv "$MOUNT" "$MOUNT.failed.$( date +%s)"
                                                                            exit "$STATUS"
                                                                        fi
                                                                    else
                                                                        if ${ generator generation-parameters }/bin/${ generator-name } "$TARGET" "$@" > "$MOUNT/standard-output" 2> "$MOUNT/standard-error"
                                                                        then
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$MOUNT/status"
                                                                            printf '%s\n' "$TARGET"
                                                                            exit 0
                                                                        else
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$MOUNT/status"
                                                                            mv "$MOUNT" "$MOUNT.failed.$( date +%s)"
                                                                            exit "$STATUS"
                                                                        fi
                                                                fi
                                                            '' ;
                                            } ;
                            } ;
            in flake-utils.lib.eachDefaultSystem fun ;
}