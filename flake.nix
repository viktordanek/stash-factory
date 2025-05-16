{
    inputs =
        {
            flake-utils.url = "github:numtide/flake-utils" ;
            nixpkgs.url = "github:Nixos/nixpkgs/nixos-23.11" ;
            visitor.url = "github:viktordanek/visitor" ;
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
                                        factory-name ,
                                        hash-length ? 128 ,
                                        generator ,
                                        generator-name ,
                                        generation-parameters ,
                                        path ? null ,
                                        stash-directory ,
                                        targets ? [ ] ,
                                        time-mask
                                    } :
                                        let
                                            primary =
                                                {
                                                    factory-name =
                                                        visitor.lib.${ system }
                                                            {
                                                                string = path : value : value ;
                                                            }
                                                            factory-name ;
                                                    hash-length =
                                                        visitor.lib.${ system }
                                                            {
                                                                int = path : value : value ;
                                                            }
                                                            hash-length ;
                                                    generator =
                                                        visitor.lib.${ system }
                                                            {
                                                                lambda = path : value : value ;
                                                            }
                                                            generator ;
                                                    generation-parameters =
                                                        visitor.lib.${ system }
                                                            {
                                                                null = path : value : { } ;
                                                                set = path : set : set ;
                                                            }
                                                            generation-parameters ;
                                                    generator-name =
                                                        visitor.lib.${ system }
                                                            {
                                                                string = path : value : value ;
                                                            }
                                                            generator-name ;
                                                    path =
                                                        visitor.lib.${ system }
                                                            {
                                                                int = path : value : [ path value ] ;
                                                                null = path : value : [ path value ] ;
                                                                string = path : value : [ path value ] ;
                                                            }
                                                            path ;
                                                    stash-directory =
                                                        visitor.lib.${ system }
                                                            {
                                                                string = path : value : value ;
                                                            }
                                                            stash-directory ;
                                                    targets =
                                                        visitor.lib.${ system }
                                                            {
                                                                string = path : value : value ;
                                                            }
                                                            targets ;
                                                    time-mask =
                                                        visitor.lib.${ system }
                                                            {
                                                                string = path : value : value ;
                                                            }
                                                            time-mask ;
                                                } ;
                                            in
                                                pkgs.writeShellApplication
                                                    {
                                                        name = factory-name ;
                                                        runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.flock ] ;
                                                        text =
                                                            let
                                                                input-hash = builtins.hashString "sha512" ( builtins.toJSON object ) ;
                                                                object =
                                                                    [
                                                                        factory-name
                                                                        hash-length
                                                                        path
                                                                        stash-directory
                                                                        targets
                                                                        time-mask
                                                                        ( builtins.toString user-environment )
                                                                    ] ;
                                                                user-environment =
                                                                    pkgs.buildFHSUserEnv
                                                                        {
                                                                            extraBwrapArgs = [ "--bind $MOUNT /mount" ] ;
                                                                            name = "user-environment" ;
                                                                            runScript = "${ primary.generator primary.generation-parameters }/bin/${ primary.generator-name }" ;
                                                                        } ;
                                                                in
                                                                    ''
                                                                        set -e
                                                                        TIMESTAMP="$( date "+${ primary.time-mask }" )"
                                                                        STANDARD_INPUT="$( mktemp )"
                                                                        if [ -f /proc/self/fd/0 ] || [ -p /proc/self/fd/0 ]
                                                                        then
                                                                            HAS_STANDARD_INPUT=true
                                                                            tee > "$STANDARD_INPUT"
                                                                        else
                                                                            HAS_STANDARD_INPUT=false
                                                                        fi
                                                                        HASH="$( printf "%s%s" "${ input-hash }" "$TIMESTAMP" "$@" "$HAS_STANDARD_INPUT" "$( cat "$STANDARD_INPUT" )" | sha512sum | cut -c1-${ builtins.toString primary.hash-length } )"
                                                                        DIRECTORY="${ primary.stash-directory }/$HASH"
                                                                        mkdir --parents "${ primary.stash-directory }"
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
                                                                        if [ -d "$DIRECTORY" ]
                                                                        then
                                                                            printf '%s\n' "$MOUNT"
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
                                                                                    if [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ${ builtins.concatStringsSep " " ( builtins.map ( target : "-name ${ target }" ) primary.targets ) } | wc --lines )" != "${ builtins.length primary.targets }" ]
                                                                                    then
                                                                                    mv "$DIRECTORY" "$DIRECTORY.target.$( date +%s )"
                                                                                        exit 64
                                                                                    elif [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ${ builtins.concatStringsSep " " ( builtins.map ( target : "! -name ${ target }" ) primary.targets ) } -quit | wc --lines )" != "0" ]
                                                                                    then
                                                                                    mv "$DIRECTORY" "$DIRECTORY.garbage.$( date +%s )"
                                                                                        exit 65
                                                                                    else
                                                                                        printf '%s\n' "$MOUNT"
                                                                                        exit 0
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
                                                                                    if [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ${ builtins.concatStringsSep " " ( builtins.map ( target : "-name ${ target }" ) primary.targets ) } | wc --lines )" != "${ builtins.length primary.targets }" ]
                                                                                    then
                                                                                    mv "$DIRECTORY" "$DIRECTORY.target.$( date +%s )"
                                                                                        exit 64
                                                                                    elif [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ${ builtins.concatStringsSep " " ( builtins.map ( target : "! -name ${ target }" ) primary.targets ) } -quit | wc --lines )" != "0" ]
                                                                                    then
                                                                                    mv "$DIRECTORY" "$DIRECTORY.garbage.$( date +%s )"
                                                                                        exit 65
                                                                                    else
                                                                                        printf '%s\n' "$MOUNT"
                                                                                        exit 0
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