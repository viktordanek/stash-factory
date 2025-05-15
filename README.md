

generator flake.nix
```
{
    inputs = { } ;
    outputs = { self } :
        {
            lib.generator =
                {
                    generator ,
                    generation-parameters ,
                    stash-directory ,
                    time-mask
                } @primary :
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
                                            HASH="$( printf "%s%s" "${ input-hash }" "$TIMESTAMP" | sha512sum | cut -c1-128 )"
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
}
```

identity flake.nix
{
    inputs = { } ;
    outputs = { self } :
        {
            lib.generator =
                {
                    pkgs
                } :
                    pkgs.writeShellApplication
                        {
                            name = "generate ssh-key" ;
                            runtimeImports = [ pkgs.coreutils pkgs.openssh ] ;
                            text =
                                ''
                                    set -e
                                    mkdir --parents $1 &&
                                    ssh-keygen -f $1/identity -P "" -C ""
                                '' ;
                        } ;
        } ;
}

usage:
generator.generate
    {
        generator = identity.lib.generator ;
        generation-parameters = { pkgs = pkgs ; } ;
        stash-directory = "/tmp/stash" ;
        time-mask = "%Y-%m-%d" ;
    }