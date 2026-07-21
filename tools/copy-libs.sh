#!/bin/bash
# config

IDF_TARGET=$1
CHIP_VARIANT=$2
IS_XTENSA=$5
OCT_FLASH="$3"
OCT_PSRAM=

if [ "$4" = "y" ]; then
	OCT_PSRAM="opi"
else
	OCT_PSRAM="qspi"
fi
MEMCONF=$OCT_FLASH"_$OCT_PSRAM"

source ./tools/config.sh

echo "IDF_TARGET: $IDF_TARGET, CHIP_VARIANT: $CHIP_VARIANT, MEMCONF: $MEMCONF, PWD: $PWD, OUT: $AR_SDK"

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
if [ -e "$AR_SDK/pioarduino-build.py" ]; then
	rm -rf "$AR_SDK/pioarduino-build.py"
fi

mkdir -p "$AR_SDK"
mkdir -p "$AR_SDK/lib"

function get_actual_path(){
	d="$1";
	if [ -d "$d" ]; then
		p="$PWD"; cd "$d"; r="$PWD"; cd "$p"; echo "$r";
	else
		echo "";
	fi
}

#
# START OF DATA EXTRACTION FROM CMAKE
#

C_FLAGS=""
CPP_FLAGS=""
AS_FLAGS=""

INCLUDES=""
DEFINES=""

EXCLUDE_LIBS=";"

LD_FLAGS=""
LD_LIBS=""
LD_LIB_FILES=""
LD_LIBS_SEARCH=""
LD_SCRIPTS=""
LD_SCRIPT_DIRS=""

PIOARDUINO_CC_FLAGS=""
PIOARDUINO_C_FLAGS=""
PIOARDUINO_CXX_FLAGS=""
PIOARDUINO_AS_FLAGS=""
PIOARDUINO_LD_FLAGS=""
PIOARDUINO_LD_FUNCS=""
PIOARDUINO_LD_SCRIPTS=""

TOOLCHAIN_PREFIX=""
if [ "$IS_XTENSA" = "y" ]; then
	TOOLCHAIN="xtensa-$IDF_TARGET-elf"
else
	TOOLCHAIN="riscv32-esp-elf"
fi

# copy zigbee + zboss lib
if [ -d "managed_components/espressif__esp-zigbee-lib/lib/$IDF_TARGET/" ]; then
	cp -r "managed_components/espressif__esp-zigbee-lib/lib/$IDF_TARGET"/* "$AR_SDK/lib/"
	EXCLUDE_LIBS+="esp_zb_api.ed;esp_zb_api.zczr;"
fi

if [ -d "managed_components/espressif__esp-zboss-lib/lib/$IDF_TARGET/" ]; then
	cp -r "managed_components/espressif__esp-zboss-lib/lib/$IDF_TARGET"/* "$AR_SDK/lib/"
	EXCLUDE_LIBS+="zboss_stack.ed;zboss_stack.zczr;zboss_port.native;zboss_port.native.debug;zboss_port.remote;zboss_port.remote.debug;"
fi

# Strip surrounding quotes and absolute path from -specs=/path/file.specs -> -specs=file.specs
# All other flags are passed through unchanged (quotes stripped).
function pio_flag() {
	local flag="${1%\"}"  # strip trailing "
	flag="${flag#\"}"     # strip leading "
	if [[ "${flag:0:7}" = "-specs=" ]]; then
		echo "-specs=$(basename "${flag:7}")"
	else
		echo "$flag"
	fi
}

#collect includes, defines and c-flags
str=`cat build/compile_commands.json | grep arduino-lib-builder-gcc.c | grep command | cut -d':' -f2 | cut -d',' -f1`
str="${str:2:${#str}-1}" #remove leading space and quotes
str=`printf '%b' "$str"` #unescape the string
set -- $str
for item in "${@:2:${#@}-5}"; do
	prefix="${item:0:2}"
	if [ "${item:0:1}" = "@" ]; then
		xfile="${item:3:${#item}-5}"
		if [ ! -f "$xfile" ]; then echo "File '$xfile' does not exist!"; exit 1; fi
		echo "Parse CC file '$xfile'"
		for xitem in `cat "$xfile"`; do
			C_FLAGS+="$xitem "
			LD_FLAGS+="$xitem "
			PIOARDUINO_LD_FLAGS+="$(pio_flag "$xitem") "
		done
	elif [ "$prefix" = "-I" ]; then
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
	elif [ "$prefix" = "-O" ]; then
		PIOARDUINO_CC_FLAGS+="$item "
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
	if [ "${item:0:1}" = "@" ]; then
		xfile="${item:3:${#item}-5}"
		if [ ! -f "$xfile" ]; then echo "File '$xfile' does not exist!"; exit 1; fi
		echo "Parse AS file '$xfile'"
		for xitem in `cat "$xfile"`; do
			AS_FLAGS+="$xitem "
			if [[ "$xitem" != *"-mtune"* && "$xitem" != *"-specs"* ]]; then
				PIOARDUINO_AS_FLAGS+="$xitem "
			fi
		done
	elif [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			AS_FLAGS+="$item "
			if [[ "$item" != *"-mtune"* && "$item" != *"-specs"* ]]; then
				if [[ $C_FLAGS == *"$item"* ]]; then
					PIOARDUINO_CC_FLAGS+="$item "
				else
					PIOARDUINO_AS_FLAGS+="$item "
				fi
			fi
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
	if [ "${item:0:1}" = "@" ]; then
		xfile="${item:3:${#item}-5}"
		if [ ! -f "$xfile" ]; then echo "File '$xfile' does not exist!"; exit 1; fi
		echo "Parse CXX file '$xfile'"
		for xitem in `cat "$xfile"`; do
			CPP_FLAGS+="$xitem "
			PIOARDUINO_CXX_FLAGS+="$(pio_flag "$xitem") "
		done
	elif [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			CPP_FLAGS+="$item "
			if [[ $PIOARDUINO_CC_FLAGS != *"$item"* ]]; then
				PIOARDUINO_CXX_FLAGS+="$(pio_flag "$item") "
			fi
		fi
	fi
done

set -- $C_FLAGS
for item; do
	if [[ $PIOARDUINO_CC_FLAGS != *"$item"* ]]; then
		PIOARDUINO_C_FLAGS+="$(pio_flag "$item") "
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
	PIOARDUINO_LD_SCRIPTS+="esp32.rom.redefined.ld "
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
				short_name="${item:2}"
				if [[ $EXCLUDE_LIBS != *";$short_name;"* ]]; then
					LD_LIBS+="$item "
					exclude_libs=";m;c;gcc;stdc++;"
					if [[ $exclude_libs != *";$short_name;"* && $LD_LIBS_SEARCH != *"lib$short_name.a"* ]]; then
						LD_LIBS_SEARCH+="lib$short_name.a "
						#echo "1. lib add: $item"
					fi
				fi
			elif [ "$item" = "-o" ]; then
				add_next=0
				is_script=0
				is_dir=0
			elif [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:19}" != "-fdebug-prefix-map=" && "${item:0:17}" != "-Wl,--start-group" && "${item:0:15}" != "-Wl,--end-group" ]]; then
				LD_FLAGS+="$item "
				PIOARDUINO_LD_FLAGS+="$(pio_flag "$item") "
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
				PIOARDUINO_LD_SCRIPTS+="$item "
			else
				LD_FLAGS+="$item "
				PIOARDUINO_LD_FUNCS+="$item "
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
								if [[ $EXCLUDE_LIBS != *";$lname;"* ]]; then
									#echo "2. collecting lib '$lname' and file: $item"
									LD_LIB_FILES+="$item "
									LD_LIBS+="-l$lname "
								fi
							else 
								# echo "!!! need to rename: '$lname'"
								for i in {2..9}; do
									n_item="${item:0:${#item}-2}_$i.a"
									n_name=$lname"_$i"
									if [ -f "$n_item" ]; then
										if [[ $EXCLUDE_LIBS != *";$lname;"* ]]; then
											#echo "3. renamed add: -l$n_name"
											LD_LIBS+="-l$n_name "
										fi
										break
									elif [[ $LD_LIB_FILES != *"$n_item"* && $LD_LIBS != *"-l$n_name"* ]]; then
										if [[ $EXCLUDE_LIBS != *";$lname;"* ]]; then
											#echo "4. Renaming '$lname' to '$n_name': $item"
											cp -f "$item" "$n_item"
											LD_LIB_FILES+="$n_item "
											LD_LIBS+="-l$n_name "
										fi
										break
									fi
								done
							fi
						else
							if [[ $EXCLUDE_LIBS != *";$lname;"* ]]; then
								#echo "5. just add: -l$lname"
								LD_LIBS+="-l$lname "
							fi
						fi
					else
						echo "*** Skipping $(basename $item): size too small $lsize"
					fi
				fi
			elif [[ "${item:${#item}-4:4}" = ".obj" || "${item:${#item}-4:4}" = ".elf" || "${item:${#item}-4:4}" = "-g++" ]]; then
				item="$item"
			elif [ "${item:0:1}" = "@" ]; then
				xfile="${item:2:${#item}-3}"
				if [ ! -f "$xfile" ]; then echo "File '$xfile' does not exist!"; exit 1; fi
				echo "Parse LD file '$xfile'"
				for xitem in `cat "$xfile"`; do
					LD_FLAGS+="$xitem "
					PIOARDUINO_LD_FLAGS+="$(pio_flag "$xitem") "
				done
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

# Keep only -march, -mabi and -mlongcalls flags for Assembler
# PIOARDUINO_AS_FLAGS=$(
#     {
#         echo "$PIOARDUINO_CXX_FLAGS" | grep -oE '\-march=[^[:space:]]*|\-mabi=[^[:space:]]*|\-mlongcalls'
#         echo "$PIOARDUINO_CC_FLAGS" | grep -oE '\-march=[^[:space:]]*|\-mabi=[^[:space:]]*|\-mlongcalls'
#     } | awk '!seen[$0]++' | paste -sd ' '
# )

# start generation of pioarduino-build.py
AR_PIOARDUINO_PY="$AR_SDK/pioarduino-build.py"
cat configs/pioarduino_start.txt > "$AR_PIOARDUINO_PY"

echo "    ASFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_AS_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
done
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    ASPPFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_AS_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
done
echo "        \"-x\", \"assembler-with-cpp\"" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    CFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_C_FLAGS
last_item="${@: -1}"
for item in "${@:0:${#@}}"; do
	if [ "${item:0:1}" != "/" ]; then
		echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
	fi
done
echo "        \"$last_item\"" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    CXXFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_CXX_FLAGS
last_item="${@: -1}"
for item in "${@:0:${#@}}"; do
	if [ "${item:0:1}" != "/" ]; then
		echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
	fi
done
echo "        \"$last_item\"" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    CCFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_CC_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
done
echo "        \"-MMD\"" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    LINKFLAGS=[" >> "$AR_PIOARDUINO_PY"
set -- $PIOARDUINO_LD_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
done
set -- $PIOARDUINO_LD_SCRIPTS
for item; do
	echo "        \"-T\", \"$item\"," >> "$AR_PIOARDUINO_PY"
done
set -- $PIOARDUINO_LD_FUNCS
for item; do
	echo "        \"-u\", \"$item\"," >> "$AR_PIOARDUINO_PY"
done
echo "        '-Wl,-Map=\"%s\"' % join(\"\${BUILD_DIR}\", \"\${PROGNAME}.map\")" >> "$AR_PIOARDUINO_PY"

echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

# include dirs. The mapping (IDF include dir -> SDK location), header copy, relative
# "../" include resolution, the flags/includes search path (-iwithprefixbefore) and the
# pioarduino CPPPATH entries are all produced by tools/sdk_includes.py, which is shared
# with tools/copy-bt-variant.sh so the Arduino and PlatformIO include paths never drift.
# It reads the aggregate public include path from build/compile_commands.json, writes
# flags/includes, copies the headers into $AR_SDK/include, and prints the CPPPATH lines
# (captured here into pioarduino-build.py). Progress/auto-resolve logs go to stderr.
echo "    CPPPATH=[" >> "$AR_PIOARDUINO_PY"
python3 "$AR_ROOT/tools/sdk_includes.py" base \
	--compile-commands "build/compile_commands.json" \
	--sdk-include "$AR_SDK/include" \
	--flags-includes "$AR_SDK/flags/includes" \
	--pio-prefix "$PIOARDUINO_SDK" >> "$AR_PIOARDUINO_PY"
echo "        join($PIOARDUINO_SDK, board_config.get(\"build.arduino.memory_type\", (board_config.get(\"build.flash_mode\", \"dio\") + \"_$OCT_PSRAM\")), \"include\")," >> "$AR_PIOARDUINO_PY"
echo "        join(FRAMEWORK_DIR, \"cores\", board_config.get(\"build.core\"))" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

AR_LIBS="$LD_LIBS"
PIOARDUINO_LIBS=""
set -- $LD_LIBS
for item; do
	if [ "$PIOARDUINO_LIBS" != "" ]; then
		PIOARDUINO_LIBS+=", "
	fi
	PIOARDUINO_LIBS+="\"$item\""
done

set -- $LD_LIB_FILES
for item; do
	cp "$item" "$AR_SDK/lib/"
done

echo "    LIBPATH=[" >> "$AR_PIOARDUINO_PY"
echo "        join($PIOARDUINO_SDK, \"lib\")," >> "$AR_PIOARDUINO_PY"
echo "        join($PIOARDUINO_SDK, \"ld\")," >> "$AR_PIOARDUINO_PY"
echo "        join($PIOARDUINO_SDK, board_config.get(\"build.arduino.memory_type\", (board_config.get(\"build.flash_mode\", \"dio\") + \"_$OCT_PSRAM\")))" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    LIBS=[" >> "$AR_PIOARDUINO_PY"
echo "        $PIOARDUINO_LIBS" >> "$AR_PIOARDUINO_PY"
echo "    ]," >> "$AR_PIOARDUINO_PY"
echo "" >> "$AR_PIOARDUINO_PY"

echo "    CPPDEFINES=[" >> "$AR_PIOARDUINO_PY"
set -- $DEFINES
for item; do
	item="${item:2}" #remove -D
	if [[ $item == *"="* ]]; then
		item=(${item//=/ })
		re='^[+-]?[0-9]+([.][0-9]+)?$'
		if [[ ${item[1]} =~ $re ]]; then
			echo "        (\"${item[0]}\", ${item[1]})," >> "$AR_PIOARDUINO_PY"
		else
			echo "        (\"${item[0]}\", '${item[1]}')," >> "$AR_PIOARDUINO_PY"
		fi
	else
		echo "        \"$item\"," >> "$AR_PIOARDUINO_PY"
	fi
done

# end generation of pioarduino-build.py
cat configs/pioarduino_end.txt >> "$AR_PIOARDUINO_PY"

# Matter Library adjustments
echo "Fixing $AR_PIOARDUINO_PY"
sed 's/\\\"-DCHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER=<lib\/address_resolve\/AddressResolve_DefaultImpl.h>\\\"/-DCHIP_HAVE_CONFIG_H/' $AR_PIOARDUINO_PY > $AR_PIOARDUINO_PY.temp
mv $AR_PIOARDUINO_PY.temp $AR_PIOARDUINO_PY

# replace double backslashes with single one
DEFINES=`echo "$DEFINES" | tr -s '\'`

# target flags files
FLAGS_DIR="$AR_SDK/flags"
mkdir -p "$FLAGS_DIR"
echo -n "$DEFINES" > "$FLAGS_DIR/defines"
# flags/includes is written by tools/sdk_includes.py (base mode) during CPPPATH generation.
echo -n "$C_FLAGS" > "$FLAGS_DIR/c_flags"
echo -n "$CPP_FLAGS" > "$FLAGS_DIR/cpp_flags"
echo -n "$AS_FLAGS" > "$FLAGS_DIR/S_flags"
echo -n "$LD_FLAGS" > "$FLAGS_DIR/ld_flags"
echo -n "$LD_SCRIPTS" > "$FLAGS_DIR/ld_scripts"
echo -n "$AR_LIBS" > "$FLAGS_DIR/ld_libs"

# --- Selectable BT stack support -------------------------------------------
# Empty default BT libs file. platform.txt links "@flags/{build.bt_libs_file}"
# with build.bt_libs_file defaulting to "ld_libs_bt". On targets/boards without
# the "BLE Stack" menu this is a harmless no-op; on flavored targets
# tools/copy-bt-variant.sh overwrites it with the default (NimBLE) BT lib list so
# that every board of that chip links a working BT stack even without touching
# the menu.
: > "$FLAGS_DIR/ld_libs_bt"
# The swappable BT library set itself is discovered later by tools/copy-bt-variant.sh
# straight from the flavor build's dependency graph, so the default pass needs no
# manifest. It does, however, record the reference content signatures of those archives
# for THIS default (NimBLE) build, so each memory-variant pass (copy-mem-variant.sh)
# can verify they stay flash-mode/PSRAM independent -- a swapped BT archive is shipped
# once and shared across all memory configs, which is only valid if it is memory
# agnostic. Discovery, signature and guard all live in config.sh. Only done for targets
# that actually build BT stack variants, to avoid the nm cost elsewhere.
BT_HAS_VARIANTS=$(jq -r --arg t "$CHIP_VARIANT" '[.targets[] | select(.target==$t or .chip_variant==$t) | (.bt_variants // [])] | add // [] | length' configs/builds.json 2>/dev/null)
if [ -n "$BT_HAS_VARIANTS" ] && [ "$BT_HAS_VARIANTS" != "0" ]; then
	BT_META_DIR="$AR_ROOT/.bt_meta/$CHIP_VARIANT"
	rm -rf "$BT_META_DIR"
	mkdir -p "$BT_META_DIR"
	bt_swappable_sigs > "$BT_META_DIR/sig_nimble"
fi
# --------------------------------------------------------------------------

# Matter Library adjustments
for flag_file in "c_flags" "cpp_flags" "S_flags"; do
	echo "Fixing $FLAGS_DIR/$flag_file"
 	sed 's/\\\"-DCHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER=<lib\/address_resolve\/AddressResolve_DefaultImpl.h>\\\"/-DCHIP_HAVE_CONFIG_H/' $FLAGS_DIR/$flag_file > $FLAGS_DIR/$flag_file.temp
	mv $FLAGS_DIR/$flag_file.temp $FLAGS_DIR/$flag_file
done
# this is not necessary for Matter 1.4, but it is for Matter 1.3
#CHIP_RESOLVE_DIR="$AR_SDK/include/espressif__esp_matter/connectedhomeip/connectedhomeip/src/lib/address_resolve"
#sed 's/CHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER/<lib\/address_resolve\/AddressResolve_DefaultImpl.h>/' $CHIP_RESOLVE_DIR/AddressResolve.h > $CHIP_RESOLVE_DIR/AddressResolve_temp.h
#mv $CHIP_RESOLVE_DIR/AddressResolve_temp.h $CHIP_RESOLVE_DIR/AddressResolve.h
# End of Matter Library adjustments

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
		if [ "$file_target" == "$CHIP_VARIANT" ]; then
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
