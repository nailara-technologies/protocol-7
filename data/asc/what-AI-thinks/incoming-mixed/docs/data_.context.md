# Protocol-7 Data Directory Context

## Purpose
The data directory contains resources, assets, libraries, and supporting files used by Protocol-7's zenki and modules. This directory serves as a repository for both static resources (fonts, graphics, templates) and language-specific content required by various system components.

## Directory Structure Overview

### Resource Assets
- **gfx/**: Graphics resources organized by type
  - **anim/**: Animation files (GIF format)
  - **backgrounds/**: Background images with cryptographic hash filenames
  - **gradients/**: Gradient textures
  - **icons/**: Icon sets including protocol-7, vclouds weather icons
  - **logos/**: Brand logos for the system
  - **patterns/**: Vector pattern resources
  - **zenka/**: Zenka-specific graphics

- **html/**: HTML templates and fallback content
  - **templates/**: Structured by zenki (image2html, pdf2html, weather, web-browser)
  - Fallback pages for error conditions

- **sounds/**: Audio resources
  - **amos7/**: System notification sounds

- **ttf/**: TrueType fonts for UI rendering
  - **console/**: Terminal-optimized fonts
  - **droid/**: Google's Droid font family
  - Specialty fonts (7segment, DS-Terminal, M39_SQUAREFUTURE)

### Internationalization
- **locales/**: Language-specific resources
  - Organized by zenka (browser, image2html, pdf2html, playlist, weather)
  - Support for multiple languages (bg, de, en, fr)
  - Specialized localization for weekdays, wind terms, and templates

### Libraries and Code
- **lib-path/**: Additional library code
  - **pm/**: Perl modules
    - **AMOS7/**: Core system modules with specialized namespaces
    - Third-party modules (Curses, Devel, Filesys)
  - **pm-src/**: Source code for cryptographic libraries
  - **manuals/**: Man pages for library components
  - **systemd/**: Service definitions for system integration

### Configuration Resources
- **configs/**: UI and application themes
  - **themes/**: Window manager themes
    - **wm/gkrellm2/**: Invisible themes (black, blue, white)
    - **wm/openbox/**: AMOS base theme

### Dependency Management
- **backup/configuration/zenki/ticker-sdl/pm-dep/**: Perl module dependency tracking
  - Zero-byte files with names matching required Perl modules
  - Currently uses "::" namespace separator in filenames (e.g., "AMOS7::Assert::Truth")
  - Planned to change to "__" separator for Windows filesystem compatibility

### Special Purpose
- **asc/**: ASCII art resources including terminal banner
- **backup/**: Backup of configuration and module code
  - **configuration/zenki/**: Zenka configuration backups
  - **modules/**: Backup of module code
- **pov/**: POV-Ray scene definitions
- **scripts/**: Utility scripts organized by function
  - **get-url/**: URL retrieval scripts for specific services

## Key Resource Categories

### Graphics Resources (gfx/)
The graphics directory maintains visual assets organized by type and purpose. Notable is the cryptographic naming scheme for background images and the specialized weather icon set from vclouds (with documented commercial usage permissions).

### HTML Templates (html/templates/)
Templates are organized by zenki, with each zenka having its own template directory. These templates support content transformation (PDF to HTML, image to HTML) and dynamic content generation (weather displays).

### Internationalization (locales/)
The localization system supports multiple languages across different zenki, with specialized vocabulary files for domain-specific terms (weather conditions, weekdays). Templates can be customized per language.

### Perl Modules (lib-path/pm/)
Contains custom modules in the AMOS7 namespace that implement core functionality, as well as third-party modules for specific features (UI rendering, filesystem access, development tools).

### Font Resources (ttf/)
Provides typefaces for various display contexts, from console terminals to UI elements. Includes specialized fonts like 7-segment display for specific visualization needs.

### Dependency Tracking (pm-dep/)
Zero-byte files used to mark Perl module dependencies for zenki. The naming will be changed from using "::" namespace separator to "__" for Windows compatibility.

## Integration Points

- Graphics and fonts are used by UI-oriented zenki
- HTML templates support content transformation zenki
- Localization files enable internationalized user interfaces
- Library modules provide implementation for zenki functionality
- Themes configure the visual appearance of desktop environments

## Note on Resource Naming

Resources with cryptographic hash names (especially in backgrounds/) are of various lengths but are transitioning towards a standardized format of base-32 encoded Blue Midnight Wish checksums. This naming scheme is strategic - these filenames will later serve as addressable routes in a cubic space topology, aligning with the system's harmonic design principles.

_Last updated: 2025-03-21 00:02:59 by nailara-technologies_