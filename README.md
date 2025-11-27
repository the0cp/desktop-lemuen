## C++ Integration (Taskbar Hider)

Instead of C# and .NET, this project use C++ to handle Windows API calls (hiding taskbar icon) for optimized performance and reduced export size.

Building DLLs requires:

- Python 3.x
- SCons (`pip install scons`)
- Visual Studio, Desktop development with C++
- Git

### Match Godot Version

The `godot-cpp` bindings must match the specific engine version to avoid API mismatch (e.g., `mem_alloc2`)

```bash
cd godot-cpp
git tag
# Example for Godot 4.5
git checkout godot-4.5-stable
```

If you cannot find an exact tag match, or if you encounter interface errors, generate a custom API JSON from engine executable:

Navigate to the Godot executable, and run it with the dump command:

```bash
<path-to-godot> --dump-extension-api
```

Move the generated `extension_api.json` to the project root (next to `SConstruct`).

### Build the DLL

Clean built:

```bash
scons platform=windows target=template_release -c
```

If the tag matched:

```bash
scons platform=windows target=template_release
```

Build with custom API:

```bash
scons platform=windows target=template_release custom_api_file=extension_api.json
```

***Restart the Godot Editor*** to load the GDExtension.
