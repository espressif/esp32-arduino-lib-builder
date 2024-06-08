#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~ DEUG DEBUG DEBUG DEBUG DEUG DEBUG DEBUG DEBUG  DEBUG DEBUG DEBUG
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if [ -z $SH_ROOT]; then
    source ./tools/config.sh
    source ./prettiyfiHelpers.sh
    # Import all environment variables from file
    oneUpDir=$(realpath $(pwd)/../) # DIR above the current directory
    echo "Load: $oneUpDir/env_variables-afterBuild-Debug.sh" 
    source "$oneUpDir/env_variables-afterBuild-Debug.sh"
fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# -------------------------------
# PIO Folder = from build output 
# -------------------------------
OUT_PIO=$oneUpDir/PIO-Out/framework-arduinoespressif32
OUT_PIO_Dist=$(realpath $OUT_PIO/../)/Dist 
mkdir -p dist $OUT_PIO # Make sure Folder exists
#-----------------------------------------
# Messag: Start Creating content
#-----------------------------------------
echo -e "-- Create PlatformIO 'framework-arduinoespressif32' form build (copying...)"
echo -e "   with:$eUS $SH_ROOT/tools/archive-build-JA.sh $TG $TARGET $eNO"
echo -e "   in: $(shortFP $OUT_PIO)"
#################################################
# Create PIO - framework-arduinoespressif32  
##################################################
#-----------------------------------------
# PIO 'cores/esp32' - FOLDER
#-----------------------------------------
mkdir -p $OUT_PIO/cores/esp32
cp -rf $ArduionoCOMPS/cores $OUT_PIO            # cores-Folder      from 'arduino-esp32'  -IDF Components (GitSource)
#-----------------------------------------
# PIO 'tools' - FOLDER
#-----------------------------------------
mkdir -p $OUT_PIO/tools/partitions
cp -rf $ArduionoCOMPS/tools $OUT_PIO            # tools-Folder      from 'arduino-esp32'  -IDF Components (GitSource)
cp -rf $AR_OWN_OUT/tools/esp32-arduino-libs $OUT_PIO/tools/  # from 'esp32-arduino-libs'             (BUILD output-libs) 
#-----------------------------------------
# PIO 'libraries' - FOLDER
#-----------------------------------------
cp -rf $ArduionoCOMPS/libraries $OUT_PIO        # libraries-Folder  from 'arduino-esp32'  -IDF Components (GitSource)
#-----------------------------------------
# PIO 'variants' - FOLDER
#-----------------------------------------
cp -rf $ArduionoCOMPS/variants $OUT_PIO         # variants-Folder   from 'arduino-esp32   -IDF Components (GitSource)
#-----------------------------------------
# PIO Single FILES
#-----------------------------------------
cp -f $ArduionoCOMPS/CMakeLists.txt $OUT_PIO    # CMakeLists.txt    from 'arduino-esp32'  -IDF Components (GitSource)
cp -rf $ArduionoCOMPS/idf_* $OUT_PIO            # idf.py            from 'arduino-esp32'  -IDF Components (GitSource)
cp -f $ArduionoCOMPS/Kconfig.projbuild $OUT_PIO # Kconfig.projbuild from 'arduino-esp32'  -IDF Components (GitSource)
#---------------------------------- 
# Create NEW file: cores/esp32/                 # core_version.h    from 'arduino-esp32' & 'esp-idf'  -IDF Components (GitSource)
#---------------------------------- 
# Get needed Info's for this file
AR_Commit_short=$(git -C "$ArduionoCOMPS" rev-parse --short HEAD || echo "") # Short commit hash of the 'arduino-esp32'
AR_VERSION=$(jq -c '.version' "$ArduionoCOMPS/package.json" | tr -d '"')     # Version of the 'arduino-esp32'
    AR_VERSION_UNDERSCORE=`echo "$AR_VERSION" | tr . _`                      # Replace dots with underscores
IDF_Commit_short=$(git -C "$IDF_PATH" rev-parse --short HEAD || echo "")     # Short commit hash of the 'esp-idf'
#--------------------------------------
# Create/write the core_version.h file
#--------------------------------------
echo -e "-- Adding core_version.h (creating...)"
echo -e "   to $(shortFP $OUT_PIO/cores/esp32/core_version.h)"
cat <<EOL > $OUT_PIO/cores/esp32/core_version.h
#define ARDUINO_ESP32_GIT_VER 0x$AR_Commit_short
#define ARDUINO_ESP32_GIT_DESC $AR_VERSION
#define ARDUINO_ESP32_RELEASE_$AR_VERSION_UNDERSCORE
#define ARDUINO_ESP32_RELEASE "$AR_VERSION_UNDERSCORE"
EOL
#---------------------------------------------
# Generate PIO framework manifest file            # package.json      from 'arduino-esp32' & 'esp-idf'  -IDF Components (GitSource)
#-------------------------------------------- 
echo -e "-- Adding PIO framework manifest (creating...)"
echo -e "   to $(shortFP $OUT_PIO/package.json)"
if [ "$BUILD_TYPE" = "all" ]; then
    python3 $SH_ROOT/tools/PIO-gen_frmwk_manifest.py -o "$OUT_PIO/" -s "v$AR_VERSION" -c "$IDF_COMMIT"
    if [ $? -ne 0 ]; then exit 1; fi
fi
# ------------------------------------------------
 # Write release-info that will be added archive
# ------------------------------------------------
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) # Get current branch of used esp32-arduiono-lib-builder
echo -e "-- Creating release-info.txt used for publishing (creating...)"
echo -e "   to $(shortFP $OUT_PIO/release-info.txt)"
cat <<EOL > $OUT_PIO/release-info.txt
Framework built from resources:

-- $IDF_REPO
 * branch [$IDF_BRANCH]
   https://github.com/$IDF_REPO/tree/$IDF_BRANCH
 * commit [$IDF_Commit_short]
   https://github.com/$IDF_REPO/commits/$IDF_BRANCH/#:~:text=$IDF_Commit_short

-- $AR_REPO
 * branch [$AR_BRANCH]
   https://github.com/$AR_REPO/tree/$AR_BRANCH
 * commit [$AR_Commit_short]
   https://github.com/$AR_REPO/commits/$AR_BRANCH/#:~:text=$AR_Commit_short

build with:
-- esp32-arduino-lib-builder
   * branch [$GIT_BRANCH]
     https://github.com/twischi/esp32-arduino-lib-builder.git
EOL
#-----------------------------------------
# Message create archive
#-----------------------------------------
echo -e "   Arranging PIO-Framwork-Files DONE"
echo -e "-- Creating Archive-File (compessing...)"
#---------------------------------------------------------
# Set variables for the archive file tar.gz or zip 
#---------------------------------------------------------
idfVersStr=${IDF_BRANCH//\//_}"-$IDF_COMMIT"                   # Create IDF version string
pioArchFN="framework-arduinoespressif32-$idfVersStr.tar.gz"    # Name of the archive
echo -e "   in: $(shortFP $OUT_PIO_Dist)"
echo -e "   with Filename:$ePF $pioArchFN $eNO"
pioArchFP="$OUT_PIO_Dist/$pioArchFN"                           # Full path of the archive
# ---------------------------------------------
# Create the Archive with tar
# ---------------------------------------------
cd $OUT_PIO/..         # Step to source-Folder
rm -f pioArchFP        # Remove potential old file
mkdir -p $OUT_PIO_Dist # Make sure Folder exists
#          <target>     <source> in currtent dir 
tar -zcf $pioArchFP framework-arduinoespressif32/
echo -e "   PIO DONE!"

# SUBSTITUTIONS
################
# cd out & '../components/arduino'    >>  $ArduionoCOMPS
#---
# cd out & 'tools/esp32-arduino-libs' >>  $AR_OWN_OUT/tools/esp32-arduino-libs
#---
# cd out & '..'                       >>  $SH_ROOT

