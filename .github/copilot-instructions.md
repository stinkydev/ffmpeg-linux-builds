<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# FFmpeg Build Project Instructions

This project is designed to build FFmpeg 5.1.2 for Ubuntu x64 with shared libraries for distribution to other Ubuntu instances.

## Project Structure
- `scripts/` - Build and installation scripts
- `packaging/` - Packaging and distribution files
- `build/` - Build artifacts (created during build)
- `dist/` - Final distribution packages

## Key Requirements
- Build FFmpeg 5.1.2 with shared libraries
- Include common codecs and formats
- Create portable packages for Ubuntu x64
- Ensure compatibility across Ubuntu versions
- Include proper dependency management

## Build Considerations
- Use shared libraries for smaller distribution size
- Include development headers for linking
- Optimize for x64 architecture
- Enable hardware acceleration where possible
- Follow Ubuntu packaging standards
