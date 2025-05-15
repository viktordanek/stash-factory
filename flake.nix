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
                    {
                        lib.generator =
                            {
                                hash-length ? 128 ,
                                generator ,
                                generation-parameters ,
                                stash-directory ,
                                time-mask
                            } @primary :
                                let
                                    pkgs = import nixpkgs { inherit system ; } ;
                                    in
                                        pkgs.writeShellApplication
                                            {
                                                name = "generic generator" ;
                                                runtimeImports = [ pkgs.coreutils pkgs.findutils pkgs.flock ] ;
                                                text =
                                                    let
                                                        input-hash = builtins.hashString "sha512" ( builtins.toJSON primary ) ;
                                                        in
                                                            ''
                                                                set -e
                                                                TIMESTAMP="$( date "${ time-mask }" )"
                                                                HASH="$( printf "%s%s" "${ input-hash }" "$TIMESTAMP" | sha512sum | cut -c1-${ builtins.toString hash-length } )"
                                                                MOUNT="${ stash-directory }/$HASH"
                                                                mkdir --parents "${ stash-directory }"
                                                                LOCK="$MOUNT.lock"
                                                                exec 201> "$LOCK"
                                                                flock -x 201
                                                                cleanup ( ) {
                                                                    flock -u 201
                                                                    rm --force "$LOCK"
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
                                                                    if ${ generator.generate generation-parameters } "$TARGET" > "$MOUNT/standard-output" 2> "$MOUNT/standard-error"
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