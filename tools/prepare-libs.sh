#!/bin/bash
# config
source ./tools/config.sh

# clean previous
if [ -e "$AR_TOOLS" ]; then
	rm -rf "$AR_TOOLS"
fi
mkdir -p "$AR_SDK"

# start generation of platformio-build.py
$AWK "/CPPPATH\=\[/{n++}{print>n\"pio_start.txt\"}" $AR_COMPS/arduino/tools/platformio-build.py
$AWK "/LIBSOURCE_DIRS\=\[/{n++}{print>n\"pio_end.txt\"}" 1pio_start.txt
cat 2pio_start.txt >> 1pio_end.txt
cat pio_start.txt > "$AR_PLATFORMIO_PY"
rm pio_end.txt 1pio_start.txt 2pio_start.txt pio_start.txt

# include dirs
AR_INC="-DESP_PLATFORM -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DHAVE_CONFIG_H -DGCC_NOT_5_2_0=0 -DWITH_POSIX \"-I{compiler.sdk.path}/include/config\""
echo "    CPPPATH=[" >> "$AR_PLATFORMIO_PY" && echo "       join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"include\", \"config\")," >> "$AR_PLATFORMIO_PY"
while [ "$1" != "" ]; do
	cpath=$1
	cname=$(echo $cpath| cut -d'/' -f 1)
	if [ "$cname" != "nimble" ]; then
		if [ -d "$AR_COMPS/$cpath" ]; then
			full_cpath="$AR_COMPS/$cpath"
		else
			full_cpath="$IDF_COMPS/$cpath"
		fi
		out_cpath="$AR_SDK/include/$cname"
		if [ ! -d $out_cpath ]; then
			#first encounter of this component
			AR_INC+=" \"-I{compiler.sdk.path}/include/$cname\""
			echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"include\", \"$cname\")," >> "$AR_PLATFORMIO_PY"
		fi
		for f in `find $full_cpath -name '*.h'`; do
			rel_f=${f#*$cpath/}
			full_f=/$rel_f
			rel_p=${full_f%/*}
			mkdir -p "$out_cpath$rel_p"
			cp -f $f "$out_cpath$rel_p/"
		done
		for f in `find $full_cpath -name '*.hpp'`; do
			rel_f=${f#*$cpath/}
			full_f=/$rel_f
			rel_p=${full_f%/*}
			mkdir -p "$out_cpath$rel_p"
			cp -f $f "$out_cpath$rel_p/"
		done
	fi
	shift
done
echo "        join(FRAMEWORK_DIR, \"cores\", env.BoardConfig().get(\"build.core\"))" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

minlsize=8

# idf libs
mkdir -p $AR_SDK/lib && \
for lib in `find $IDF_COMPS -name '*.a' | grep -v libg | grep -v libc_rom | grep -v workaround | grep -v libc-minusrom`; do
    lsize=$($SSTAT "$lib")
    if (( lsize > minlsize )); then
        cp -f $lib $AR_SDK/lib/
    else
        echo "skipping $lib: size too small $lsize"
    fi
done

# component libs
for lib in `find components -name '*.a' | grep -v arduino`; do
    lsize=$($SSTAT "$lib")
    if (( lsize > minlsize )); then
        cp -f $lib $AR_SDK/lib/
    else
        echo "skipping $lib: size too small $lsize"
    fi
done

# compiled libs
for lib in `find build -name '*.a' | grep -v bootloader | grep -v libmain | grep -v idf_test | grep -v aws_iot | grep -v libmicro | grep -v libarduino`; do
    lsize=$($SSTAT "$lib")
    if (( lsize > minlsize )); then
        cp -f $lib $AR_SDK/lib/
    else
        echo "skipping $lib: size too small $lsize"
    fi
done
cp build/bootloader_support/libbootloader_support.a $AR_SDK/lib/
cp build/micro-ecc/libmicro-ecc.a $AR_SDK/lib/

# remove liblib.a from esp-face (empty and causing issues on Windows)
rm -rf $AR_SDK/lib/liblib.a

# generate Arduino and PIO configs
AR_LIBS=""
PIO_LIBS="\"-lgcc\""
cd "$AR_SDK/lib/"
for lib in `find . -name '*.a'`; do
    AR_LIBS+="-l"$(basename ${lib:5} .a)" "
    PIO_LIBS+=", \"-l"$(basename ${lib:5} .a)"\""
done
PIO_LIBS+=", \"-lstdc++\""

# copy libs for psram workaround
for lib in `find $IDF_COMPS/newlib/lib -name '*-psram-workaround.a'`; do
    lsize=$($SSTAT "$lib")
    if (( lsize > minlsize )); then
        cp -f $lib $AR_SDK/lib/
    else
        echo "skipping $lib: size too small $lsize"
    fi
done

cd "$AR_ROOT"

echo "    LIBPATH=[" >> "$AR_PLATFORMIO_PY"
echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"lib\")," >> "$AR_PLATFORMIO_PY"
echo "        join(FRAMEWORK_DIR, \"tools\", \"sdk\", \"ld\")" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

echo "    LIBS=[" >> "$AR_PLATFORMIO_PY"
echo "        $PIO_LIBS" >> "$AR_PLATFORMIO_PY"
echo "    ]," >> "$AR_PLATFORMIO_PY"
echo "" >> "$AR_PLATFORMIO_PY"

# end generation of platformio-build.py
cat 1pio_end.txt >> "$AR_PLATFORMIO_PY"
rm 1pio_end.txt

# arduino platform.txt
$AWK "/compiler.cpreprocessor.flags\=/{n++}{print>n\"platform_start.txt\"}" $AR_COMPS/arduino/platform.txt
$SED -i '/compiler.cpreprocessor.flags\=/d' 1platform_start.txt
$AWK "/compiler.c.elf.libs\=/{n++}{print>n\"platform_mid.txt\"}" 1platform_start.txt
$SED -i '/compiler.c.elf.libs\=/d' 1platform_mid.txt
rm 1platform_start.txt
cat platform_start.txt > "$AR_PLATFORM_TXT"
echo "compiler.cpreprocessor.flags=$AR_INC" >> "$AR_PLATFORM_TXT"
cat platform_mid.txt >> "$AR_PLATFORM_TXT"
echo "compiler.c.elf.libs=-lgcc $AR_LIBS -lstdc++" >> "$AR_PLATFORM_TXT"
cat 1platform_mid.txt >> "$AR_PLATFORM_TXT"
rm platform_start.txt platform_mid.txt 1platform_mid.txt

# sdkconfig
mkdir -p $AR_SDK/include/config && cp -f build/include/sdkconfig.h $AR_SDK/include/config/sdkconfig.h
cp -f sdkconfig $AR_SDK/sdkconfig

# esptool.py
cp $IDF_COMPS/esptool_py/esptool/esptool.py $AR_ESPTOOL_PY

# gen_esp32part.py
cp $IDF_COMPS/partition_table/gen_esp32part.py $AR_GEN_PART_PY

# idf ld scripts
mkdir -p $AR_SDK/ld && find $IDF_COMPS/esp32/ld -name '*.ld' -exec cp -f {} $AR_SDK/ld/ \;

# ld script
cp -f build/esp32/*.ld $AR_SDK/ld/

# Add IDF versions to sdkconfig
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> $AR_SDK/include/config/sdkconfig.h
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> $AR_SDK/include/config/sdkconfig.h
