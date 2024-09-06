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

## Project Structure

| File/Directory | Description |
|----------------|-------------|
| MorseCodeInputMethod.xcodeproj/ | Xcode project files not to be edited manually. |
| MorseCodeInputMethod/ | Source code for the input method. |
| &nbsp;&nbsp;&nbsp;&nbsp;├── Assets.xcassets/ | Unused default directory for input method assets |
| &nbsp;&nbsp;&nbsp;&nbsp;├── Preview Content/ | Unused default directory |
| &nbsp;&nbsp;&nbsp;&nbsp;├── AppDelegate.swift | Required file for input method to work |
| &nbsp;&nbsp;&nbsp;&nbsp;├── Info.plist | Property list file for the input method |
| &nbsp;&nbsp;&nbsp;&nbsp;├── MorseCodeDictionary.swift | Mapping from Morse code to English keyboard characters, numbers, and punctuation |
| &nbsp;&nbsp;&nbsp;&nbsp;├── MorseCodeInputMethod.entitlements | Required entitlements file for input method to work |
| &nbsp;&nbsp;&nbsp;&nbsp;├── MorseCodeInputMethodController.swift | The main code the captures typing events, displays Morse symbols and converts them to characters |
| &nbsp;&nbsp;&nbsp;&nbsp;├── MorseKeyCodes.swift | Array of allowed keyboard key codes that can be used for typing in Morse code |
| &nbsp;&nbsp;&nbsp;&nbsp;├── menu-icon.icns | An Iconset for the icon that displays in the input menu |
| Packaging/ | Files used after building the app to produce installer and uninstall packages. |
| &nbsp;&nbsp;&nbsp;&nbsp;├── InstallScripts/ | Scripts packaged into the installer package |
| &nbsp;&nbsp;&nbsp;&nbsp;├── Resources/ | HTML files and background image for the package install window |
| &nbsp;&nbsp;&nbsp;&nbsp;├── UninstallScripts/ | Scripts packaged into the uninstaller package |
| &nbsp;&nbsp;&nbsp;&nbsp;├── distribution.xml | File that defines the installation experience for the installer package that contains it |
| .gitignore | File specifying which files to exclude from version control. |
| LICENSE | Licensing information for this software. |
| README.md | This documentation file, used to learn more about the software. |

## Packaging

0. Build the software and place the build products ("Morse Code.app", "Morse_Code.swiftmodule") into a folder to be used during installation package creation.
```bash
cp -r ./build/Release/MorseCodeInputMethod.{app,swiftmodule} Packaging/install-files/
```

2. Create the component package file that handles the installation. This file is sufficient to install the input method.
```bash
cd Packaging
```
```bash
pkgbuild --install-location ~/Library/Input\ Methods/ --identifier com.rapierevite.inputmethod.MorseCodeInputMethod --version 1.0 --root install-files/ --scripts InstallScripts/ MorseCodeComponent.pkg
```

2. Create a **distribution.xml** file, specifying the pkg name from step 1. For more info on the **distribution.xml** file syntax, see Apple's [Distribution XML Reference](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html#//apple_ref/doc/uid/TP40005370-CH100-SW20)
```bash
productbuild --synthesize --package MorseCodeComponent.pkg distribution.xml
```

3. Modify the **distribution.xml** file appropriately.

4. Create the distribution package, where **resources/** contains the .html files and background.png image that **distribution.xml** references.
```bash
productbuild --distribution distribution.xml --resources resources --package-path . MorseCodeInputMethodInstaller.pkg
```

5. Create an uninstaller package.
```bash
pkgbuild --nopayload --scripts UninstallScripts --identifier com.rapierevite.inputmethod.MorseCodeInputMethod --version 1.0 MorseCodeInputMethodUninstaller.pkg
```
