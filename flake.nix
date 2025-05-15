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
                                                        user-environment =
                                                            pkgs.buildFHSUserEnv
                                                                {
                                                                    extraBwrapArgs = [ "--bind $MOUNT /mount" ] ;
                                                                    name = "user-environment" ;
                                                                    runScript = "${ generator generation-parameters }/bin/${ generator-name }" ;
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
                                                                DIRECTORY="${ stash-directory }/$HASH"
                                                                mkdir --parents "${ stash-directory }"
                                                                LOCK="$DIRECTORY.lock"
                                                                exec 201> "$LOCK"
                                                                flock -x 201
                                                                # shellcheck disable=SC2317
                                                                cleanup( ) {
                                                                    flock -u 201
                                                                    rm --force "$LOCK"
                                                                    rm --force "$STANDARD_INPUT"
                                                                }
                                                                trap cleanup EXIT
                                                                export MOUNT="$DIRECTORY/mount"
                                                                TARGET="$MOUNT/target"
                                                                if [ -d "$DIRECTORY" ]
                                                                then
                                                                    printf '%s\n' "$TARGET"
                                                                    exit 0
                                                                else
                                                                    if [ -e "$DIRECTORY" ]
                                                                    then
                                                                        mv "$DIRECTORY" "$DIRECTORY.trash.$( date +%s )"
                                                                    fi
                                                                    mkdir --parents "$DIRECTORY"
                                                                    printf '%s' "$@" > "$DIRECTORY/arguments"
                                                                    printf '%s' "$STANDARD_INPUT" > "$DIRECTORY/standard-input"
                                                                    printf '%s' "$HAS_STANDARD_INPUT" > "$DIRECTORY/has-standard-input"
                                                                    mkdir --parents "$MOUNT"
                                                                    if $HAS_STANDARD_INPUT
                                                                    then
                                                                        if ${ user-environment }/bin/user-environment "$@" < "$STANDARD_INPUT" > "$DIRECTORY/standard-output" 2> "$DIRECTORY/standard-error"
                                                                        then
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$DIRECTORY/status"
                                                                            if [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ! -name target -quit | wc --lines )" == "0" ]
                                                                            then
                                                                                printf '%s\n' "$TARGET"
                                                                                exit 0
                                                                            else
                                                                            mv "$DIRECTORY" "$DIRECTORY.garbage.$( date +%s )"
                                                                                exit 64
                                                                            fi
                                                                        else
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$DIRECTORY/status"
                                                                            mv "$DIRECTORY" "$DIRECTORY.failed.$( date +%s)"
                                                                            exit "$STATUS"
                                                                        fi
                                                                    else
                                                                        if ${ user-environment }/bin/user-environment "$@" > "$DIRECTORY/standard-output" 2> "$DIRECTORY/standard-error"
                                                                        then
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$DIRECTORY/status"
                                                                            if [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ! -name target -quit | wc --lines )" == "0" ]
                                                                            then
                                                                                printf '%s\n' "$TARGET"
                                                                                exit 0
                                                                            else
                                                                            mv "$DIRECTORY" "$DIRECTORY.garbage.$( date +%s )"
                                                                                exit 64
                                                                            fi
                                                                        else
                                                                            STATUS=$?
                                                                            echo "$STATUS" > "$DIRECTORY/status"
                                                                            mv "$DIRECTORY" "$DIRECTORY.failed.$( date +%s)"
                                                                            exit "$STATUS"
                                                                        fi
                                                                    fi
                                                                fi
                                                            '' ;
                                            } ;
                            } ;
            in flake-utils.lib.eachDefaultSystem fun ;
}