#!/bin/bash

#  uninstall.sh
#  MorseCodeInputMethod
# Uninstall script for Morse Code input method
#
#  Created by Pete Vieira on 9/5/24.
#

# Define the paths
INPUT_METHODS_PATH="~/Library/Input\ Methods"
APP_PATH="$INPUT_METHODS_PATH/MorseCodeInputMethod.app"
SWIFTMODULE_PATH="$INPUT_METHODS_PATH/MorseCodeInputMethod.swiftmodule"

# Check if .app exists and remove it
if [ -d "$APP_PATH" ]; then
    echo "Removing MorseCodeInputMethod.app..."
    rm -rf "$APP_PATH"
else
    echo "MorseCodeInputMethod.app not found."
fi

# Check if swiftmodule exists and remove it
if [ -d "$SWIFTMODULE_PATH" ]; then
    echo "Removing MorseCodeInputMethod.swiftmodule..."
    rm -rf "$SWIFTMODULE_PATH"
else
    echo "MorseCodeInputMethod.swiftmodule not found."
fi

echo "Uninstallation complete."

exit 0
