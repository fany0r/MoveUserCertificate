#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}


# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != 1 ]; do
    /system/bin/sleep 1s
done

# set variable
TEMP_DIR="/data/local/tmp/tmp-ca-copy"
SYSTEM_CACERTS="/system/etc/security/cacerts"
USER_CACERTS="/data/misc/user/0/cacerts-added"
APEX_CACERTS="/apex/com.android.conscrypt/cacerts"

# Create a separate temp directory, to hold the current certificates
# Without this, when we add the mount we can't read the current certs anymore.
mkdir -p -m 700 $TEMP_DIR

# Copy out the existing certificates
if [ -d $APEX_CACERTS ]; then
    cp $APEX_CACERTS/* $TEMP_DIR/
else
    cp $SYSTEM_CACERTS/* $TEMP_DIR/
fi

# Create the in-memory mount on top of the system certs folder
mount -t tmpfs tmpfs $SYSTEM_CACERTS

# Copy the existing certs back into the tmpfs mount, so we keep trusting them
mv $TEMP_DIR/* $SYSTEM_CACERTS/

# Copy user cert in, so we trust that too
cp $USER_CACERTS/* $SYSTEM_CACERTS/

# Update the perms & selinux context labels, so everything is as readable as before
chown root:root $SYSTEM_CACERTS/*
chmod 644 $SYSTEM_CACERTS/*
chcon u:object_r:system_file:s0 $SYSTEM_CACERTS/*

log -t Magisk "System cacerts setup completed"

# Deal with the APEX overrides in Android 14+, which need injecting into each namespace:
if [ -d $APEX_CACERTS ]; then
    log -t Magisk "Injecting certificates into APEX cacerts"

    # When the APEX manages cacerts, we need to mount them at that path too. We can't do
    # this globally as APEX mounts are namespaced per process, so we need to inject a
    # bind mount for this directory into every mount namespace.

    # First we get the Zygote process(es), which launch each app
    ZYGOTE_PID=$(pidof zygote || true)
    ZYGOTE64_PID=$(pidof zygote64 || true)
    Z_PIDS="$ZYGOTE_PID $ZYGOTE64_PID"
    # N.b. some devices appear to have both, some have >1 of each (!)

    # Apps inherit the Zygote's mounts at startup, so we inject here to ensure all newly
    # started apps will see these certs straight away:
    for Z_PID in $Z_PIDS; do
        if [ -n "$Z_PID" ]; then
            /system/bin/nsenter --mount=/proc/$Z_PID/ns/mnt -- /bin/mount --bind $SYSTEM_CACERTS $APEX_CACERTS
        fi
    done

    log -t Magisk "Zygote APEX certificates remounted"

    # Then we inject the mount into all already running apps, so they see these certs immediately.

    # Get the PID of every process whose parent is one of the Zygotes:
    APP_PIDS=$(echo $Z_PIDS | xargs -n1 ps -o 'PID' -P | grep -v PID)

    # Inject into the mount namespace of each of those apps:
    for PID in $APP_PIDS; do
        /system/bin/nsenter --mount=/proc/$PID/ns/mnt -- /bin/mount --bind $SYSTEM_CACERTS $APEX_CACERTS &
    done
    wait # Launched in parallel - wait for completion here

    log -t Magisk "APEX certificates remounted for $(echo $APP_PIDS | wc -w) apps"
fi

# Delete the temp cert directory & this script itself
rm -rf $TEMP_DIR

log -t Magisk "User credentials were successfully imported into the system zone."
