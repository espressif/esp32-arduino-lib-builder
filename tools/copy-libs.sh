#!/bin/bash
# config

IDF_TARGET=$1
IS_XTENSA=$4
OCT_FLASH="$2"
OCT_PSRAM=

if [ "$3" = "y" ]; then
	OCT_PSRAM="opi"
else
	OCT_PSRAM="qspi"
fi
MEMCONF=$OCT_FLASH"_$OCT_PSRAM"

source ./tools/config.sh

echo "IDF_TARGET: $IDF_TARGET, MEMCONF: $MEMCONF, PWD: $PWD, OUT: $AR_SDK"

# clean previous
if [ -e "$AR_SDK/sdkconfig" ]; then
	rm -rf "$AR_SDK/sdkconfig"
fi
if [ -e "$AR_SDK/lib" ]; then
	rm -rf "$AR_SDK/lib"
fi
if [ -e "$AR_SDK/ld" ]; then
	rm -rf "$AR_SDK/ld"
fi
if [ -e "$AR_SDK/include" ]; then
	rm -rf "$AR_SDK/include"
fi
if [ -e "$AR_SDK/flags" ]; then
	rm -rf "$AR_SDK/flags"
fi
if [ -e "$AR_SDK/$MEMCONF" ]; then
	rm -rf "$AR_SDK/$MEMCONF"
fi
if [ -e "$AR_SDK/platformio-build.py" ]; then
	rm -rf "$AR_SDK/platformio-build.py"
fi
mkdir -p "$AR_SDK"

function get_actual_path(){
	p="$PWD"; cd "$1"; r="$PWD"; cd "$p"; echo "$r";
}

#
# START OF DATA EXTRACTION FROM CMAKE
#

C_FLAGS=""
CPP_FLAGS=""
AS_FLAGS=""

INCLUDES=""
DEFINES=""

LD_FLAGS=""
LD_LIBS=""
LD_LIB_FILES=""
LD_LIBS_SEARCH=""
LD_SCRIPTS=""
LD_SCRIPT_DIRS=""

TOOLCHAIN_PREFIX=""
if [ "$IS_XTENSA" = "y" ]; then
	TOOLCHAIN="xtensa-$IDF_TARGET-elf"
else
	TOOLCHAIN="riscv32-esp-elf"
fi

#collect includes, defines and c-flags
str=`cat build/compile_commands.json | grep arduino-lib-builder-gcc.c | grep command | cut -d':' -f2 | cut -d',' -f1`
str="${str:2:${#str}-1}" #remove leading space and quotes
str=`printf '%b' "$str"` #unescape the string
set -- $str
for item in "${@:2:${#@}-5}"; do
	prefix="${item:0:2}"
	if [ "$prefix" = "-I" ]; then
		item="${item:2}"
		if [ "${item:0:1}" = "/" ]; then
			item=`get_actual_path $item`
			INCLUDES+="$item "
		elif [ "${item:0:2}" = ".." ]; then
			if [[ "${item:0:14}" = "../components/" && "${item:0:22}" != "../components/arduino/" ]] || [[ "${item:0:11}" = "../esp-idf/" ]] || [[ "${item:0:22}" = "../managed_components/" ]]; then
				item="$PWD${item:2}"
				item=`get_actual_path $item`
				INCLUDES+="$item "
			fi
		else
			item="$PWD/build/$item"
			item=`get_actual_path $item`
			INCLUDES+="$item "
		fi
	elif [ "$prefix" = "-D" ]; then
		if [[ "${item:2:7}" != "ARDUINO" ]] && [[ "$item" != "-DESP32=ESP32" ]]; then #skip ARDUINO defines
			DEFINES+="$item "
		fi
	elif [[ "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			C_FLAGS+="$item "
		fi
	fi
done

#collect asm-flags
str=`cat build/compile_commands.json | grep arduino-lib-builder-as.S | grep command | cut -d':' -f2 | cut -d',' -f1`
str="${str:2:${#str}-1}" #remove leading space and quotes
str=`printf '%b' "$str"` #unescape the string
set -- $str
for item in "${@:2:${#@}-5}"; do
	prefix="${item:0:2}"
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			AS_FLAGS+="$item "
		fi
	fi
done

#collect cpp-flags
str=`cat build/compile_commands.json | grep arduino-lib-builder-cpp.cpp | grep command | cut -d':' -f2 | cut -d',' -f1`
str="${str:2:${#str}-1}" #remove leading space and quotes
str=`printf '%b' "$str"` #unescape the string
set -- $str
for item in "${@:2:${#@}-5}"; do
	prefix="${item:0:2}"
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			CPP_FLAGS+="$item "
		fi
	fi
done

#parse link command to extract libs and flags
add_next=0
is_dir=0
is_script=0
if [ -f "build/CMakeFiles/arduino-lib-builder.elf.dir/link.txt" ]; then
	str=`cat build/CMakeFiles/arduino-lib-builder.elf.dir/link.txt`
else
	libs=`cat build/build.ninja | grep LINK_LIBRARIES`
	libs="${libs:19:${#libs}-1}"
	flags=`cat build/build.ninja | grep LINK_FLAGS`
	flags="${flags:15:${#flags}-1}"
	paths=`cat build/build.ninja | grep LINK_PATH`
	paths="${paths:14:${#paths}-1}"
	if [ "$IDF_TARGET" = "esp32" ]; then
		flags="-Wno-frame-address $flags"
	fi
	if [ "$IS_XTENSA" = "y" ]; then
		flags="-mlongcalls $flags"
	fi
	str="$flags $libs $paths"
fi
if [ "$IDF_TARGET" = "esp32" ]; then
	LD_SCRIPTS+="-T esp32.rom.redefined.ld "
fi
set -- $str
for item; do
	prefix="${item:0:1}"
	if [ "$prefix" = "-" ]; then
		if [ "${item:0:10}" != "-Wl,--Map=" ]; then
			if [ "$item" = "-L" ]; then # -L /path
				add_next=1
				is_dir=1
			elif [ "${item:0:2}" = "-L" ]; then # -L/path
				LD_SCRIPT_DIRS+="${item:2} "
			elif [ "$item" = "-T" ]; then # -T script.ld
				add_next=1
				is_script=1
				LD_SCRIPTS+="$item "
			elif [ "$item" = "-u" ]; then # -u function_name
				add_next=1
				LD_FLAGS+="$item "
			elif [ "${item:0:2}" = "-l" ]; then # -l[lib_name]
				LD_LIBS+="$item "
				exclude_libs=";m;c;gcc;stdc++;"
				short_name="${item:2}"
				if [[ $exclude_libs != *";$short_name;"* && $LD_LIBS_SEARCH != *"lib$short_name.a"* ]]; then
					LD_LIBS_SEARCH+="lib$short_name.a "
					#echo "lib add: $item"
				fi
			elif [ "$item" = "-o" ]; then
				add_next=0
				is_script=0
				is_dir=0
			elif [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:19}" != "-fdebug-prefix-map=" && "${item:0:17}" != "-Wl,--start-group" && "${item:0:15}" != "-Wl,--end-group" ]]; then
				LD_FLAGS+="$item "
			fi
		fi
	else
		if [ "$add_next" = "1" ]; then
			add_next=0
			if [ "$is_dir" = "1" ]; then
				is_dir=0
				LD_SCRIPT_DIRS+="$item "
			elif [ "$is_script" = "1" ]; then
				is_script=0
				LD_SCRIPTS+="$item "
			else
				LD_FLAGS+="$item "
			fi
		else
			if [ "${item:${#item}-2:2}" = ".a" ]; then
				if [ "${item:0:1}" != "/" ]; then
					item="$PWD/build/$item"
				fi
				lname=$(basename $item)
				lname="${lname:3:${#lname}-5}"
				if [[ "$lname" != "main" && "$lname" != "arduino" ]]; then
					lsize=$($SSTAT "$item")
					if (( lsize > 8 )); then
						# do we already have this file?
						if [[ $LD_LIB_FILES != *"$item"* ]]; then
							# do we already have lib with the same name?
							if [[ $LD_LIBS != *"-l$lname"* ]]; then
								# echo "collecting lib '$lname' and file: $item"
								LD_LIB_FILES+="$item "
								LD_LIBS+="-l$lname "
							else 
								# echo "!!! need to rename: '$lname'"
								for i in {2..9}; do
									n_item="${item:0:${#item}-2}_$i.a"
									n_name=$lname"_$i"
									if [ -f "$n_item" ]; then
										# echo "renamed add: -l$n_name"
										LD_LIBS+="-l$n_name "
										break
									elif [[ $LD_LIB_FILES != *"$n_item"* && $LD_LIBS != *"-l$n_name"* ]]; then
										echo "Renaming '$lname' to '$n_name': $item"
										cp -f "$item" "$n_item"
										LD_LIB_FILES+="$n_item "
										LD_LIBS+="-l$n_name "
										break
									fi
								done
							fi
						else
							# echo "just add: -l$lname"
							LD_LIBS+="-l$lname "
						fi
					else
						echo "*** Skipping $(basename $item): size too small $lsize"
					fi
				fi
			elif [[ "${item:${#item}-4:4}" = ".obj" || "${item:${#item}-4:4}" = ".elf" || "${item:${#item}-4:4}" = "-g++" ]]; then
				item="$item"
			else
				echo "*** BAD LD ITEM: $item ${item:${#item}-2:2}"
			fi
		fi
	fi
done

#
# END OF DATA EXTRACTION FROM CMAKE
#

mkdir -p "$AR_SDK"

# replace double backslashes with single one
DEFINES=`echo "$DEFINES" | tr -s '\'`

# target flags files
FLAGS_DIR="$AR_SDK/flags"
mkdir -p "$FLAGS_DIR"
echo -n "$DEFINES" > "$FLAGS_DIR/defines"
echo -n "$REL_INC" > "$FLAGS_DIR/includes"
echo -n "$C_FLAGS" > "$FLAGS_DIR/c_flags"
echo -n "$CPP_FLAGS" > "$FLAGS_DIR/cpp_flags"
echo -n "$AS_FLAGS" > "$FLAGS_DIR/S_flags"
echo -n "$LD_FLAGS" > "$FLAGS_DIR/ld_flags"
echo -n "$LD_SCRIPTS" > "$FLAGS_DIR/ld_scripts"
echo -n "$AR_LIBS" > "$FLAGS_DIR/ld_libs"

# Matter Library adjustments
for flag_file in "c_flags" "cpp_flags" "S_flags"; do
	echo "Fixing $FLAGS_DIR/$flag_file"
 	sed 's/\\\"-DCHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER=<lib\/address_resolve\/AddressResolve_DefaultImpl.h>\\\"/-DCHIP_HAVE_CONFIG_H/' $FLAGS_DIR/$flag_file > $FLAGS_DIR/$flag_file.temp
	mv $FLAGS_DIR/$flag_file.temp $FLAGS_DIR/$flag_file
done
CHIP_RESOLVE_DIR="$AR_SDK/include/espressif__esp_matter/connectedhomeip/connectedhomeip/src/lib/address_resolve"
sed 's/CHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER/<lib\/address_resolve\/AddressResolve_DefaultImpl.h>/' $CHIP_RESOLVE_DIR/AddressResolve.h > $CHIP_RESOLVE_DIR/AddressResolve_temp.h
mv $CHIP_RESOLVE_DIR/AddressResolve_temp.h $CHIP_RESOLVE_DIR/AddressResolve.h
# End of Matter Library adjustments

# copy zigbee + zboss lib
if [ -d "managed_components/espressif__esp-zigbee-lib/lib/$IDF_TARGET/" ]; then
	cp -r "managed_components/espressif__esp-zigbee-lib/lib/$IDF_TARGET"/* "$AR_SDK/lib/"
fi

if [ -d "managed_components/espressif__esp-zboss-lib/lib/$IDF_TARGET/" ]; then
	cp -r "managed_components/espressif__esp-zboss-lib/lib/$IDF_TARGET"/* "$AR_SDK/lib/"
fi

# sdkconfig
cp -f "sdkconfig" "$AR_SDK/sdkconfig"

# dependencies.lock
cp -f "dependencies.lock" "$AR_SDK/dependencies.lock"

# gen_esp32part.py
# cp "$IDF_PATH/components/partition_table/gen_esp32part.py" "$AR_GEN_PART_PY"

# copy precompiled libs (if we need them)
function copy_precompiled_lib(){
	lib_file="$1"
	lib_name="$(basename $lib_file)"
	if [[ $LD_LIBS_SEARCH == *"$lib_name"* ]]; then
		cp "$lib_file" "$AR_SDK/ld/"
	fi
}

# idf ld scripts
mkdir -p "$AR_SDK/ld"
set -- $LD_SCRIPT_DIRS
for item; do
	item="${item%\"}"
	item="${item#\"}"
	find "$item" -name '*.ld' -exec cp -f {} "$AR_SDK/ld/" \;
	for lib in `find "$item" -name '*.a'`; do
		copy_precompiled_lib "$lib"
	done
done

for lib in "openthread" "espressif__esp-tflite-micro" "bt" "espressif__esp_matter"; do
	if [ -f "$AR_SDK/lib/lib$lib.a" ]; then
		echo "Stripping $AR_SDK/lib/lib$lib.a"
		"$TOOLCHAIN-strip" -g "$AR_SDK/lib/lib$lib.a"
	fi
done

# Handle Mem Variants
mkdir -p "$AR_SDK/$MEMCONF/include"
mv "$PWD/build/config/sdkconfig.h" "$AR_SDK/$MEMCONF/include/sdkconfig.h"
for mem_variant in `jq -c '.mem_variants_files[]' configs/builds.json`; do
	skip_file=1
	for file_target in $(echo "$mem_variant" | jq -c '.targets[]' | tr -d '"'); do
		if [ "$file_target" == "$IDF_TARGET" ]; then
			skip_file=0
			break
		fi
	done
	if [ $skip_file -eq 0 ]; then
		file=$(echo "$mem_variant" | jq -c '.file' | tr -d '"')
		out=$(echo "$mem_variant" | jq -c '.out' | tr -d '"')
		mv "$AR_SDK/$out" "$AR_SDK/$MEMCONF/$file"
	fi
done;

# Add IDF versions to sdkconfig
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> "$AR_SDK/$MEMCONF/include/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> "$AR_SDK/$MEMCONF/include/sdkconfig.h"
