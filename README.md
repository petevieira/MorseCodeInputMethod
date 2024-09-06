# MorseCodeInputMethod
macOS keyboard input method for Morse code.

## Description
This input method provides the ability to use any non-modifier key to type Morse code as if the key were a telegraph or Morse key.

### Supported Morse Dictionary
| Morse Code | Letter | Morse Code | Number | Morse Code | Punctuation |
|------------|--------|------------|--------|------------|-------------|
| .-         | A      | -----      | 0      | .-.-.-     | .           |
| -...       | B      | .----      | 1      | --..--     | ,           |
| -.-.       | C      | ..---      | 2      | ..--..     | ?           |
| -..        | D      | ...--      | 3      | .----.     | '           |
| .          | E      | ....-      | 4      | -.-.--     | !           |
| ..-.       | F      | .....      | 5      | -..-.      | /           |
| --.        | G      | -....      | 6      | -.--.      | (           |
| ....       | H      | --...      | 7      | -.--.-     | )           |
| ..         | I      | ---..      | 8      | .-...      | &           |
| .---       | J      | ----.      | 9      | ---...     | :           |
| -.-        | K      |            |        | -.-.-.     | ;           |
| .-..       | L      |            |        | -...-      | =           |
| --         | M      |            |        | .-.-.      | +           |
| -.         | N      |            |        | -....-     | -           |
| ---        | O      |            |        | ..--.-     | _           |
| .--.       | P      |            |        | .-..-.     | "           |
| --.-       | Q      |            |        | ...-..-    | $           |
| .-.        | R      |            |        | .--.-.     | @           |
| ...        | S      |            |        |            |             |
| -          | T      |            |        |            |             |
| ..-        | U      |            |        |            |             |
| ...-       | V      |            |        |            |             |
| .--        | W      |            |        |            |             |
| -..-       | X      |            |        |            |             |
| -.--       | Y      |            |        |            |             |
| --..       | Z      |            |        |            |             |

## Packaging

1. Create the component package file that handles the installation. This file is sufficient to install the input method.
```bash
pkgbuild --install-location ~/Library/Input\ Methods/ --identifier com.mycompany.inputmethod.MorseCodeInputMethod --version 1.0 --root morse-code-install-files/ MorseCodeComponent.pkg
```

2. Create a **distribution.xml** file, specifying the pkg name from step 1
```bash
productbuild --synthesize --package MorseCodeComponent.pkg distribution.xml
```

3. Modify the **distribution.xml** file appropriately.

4. Create the distribution package, where **resources/** contains the .html files and background.png image that **distribution.xml** references.
```bash
productbuild --distribution distribution.xml --resources resources --package-path . MorseCodeInputMethodInstaller.pkg
```

1. Create an uninstaller package.
```bash
mkdir /tmp/emptydir
pkgbuild --nopayload --scripts uninstall-scripts --identifier com.mycompany.inputmethod.MorseCodeInputMethod --version 1.0 MorseCodeInputMethodUninstaller.pkg
```
