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
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			AS_FLAGS+="$item "
			if [[ $C_FLAGS == *"$item"* ]]; then
				PIOARDUINO_CC_FLAGS+="$item "
			else
				PIOARDUINO_AS_FLAGS+="$item "
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
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" && "$prefix" != "-O" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" && "${item:0:20}" != "-fdiagnostics-color=" && "${item:0:19}" != "-fdebug-prefix-map=" ]]; then
			CPP_FLAGS+="$item "
			if [[ $PIOARDUINO_CC_FLAGS != *"$item"* ]]; then
				PIOARDUINO_CXX_FLAGS+="$item "
			fi
		fi
	fi
done

set -- $C_FLAGS
for item; do
	if [[ $PIOARDUINO_CC_FLAGS != *"$item"* ]]; then
		PIOARDUINO_C_FLAGS+="$item "
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
				PIOARDUINO_LD_FLAGS+="$item "
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
PIOARDUINO_AS_FLAGS=$(
    {
        echo "$PIOARDUINO_CXX_FLAGS" | grep -oE '\-march=[^[:space:]]*|\-mabi=[^[:space:]]*|\-mlongcalls'
        echo "$PIOARDUINO_CC_FLAGS" | grep -oE '\-march=[^[:space:]]*|\-mabi=[^[:space:]]*|\-mlongcalls'
    } | awk '!seen[$0]++' | paste -sd ' '
)

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

# include dirs
REL_INC=""
echo "    CPPPATH=[" >> "$AR_PIOARDUINO_PY"

set -- $INCLUDES

for item; do
	if [[ "$item" != $PWD ]]; then
		ipath="$item"
		fname=`basename "$ipath"`
		dname=`basename $(dirname "$ipath")`
		if [[ "$fname" == "main" && "$dname" == $(basename "$PWD") ]]; then
			continue
		fi
		while [[ "$dname" != "components" && "$dname" != "managed_components" && "$dname" != "build" ]]; do
			ipath=`dirname "$ipath"`
			fname=`basename "$ipath"`
			dname=`basename $(dirname "$ipath")`
		done
		if [[ "$fname" == "arduino" ]]; then
			continue
		fi
		if [[ "$fname" == "config" ]]; then
			continue
		fi

		out_sub="${item#*$ipath}"
		out_cpath="$AR_SDK/include/$fname$out_sub"
		REL_INC+="-iwithprefixbefore $fname$out_sub "
		if [ "$out_sub" = "" ]; then
			echo "        join($PIOARDUINO_SDK, \"include\", \"$fname\")," >> "$AR_PIOARDUINO_PY"
		else
			pioarduino_sub="${out_sub:1}"
			pioarduino_sub=`echo $pioarduino_sub | sed 's/\//\\", \\"/g'`
			echo "        join($PIOARDUINO_SDK, \"include\", \"$fname\", \"$pioarduino_sub\")," >> "$AR_PIOARDUINO_PY"
		fi
		for f in `find "$item" -name '*.h'`; do
			rel_f=${f#*$item}
			rel_p=${rel_f%/*}
			mkdir -p "$out_cpath$rel_p"
			cp -n $f "$out_cpath$rel_p/"
		done
		for f in `find "$item" -name '*.hpp'`; do
			rel_f=${f#*$item}
			rel_p=${rel_f%/*}
			mkdir -p "$out_cpath$rel_p"
			cp -n $f "$out_cpath$rel_p/"
		done
		for f in `find "$item" -name '*.inc'`; do
			rel_f=${f#*$item}
			rel_p=${rel_f%/*}
			mkdir -p "$out_cpath$rel_p"
			cp -n $f "$out_cpath$rel_p/"
		done

		# ---------------------------------------------------------------
		# Auto-resolve relative #include paths
		# ---------------------------------------------------------------
		# Some copied headers use relative paths with "../" to reference
		# files that live elsewhere in the component source tree and were
		# not part of any include directory (so they were never copied).
		#
		# Example from the bt component:
		#   esp_bt.h contains:
		#     #include "../../../../controller/esp32/esp_bredr_cfg.h"
		#
		# This block scans the just-copied headers, extracts every
		# #include ".../.../path" directive, resolves where the compiler
		# would expect the file in the output SDK, locates the actual
		# source file in the IDF tree, and copies it over.
		#
		# It loops to handle transitive dependencies (a newly copied
		# header may itself contain relative includes). Circular deps
		# are safe: already-existing files are skipped, so the loop
		# naturally terminates.
		#
		# Key variables coming from the outer loop:
		#   $item     - the IDF include directory currently being processed
		#   $out_cpath - corresponding output directory in the SDK
		#   $ipath    - root of the IDF component (e.g. esp-idf/components/bt)
		#   $fname    - component name (e.g. "bt")
		# ---------------------------------------------------------------

		# Canonicalize the SDK path so string comparisons work even when
		# the OS has symlinks (e.g. macOS: /var -> /private/var).
		_canonical_sdk=$($REALPATH -m "$AR_SDK" 2>/dev/null)

		# Seed the scan lists with headers we just copied into $out_cpath.
		# _scan_out  - output file paths (in the SDK) to scan
		# _scan_srcdir - matching source directories (in the IDF tree)
		_scan_out=()
		_scan_srcdir=()
		while IFS= read -r -d '' _f; do
			_fdir=$(dirname "$_f")
			_scan_out+=("$_f")
			# Map the output dir back to the source dir:
			# strip the $out_cpath prefix, then prepend $item.
			_scan_srcdir+=("$item${_fdir#$out_cpath}")
		done < <(find "$out_cpath" \( -name '*.h' -o -name '*.hpp' -o -name '*.inc' \) -print0 2>/dev/null)

		while [ ${#_scan_out[@]} -gt 0 ]; do
			_next_out=()
			_next_srcdir=()

			for _idx in "${!_scan_out[@]}"; do
				_f="${_scan_out[$_idx]}"
				_srcdir="${_scan_srcdir[$_idx]}"
				_outdir=$(dirname "$_f")

				# Extract relative include paths (containing "../") from
				# the header. The grep matches #include "path", the sed
				# strips the #include " prefix and trailing ".
				while IFS= read -r _rel_include; do

					# Resolve where the compiler would look for this file
					# relative to the header's location in the output SDK.
					_resolved_out=$($REALPATH -m "$_outdir/$_rel_include" 2>/dev/null)

					# Skip if: resolution failed, target is outside the
					# SDK (safety), or the file already exists (handles
					# duplicates and circular dependencies).
					if [ -z "$_resolved_out" ] || [[ "$_resolved_out" != "$_canonical_sdk/"* ]] || [ -f "$_resolved_out" ]; then
						continue
					fi

					# Locate the actual source file in the IDF tree.
					# Method 1: resolve the same relative path from the
					# header's original source directory. This works well
					# for transitive deps whose source location is known.
					_resolved_src=$($REALPATH -m "$_srcdir/$_rel_include" 2>/dev/null)

					# Method 2 (fallback): when the "../" chain escapes
					# above the include subdir, method 1 resolves to a
					# path that doesn't exist. In that case, strip the
					# leading "../" segments to get the tail (e.g.
					# "controller/esp32/file.h") and look for it under
					# the component root ($ipath).
					if [ -z "$_resolved_src" ] || [ ! -f "$_resolved_src" ]; then
						_tail=$(echo "$_rel_include" | sed 's|^\(\.\./\)*||')
						_resolved_src="$ipath/$_tail"
					fi

					if [ -f "$_resolved_src" ]; then
						# Only copy header/include files, skip source
						# files (.c, .cpp, .S, etc.) that happen to be
						# referenced via relative includes.
						case "$_resolved_src" in
							*.h|*.hpp|*.inc) ;;
							*) continue ;;
						esac
						mkdir -p "$(dirname "$_resolved_out")"
						cp -n "$_resolved_src" "$_resolved_out"
						echo "Auto-copied missing relative include: $_rel_include (from $(basename "$_f"))"
						# Queue the newly copied file for scanning in the
						# next iteration (transitive dependency resolution).
						_next_out+=("$_resolved_out")
						_next_srcdir+=("$(dirname "$_resolved_src")")
					fi

				done < <(grep -o '#include *"[^"]*\.\./[^"]*"' "$_f" 2>/dev/null | sed 's/#include *"//;s/"$//')
			done

			# If nothing new was copied this iteration, all transitive
			# dependencies have been resolved -- we're done.
			if [ ${#_next_out[@]} -eq 0 ]; then
				break
			fi
			_scan_out=("${_next_out[@]}")
			_scan_srcdir=("${_next_srcdir[@]}")
		done
	fi
done
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
# this is not necessary for Matter 1.4, but it is for Matter 1.3
#CHIP_RESOLVE_DIR="$AR_SDK/include/espressif__esp_matter/connectedhomeip/connectedhomeip/src/lib/address_resolve"
#sed 's/CHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER/<lib\/address_resolve\/AddressResolve_DefaultImpl.h>/' $CHIP_RESOLVE_DIR/AddressResolve.h > $CHIP_RESOLVE_DIR/AddressResolve_temp.h
#mv $CHIP_RESOLVE_DIR/AddressResolve_temp.h $CHIP_RESOLVE_DIR/AddressResolve.h
# End of Matter Library adjustments

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
