#!/bin/bash

#  uninstall.sh
#  MorseCodeInputMethod
# Uninstall script for Morse Code input method
#
#  Created by Pete Vieira on 9/5/24.
#

# Define the paths
INPUT_METHODS_PATH="~/Library/Input\ Methods"
APP_PATH="$INPUT_METHODS_PATH/Morse Code.app"
SWIFTMODULE_PATH="$INPUT_METHODS_PATH/Morse_Code.swiftmodule"

# Check if Morse Code.app exists and remove it
if [ -d "$APP_PATH" ]; then
    echo "Removing Morse Code.app..."
    rm -rf "$APP_PATH"
else
    echo "Morse Code.app not found."
fi

# Check if Morse_Code.swiftmodule exists and remove it
if [ -d "$SWIFTMODULE_PATH" ]; then
    echo "Removing Morse_Code.swiftmodule..."
    rm -rf "$SWIFTMODULE_PATH"
else
    echo "Morse_Code.swiftmodule not found."
fi

echo "Uninstallation complete."

exit 0
