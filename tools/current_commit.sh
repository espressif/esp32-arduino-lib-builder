IDF_COMMIT=$(wget -q -O- "https://github.com/espressif/arduino-esp32/search?q=update+idf&type=Commits" | grep -i "update idf" | grep -e "to [0-9a-f]*" | sed "s/^.*to \([0-9a-f]*\).*/\1/" | head -1)
echo Current commit is $IDF_COMMIT
