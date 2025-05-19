{
    inputs = { visitor.url = "github:viktordanek/visitor/scratch/d926f8ea-1fdc-441c-9fd9-8abbc5e13fdf" ; } ;
    outputs =
        { self , visitor } :
            {
                lib.generator =
                    {
                        factory-name ,
                        hash-length ? 128 ,
                        generator ,
                        generator-name ,
                        generation-parameters ,
                        nixpkgs ,
                        path ? null ,
                        stash-directory ,
                        system ,
                        targets ? [ ]
                    } :
                        let
                            pkgs = nixpkgs.legacyPackages.${ primary.system } ;
                            primary =
                                {
                                    factory-name =
                                        visitor.lib.implementation
                                            {
                                                string = path : value : value ;
                                            }
                                            factory-name ;
                                    hash-length =
                                        visitor.lib.implementation
                                            {
                                                int = path : value : builtins.toString value ;
                                            }
                                            hash-length ;
                                    generator =
                                        visitor.lib.implementation
                                            {
                                                lambda = path : value : value ;
                                            }
                                            generator ;
                                    generation-parameters =
                                        visitor.lib.implementation
                                            {
                                                null = path : value : { } ;
                                                set = path : set : set ;
                                            }
                                            generation-parameters ;
                                    generator-name =
                                        visitor.lib.implementation
                                            {
                                                string = path : value : value ;
                                            }
                                            generator-name ;
                                    path =
                                        visitor.lib.implementation
                                            {
                                                int = path : value : [ path value ] ;
                                                null = path : value : [ path value ] ;
                                                string = path : value : [ path value ] ;
                                            }
                                            path ;
                                    stash-directory =
                                        visitor.lib.implementation
                                            {
                                                string = path : value : value ;
                                            }
                                            stash-directory ;
                                    system =
                                        visitor.lib.implementation
                                            {
                                                string = path : value : value ;
                                            }
                                            system ;
                                    targets =
                                        visitor.lib.implementation
                                            {
                                                string = path : value : value ;
                                            }
                                            targets ;
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
                                                        primary.factory-name
                                                        primary.hash-length
                                                        primary.generator-name
                                                        primary.path
                                                        primary.stash-directory
                                                        primary.system
                                                        primary.targets
                                                        user-environment
                                                    ] ;
                                                user-environment =
                                                    pkgs.buildFHSUserEnv
                                                        {
                                                            extraBwrapArgs = [ "--bind $MOUNT /mount" ] ;
                                                            name = "user-environment" ;
                                                            runScript = "${ generator generation-parameters }/bin/${ primary.generator-name }" ;
                                                        } ;
                                                in
                                                    ''
                                                        set -e
                                                        STANDARD_INPUT="$( mktemp )"
                                                        if [ -f /proc/self/fd/0 ] || [ -p /proc/self/fd/0 ]
                                                        then
                                                            HAS_STANDARD_INPUT=true
                                                            tee > "$STANDARD_INPUT"
                                                        else
                                                            HAS_STANDARD_INPUT=false
                                                        fi
                                                        HASH="$( echo ${ input-hash } "$@" "$HAS_STANDARD_INPUT" "$( cat "$STANDARD_INPUT" )" | sha512sum | cut -c1-${ primary.hash-length } )"
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
                                                            echo "$@" > "$DIRECTORY/arguments"
                                                            cat "$STANDARD_INPUT" > "$DIRECTORY/standard-input"
                                                            printf '%s' "$HAS_STANDARD_INPUT" > "$DIRECTORY/has-standard-input"
                                                            mkdir --parents "$MOUNT"
                                                            process_success( ) {
                                                                echo "$1" > "$DIRECTORY/status"
                                                                if [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 \( ${ builtins.concatStringsSep " -o " ( builtins.map ( target : "-name ${ target }" ) primary.targets ) } \) | wc --lines )" != "${ builtins.toString ( builtins.length primary.targets ) }" ]
                                                                then
                                                                    echo 64 > "$DIRECTORY/FAILURE"
                                                                    mv "$DIRECTORY" "$( mktemp --dry-run "$DIRECTORY.XXXXXXXX" )"
                                                                    exit 64
                                                                elif [ "$( find "$MOUNT" -mindepth 1 -maxdepth 1 ${ builtins.concatStringsSep " " ( builtins.map ( target : "! -name ${ target }" ) primary.targets ) } -quit | wc --lines )" != "0" ]
                                                                then
                                                                    echo 65 > "$DIRECTORY/FAILURE"
                                                                    mv "$DIRECTORY" "$( mktemp --dry-run "$DIRECTORY.XXXXXXXX" )"
                                                                    exit 65
                                                                elif [ -s "$DIRECTORY/standard-error" ]
                                                                then
                                                                    echo 66 > "$DIRECTORY/FAILURE"
                                                                    mv "$DIRECTORY" "$( mktemp --dry-run "$DIRECTORY.XXXXXXXX" )"
                                                                    exit 66
                                                                else
                                                                    printf '%s\n' "$MOUNT"
                                                                    exit 0
                                                                fi
                                                            }
                                                            process_failure( ) {
                                                                echo "$1" > "$DIRECTORY/status"
                                                                echo 67 > "$DIRECTORY/FAILURE"
                                                                mv "$DIRECTORY" "$( mktemp --dry-run "$DIRECTORY.XXXXXXXX" )"
                                                                exit "$1"
                                                            }
                                                            if "$HAS_STANDARD_INPUT"
                                                            then
                                                                if ${ user-environment }/bin/user-environment "$@" < "$STANDARD_INPUT" > "$DIRECTORY/standard-output" 2> "$DIRECTORY/standard-error"
                                                                then
                                                                    process_success "$?"
                                                                else
                                                                    process_failure "$?"
                                                                fi
                                                            else
                                                                if ${ user-environment }/bin/user-environment "$@" > "$DIRECTORY/standard-output" 2> "$DIRECTORY/standard-error"
                                                                then
                                                                    process_success "$?"
                                                                else
                                                                    process_failure "$?"
                                                                fi
                                                            fi
                                                        fi
                                                    '' ;
                                    } ;
            } ;
}