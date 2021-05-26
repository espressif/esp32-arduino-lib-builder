#!/bin/bash
# config

IDF_TARGET=$1

source ./tools/config.sh

echo "IDF_TARGET: $IDF_TARGET, PWD: $PWD, OUT: $AR_SDK"

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

PIO_CC_FLAGS=""
PIO_C_FLAGS=""
PIO_CXX_FLAGS=""
PIO_AS_FLAGS=""
PIO_LD_FLAGS=""
PIO_LD_FUNCS=""
PIO_LD_SCRIPTS=""

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
			if [[ "${item:0:14}" = "../components/" && "${item:0:22}" != "../components/arduino/" ]] || [[ "${item:0:11}" = "../esp-idf/" ]]; then
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
		if [[ "${item:2:7}" != "ARDUINO" ]] && [[ "$item" != "-DESP32" ]]; then #skip ARDUINO defines
			DEFINES+="$item "
		fi
	elif [[ "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" ]]; then
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
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" ]]; then
			AS_FLAGS+="$item "
			if [[ $C_FLAGS == *"$item"* ]]; then
				PIO_CC_FLAGS+="$item "
			else
				PIO_AS_FLAGS+="$item "
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
	if [[ "$prefix" != "-I" && "$prefix" != "-D" && "$item" != "-Wall" && "$item" != "-Werror=all"  && "$item" != "-Wextra" ]]; then
		if [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" ]]; then
			CPP_FLAGS+="$item "
			if [[ $PIO_CC_FLAGS != *"$item"* ]]; then
				PIO_CXX_FLAGS+="$item "
			fi
		fi
	fi
done

set -- $C_FLAGS
for item; do
	if [[ $PIO_CC_FLAGS != *"$item"* ]]; then
		PIO_C_FLAGS+="$item "
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
	if [ "$IDF_TARGET" = "esp32" ]; then
		flags="-Wno-frame-address $flags"
	fi
	if [ "$IDF_TARGET" != "esp32c3" ]; then
		flags="-mlongcalls $flags"
	fi
	str="$flags $libs"
fi
if [ "$IDF_TARGET" = "esp32" ]; then
	LD_SCRIPTS+="-T esp32.rom.redefined.ld "
	PIO_LD_SCRIPTS+="esp32.rom.redefined.ld "
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
				fi
			elif [ "$item" = "-o" ]; then
				add_next=0
				is_script=0
				is_dir=0
			elif [[ "${item:0:23}" != "-mfix-esp32-psram-cache" && "${item:0:18}" != "-fmacro-prefix-map" ]]; then
				LD_FLAGS+="$item "
				PIO_LD_FLAGS+="$item "
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
				PIO_LD_SCRIPTS+="$item "
			else
				LD_FLAGS+="$item "
				PIO_LD_FUNCS+="$item "
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
						LD_LIBS+="-l$lname "
						LD_LIB_FILES+="$item "
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

AR_PLATFORMIO_PY="$AR_TOOLS/platformio-build-$IDF_TARGET.py"

# start generation of platformio-build.py
awk "/ASFLAGS=\[/{n++}{print>n\"pio_start.txt\"}" $AR_COMPS/arduino/tools/platformio-build-$IDF_TARGET.py
awk "/\"ARDUINO_ARCH_ESP32\"/{n++}{print>n\"pio_end.txt\"}" 1pio_start.txt
cat pio_start.txt > "$AR_PLATFORMIO_PY"
rm pio_end.txt 1pio_start.txt pio_start.txt

echo "    ASFLAGS=[" >> "$AR_PLATFORMIO_PY"
set -- $PIO_AS_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
done
echo "        \"-x\", \"assembler-with-cpp\"" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    CFLAGS=[" >> "$AR_PLATFORMIO_PY"
set -- $PIO_C_FLAGS
last_item="${@: -1}"
for item in "${@:0:${#@}}"; do
	if [ "${item:0:1}" != "/" ]; then
		echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
	fi
done
echo "        \"$last_item\"" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    CXXFLAGS=[" >> "$AR_PLATFORMIO_PY"
set -- $PIO_CXX_FLAGS
last_item="${@: -1}"
for item in "${@:0:${#@}}"; do
	if [ "${item:0:1}" != "/" ]; then
		echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
	fi
done
echo "        \"$last_item\"" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    CCFLAGS=[" >> "$AR_PLATFORMIO_PY"
set -- $PIO_CC_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
done
echo "        \"-MMD\"" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    LINKFLAGS=[" >> "$AR_PLATFORMIO_PY"
set -- $PIO_LD_FLAGS
for item; do
	echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
done
set -- $PIO_LD_SCRIPTS
for item; do
	echo "        \"-T\", \"$item\"," >> "$AR_PLATFORMIO_PY"
done
set -- $PIO_LD_FUNCS
for item; do
	echo "        \"-u\", \"$item\"," >> "$AR_PLATFORMIO_PY"
done
echo "        '-Wl,-Map=\"%s\"' % join(\"\$BUILD_DIR\", basename(env.subst(\"\${PROJECT_DIR}.map\")))" >> "$AR_PLATFORMIO_PY"

echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

# # include dirs
AR_INC=""
echo "    CPPPATH=[" >> "$AR_PLATFORMIO_PY"

set -- $INCLUDES

for item; do
	if [[ "$item" != $PWD ]]; then
		ipath="$item"
		fname=`basename "$ipath"`
		dname=`basename $(dirname "$ipath")`
		if [[ "$fname" == "main" && "$dname" == "esp32-arduino-lib-builder" ]]; then
			continue
		fi
		while [[ "$dname" != "components" && "$dname" != "build" ]]; do
			ipath=`dirname "$ipath"`
			fname=`basename "$ipath"`
			dname=`basename $(dirname "$ipath")`
		done
		if [[ "$fname" == "arduino" ]]; then
			continue
		fi

		out_sub="${item#*$ipath}"
		out_cpath="$AR_SDK/include/$fname$out_sub"
		AR_INC+=" \"-I{compiler.sdk.path}/include/$fname$out_sub\""
		if [ "$out_sub" = "" ]; then
			echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"$IDF_TARGET\", \"include\", \"$fname\")," >> "$AR_PLATFORMIO_PY"
		else
			pio_sub="${out_sub:1}"
			pio_sub=`echo $pio_sub | sed 's/\//\\", \\"/g'`
			echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"$IDF_TARGET\", \"include\", \"$fname\", \"$pio_sub\")," >> "$AR_PLATFORMIO_PY"
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
	fi
done
echo "        join(FRAMEWORK_DIR, \"cores\", env.BoardConfig().get(\"build.core\"))" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

mkdir -p "$AR_SDK/lib"

AR_LIBS="$LD_LIBS"
PIO_LIBS=""
set -- $LD_LIBS
for item; do
	if [ "$PIO_LIBS" != "" ]; then
		PIO_LIBS+=", "
	fi
	PIO_LIBS+="\"$item\""
done

set -- $LD_LIB_FILES
for item; do
	cp "$item" "$AR_SDK/lib/"
done

echo "    LIBPATH=[" >> "$AR_PLATFORMIO_PY"
echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"$IDF_TARGET\", \"lib\")," >> "$AR_PLATFORMIO_PY"
echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"$IDF_TARGET\", \"ld\")" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    LIBS=[" >> "$AR_PLATFORMIO_PY"
echo "        $PIO_LIBS" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    CPPDEFINES=[" >> "$AR_PLATFORMIO_PY"
set -- $DEFINES
for item; do
	item="${item:2}" #remove -D
	if [[ $item == *"="* ]]; then
		item=(${item//=/ })
		re='^[+-]?[0-9]+([.][0-9]+)?$'
		if [[ ${item[1]} =~ $re ]]; then
			echo "        (\"${item[0]}\", ${item[1]})," >> "$AR_PLATFORMIO_PY"
		else
			echo "        (\"${item[0]}\", '${item[1]}')," >> "$AR_PLATFORMIO_PY"
		fi
	else
		echo "        \"$item\"," >> "$AR_PLATFORMIO_PY"
	fi
done

# remove backslashes for Arduino
DEFINES=`echo "$DEFINES" | tr -d '\\'`


# end generation of platformio-build.py
cat 1pio_end.txt >> "$AR_PLATFORMIO_PY"
rm 1pio_end.txt

# arduino platform.txt
platform_file="$AR_COMPS/arduino/platform.txt"
if [ -f "$AR_PLATFORM_TXT" ]; then
	# use the file we have already compiled for other chips
	platform_file="$AR_PLATFORM_TXT"
fi
awk "/compiler.cpreprocessor.flags.$IDF_TARGET=/{n++}{print>n\"platform_start.txt\"}" "$platform_file"
$SED -i "/compiler.cpreprocessor.flags.$IDF_TARGET\=/d" 1platform_start.txt
awk "/compiler.ar.flags.$IDF_TARGET=/{n++}{print>n\"platform_mid.txt\"}" 1platform_start.txt
rm -rf 1platform_start.txt

cat platform_start.txt > "$AR_PLATFORM_TXT"
echo "compiler.cpreprocessor.flags.$IDF_TARGET=$DEFINES $AR_INC" >> "$AR_PLATFORM_TXT"
echo "compiler.c.elf.libs.$IDF_TARGET=$AR_LIBS" >> "$AR_PLATFORM_TXT"
echo "compiler.c.flags.$IDF_TARGET=$C_FLAGS -MMD -c" >> "$AR_PLATFORM_TXT"
echo "compiler.cpp.flags.$IDF_TARGET=$CPP_FLAGS -MMD -c" >> "$AR_PLATFORM_TXT"
echo "compiler.S.flags.$IDF_TARGET=$AS_FLAGS -x assembler-with-cpp -MMD -c" >> "$AR_PLATFORM_TXT"
echo "compiler.c.elf.flags.$IDF_TARGET=$LD_SCRIPTS $LD_FLAGS" >> "$AR_PLATFORM_TXT"
cat 1platform_mid.txt >> "$AR_PLATFORM_TXT"
rm -rf platform_start.txt platform_mid.txt 1platform_mid.txt

# sdkconfig
cp -f "sdkconfig" "$AR_SDK/sdkconfig"

# esptool.py
cp "$IDF_COMPS/esptool_py/esptool/esptool.py" "$AR_ESPTOOL_PY"

# gen_esp32part.py
cp "$IDF_COMPS/partition_table/gen_esp32part.py" "$AR_GEN_PART_PY"

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
	find "$item" -name '*.ld' -exec cp -f {} "$AR_SDK/ld/" \;
	for lib in `find "$item" -name '*.a'`; do
		copy_precompiled_lib "$lib"
	done
done

# Add IDF versions to sdkconfig
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> "$AR_SDK/include/config/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> "$AR_SDK/include/config/sdkconfig.h"
