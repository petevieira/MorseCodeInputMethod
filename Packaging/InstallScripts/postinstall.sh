#!/bin/bash

# Get the current logged-in user
USER=$(stat -f "%Su" /dev/console)

# Change ownership of installed files to the logged-in user
chown -R "$USER:staff" "$HOME/Library/Input Methods/MorseCodeInputMethod.app"
chown -R "$USER:staff" "$HOME/Library/Input Methods/MorseCodeInputMethod.swiftmodule"

exit 0
